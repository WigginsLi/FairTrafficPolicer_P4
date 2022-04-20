/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

#include "include/headers.p4"
#include "include/parsers.p4"

#define TURE 1
#define FALSE 0

/* CONSTANTS */
#define SKETCH_BUCKET_LENGTH 1000
#define SKETCH_CELL_BIT_WIDTH 64

/* token bucket */
#define TOTAL_CAPACITY 1
#define PER_TOKEN_NUM 1

/* timestamp */
#define REG_TIMESTAMP_INDEX 0
#define REG_SPENT_TIME_INDEX 1

/* generate time for a token */
#define GEN_TIME 1000

/* queue capacity for active queue and some property for queue */
#define QUEUE_CAPACITY 1000
#define QUEUE_SIZE_INDEX 0
#define QUEUE_TOP_INDEX 1
#define QUEUE_TAIL_INDEX 2

typedef bit<48> time_t;
typedef tuple<bit<32>, bit<32>, bit<16>, bit<16>, bit<8>> ipv4_tuple_t;

#define SKETCH_REGISTER(num) register<bit<SKETCH_CELL_BIT_WIDTH>>(SKETCH_BUCKET_LENGTH) sketch##num

#define IPV4_TUPLE {hdr.ipv4.srcAddr, hdr.ipv4.dstAddr, hdr.tcp.srcPort, hdr.tcp.dstPort, hdr.ipv4.protocol}
#define TOP_IPV4_TUPLE {meta._srcAddr, meta._dstAddr, meta._srcPort, meta._dstPort, meta._protocol}

#define TUPLE_TO_BIT \
  bit<104> tuple_bit = 0; \
  tuple_bit[7:0] = hdr.ipv4.protocol; \
  tuple_bit[23:8] = hdr.tcp.dstPort; \
  tuple_bit[39:24] = hdr.tcp.srcPort; \
  tuple_bit[71:40] = hdr.ipv4.dstAddr; \
  tuple_bit[103:72] = hdr.ipv4.srcAddr; 

#define BIT_TO_TUPLE(num) \
  bit<IPV4_TUPLE_BIT_SIZE> temp = num; \
  meta._srcAddr = temp[103:72]; \
  meta._dstAddr = temp[71:40]; \
  meta._srcPort = temp[39:24]; \
  meta._dstPort = temp[23:8]; \
  meta._protocol = temp[7:0];

#define GET_SKETCH_INDEX_WITH_TUPLE(num, algorithm, tuple) \
  hash(\
    meta.index_sketch##num, \
    HashAlgorithm.algorithm, \
    (bit<16>)0, \
    tuple, \
    (bit<32>)SKETCH_BUCKET_LENGTH ); \
  sketch##num.read(meta.value_sketch##num, meta.index_sketch##num); \
  if (meta.value_sketch##num < meta.minimun_value) {\
    meta.minimun_value = meta.value_sketch##num; \
  } 

#define INCREASE_SKETCH_COUNT(num) \
  meta.value_sketch##num = meta.value_sketch##num + 1; \
  sketch##num.write(meta.index_sketch##num, meta.value_sketch##num);

#define DECREASE_SKETCH_COUNT(num, token_num) \
  if (meta.value_sketch##num > token_num) { \
    meta.value_sketch##num = meta.value_sketch##num - token_num; \
  } else { \
    meta.value_sketch##num = 0; \
    meta.become_zero = TURE;\
  } \
  sketch##num.write(meta.index_sketch##num, meta.value_sketch##num);
  

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    
    SKETCH_REGISTER(0);
    SKETCH_REGISTER(1);
    SKETCH_REGISTER(2);

    register<time_t>(2) slice_ts;
    register<bit<IPV4_TUPLE_BIT_SIZE>>(QUEUE_CAPACITY) active_queue;
    register<bit<32>>(3) queue_property; // 0: size_index, 1: top_index, 2: tail_index

    register<bit<IPV4_TUPLE_BIT_SIZE>>(1) debug_tool;

    action init() {
        meta.should_drop = FALSE;
        meta.enough_token = FALSE;
        meta.should_add_queue = FALSE;
        meta.should_gen_token = FALSE;
    }

    action drop() {
        meta.should_drop = TURE;
        mark_to_drop(standard_metadata);
    }

    action check_queue_state() {
        meta.queue_is_empty = FALSE;
        meta.queue_is_full = FALSE;

        bit<32> queue_top_index; 
        queue_property.read(queue_top_index, QUEUE_TOP_INDEX); 
        bit<32> queue_tail_index; 
        queue_property.read(queue_tail_index, QUEUE_TAIL_INDEX); 

        if (queue_top_index == queue_tail_index) {
            meta.queue_is_empty = TURE;
        }

        bit<32> next_index;
        if (queue_tail_index == QUEUE_CAPACITY - 1) next_index = 0; 
        else next_index = queue_tail_index + 1; 
        if (next_index == queue_top_index) {
            meta.queue_is_full = TURE;
        }
    }

    action queue_push(bit<IPV4_TUPLE_BIT_SIZE> value) {
        bit<32> queue_top_index; 
        queue_property.read(queue_top_index, QUEUE_TOP_INDEX); 
        bit<32> queue_tail_index; 
        queue_property.read(queue_tail_index, QUEUE_TAIL_INDEX);
        bit<32> queue_size; 
        queue_property.read(queue_size, QUEUE_SIZE_INDEX);
        bit<32> next_index; 
        if (queue_tail_index == QUEUE_CAPACITY - 1) next_index = 0;
        else next_index = queue_tail_index + 1;

        active_queue.write(queue_tail_index, value);
        queue_property.write(QUEUE_TAIL_INDEX, next_index); 
        queue_property.write(QUEUE_SIZE_INDEX, queue_size + 1); 
    }

    action queue_pop() {
        bit<32> queue_top_index; 
        queue_property.read(queue_top_index, QUEUE_TOP_INDEX); 
        bit<32> queue_tail_index; 
        queue_property.read(queue_tail_index, QUEUE_TAIL_INDEX); 
        bit<32> queue_size; 
        queue_property.read(queue_size, QUEUE_SIZE_INDEX);
        bit<32> next_index;

        if (queue_top_index == QUEUE_CAPACITY - 1) next_index = 0; 
        else next_index = queue_top_index + 1;
        queue_property.write(QUEUE_TOP_INDEX, next_index);
        queue_property.write(QUEUE_SIZE_INDEX, queue_size - 1);
    }

    action check_token(){
        meta.minimun_value = 64w0x7FFFFFFFFFFFFFFF;
        GET_SKETCH_INDEX_WITH_TUPLE(0, crc32_custom, IPV4_TUPLE);
        GET_SKETCH_INDEX_WITH_TUPLE(1, crc32_custom, IPV4_TUPLE);
        GET_SKETCH_INDEX_WITH_TUPLE(2, crc32_custom, IPV4_TUPLE);

        /*
        1、get the minimun value as current value
        2、if (value > Total_Capacity/(queue_size+1)) , drop()
        3、otherwise, increase 1
        */
        
        bit<32> queue_size;
        queue_property.read(queue_size, QUEUE_SIZE_INDEX);
        if (meta.minimun_value *  ((bit<64>)queue_size + 1) < TOTAL_CAPACITY) {
            meta.enough_token = TURE;
            if (meta.minimun_value == 0) {
                meta.should_add_queue = TURE;
            }
        }
    }

    action generate_token_and_update_queue() {
        // 1、pop queue top and get its tuple_bit
        // 2、deparse tuple_bit to tuple
        // 3、hash tuple and decrase its sketch_value
        // 4、if its value doesn't become zero, push it back to queue 
        // 5、modify queue size

        bit<32> queue_top_index;
        queue_property.read(queue_top_index, QUEUE_TOP_INDEX);
        active_queue.read(meta.top_bit, queue_top_index);
        queue_pop();

        BIT_TO_TUPLE(meta.top_bit);
        meta.minimun_value = 64w0x7FFFFFFFFFFFFFFF;
        GET_SKETCH_INDEX_WITH_TUPLE(0, crc32_custom, TOP_IPV4_TUPLE);
        GET_SKETCH_INDEX_WITH_TUPLE(1, crc32_custom, TOP_IPV4_TUPLE);
        GET_SKETCH_INDEX_WITH_TUPLE(2, crc32_custom, TOP_IPV4_TUPLE);

        meta.become_zero = FALSE;
        DECREASE_SKETCH_COUNT(0, PER_TOKEN_NUM);
        DECREASE_SKETCH_COUNT(1, PER_TOKEN_NUM);
        DECREASE_SKETCH_COUNT(2, PER_TOKEN_NUM);
    }

    action check_token_generated() {
        time_t c_ts = standard_metadata.ingress_global_timestamp;
        time_t p_ts;
        time_t delta;

        // update timestamp
        slice_ts.read(p_ts, REG_TIMESTAMP_INDEX);
        slice_ts.write(REG_TIMESTAMP_INDEX, c_ts);

        delta = c_ts - p_ts;
        // Wrap up timestamp
        if (delta >= 3294967296) {
            delta = delta - 3294967296;
        }

        time_t spent_time;
        slice_ts.read(spent_time, REG_SPENT_TIME_INDEX);
        if (spent_time + delta >= GEN_TIME) {
            spent_time = spent_time + delta - GEN_TIME;
            meta.should_gen_token = TURE;
        }

        slice_ts.write(REG_SPENT_TIME_INDEX, spent_time);
    }

    action forward(bit<9> egress_port) {
        standard_metadata.egress_spec = egress_port;
    }

    table dmac {
        key = {
            hdr.ethernet.dstAddr: exact;
        }

        actions = {
            forward;
            NoAction;
        }
        size = 256;
        default_action = NoAction;
    }

    apply {

        bit<1> should_apply_fairPolicer = 0;
        if (should_apply_fairPolicer == TURE) {
            init();
            if (hdr.ipv4.isValid() && hdr.tcp.isValid()){
                check_queue_state();
                check_token_generated();
                if (meta.should_gen_token == TURE && meta.queue_is_empty == FALSE) {
                    generate_token_and_update_queue();
                    if (meta.become_zero == FALSE) {
                        queue_push(meta.top_bit);
                    }
                }
                
                check_queue_state();
                check_token();
                if (meta.enough_token == TURE) {
                    INCREASE_SKETCH_COUNT(0);
                    INCREASE_SKETCH_COUNT(1);
                    INCREASE_SKETCH_COUNT(2);
                    if (meta.should_add_queue == TURE && meta.queue_is_full == FALSE) {
                        TUPLE_TO_BIT;
                        queue_push(tuple_bit);
                    }
                }else {
                    drop();
                }
            }

            if (meta.should_drop == FALSE) {
                dmac.apply();
            }
        }else {
            dmac.apply();
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {  }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
     apply {
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

//switch architecture
V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;