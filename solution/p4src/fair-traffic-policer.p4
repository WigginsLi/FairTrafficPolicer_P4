/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

#include "include/headers.p4"
#include "include/parsers.p4"

/* CONSTANTS */
#define SKETCH_BUCKET_LENGTH 28
#define SKETCH_CELL_BIT_WIDTH 64

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

/* tuple bit size */
#define IPV4_TUPLE_BIT_SIZE 104

typedef bit<48> time_t;
typedef bit<IPV4_TUPLE_BIT_SIZE> ipv4_tuple_bit_t;
typedef tuple<bit<32>, bit<32>, bit<16>, bit<16>, bit<8>> ipv4_tuple_t;

#define SKETCH_REGISTER(num) register<bit<SKETCH_CELL_BIT_WIDTH>>(SKETCH_BUCKET_LENGTH) sketch##num

#define IPV4_TUPLE {hdr.ipv4.srcAddr, hdr.ipv4.dstAddr, hdr.tcp.srcPort, hdr.tcp.dstPort, hdr.ipv4.protocol}

#define TUPLE_TO_BIT \
  ((((((((\
  (ipv4_tuple_bit_t)hdr.ipv4.srcAddr << (IPV4_TUPLE_BIT_SIZE - 32)) \
  & (ipv4_tuple_bit_t)hdr.ipv4.dstAddr) << (IPV4_TUPLE_BIT_SIZE - 32 - 32)) \
  & (ipv4_tuple_bit_t)hdr.tcp.srcPort) << (IPV4_TUPLE_BIT_SIZE - 32 - 32 - 16)) \
  & (ipv4_tuple_bit_t)hdr.tcp.dstPort) << (IPV4_TUPLE_BIT_SIZE - 32 - 32 - 16 - 16)) \
  & (ipv4_tuple_bit_t)hdr.ipv4.protocol)

#define BIT_TO_TUPLE(num) \
  ipv4_tuple_bit_t temp = num; \
  bit<32> srcAddr; srcAddr = (bit<32>)temp & (1<<32-1); temp = temp >> 32; \
  bit<32> dstAddr; dstAddr = (bit<32>)temp & (1<<32-1); temp = temp >> 32;\
  bit<16> srcPort; srcPort = (bit<16>)temp & (1<<16-1); temp = temp >> 16;\
  bit<16> dstPort; dstPort = (bit<16>)temp & (1<<16-1); temp = temp >> 16;\
  bit<8> protocol; protocol = (bit<8>)temp & (1<<8-1); temp = temp >> 8;\

#define SKETCH_COUNT(num, algorithm, tuple) \
  hash(\
    meta.index_sketch##num, \
    HashAlgorithm.algorithm,\
    (bit<16>)0, \
    tuple,\
    (bit<32>)SKETCH_BUCKET_LENGTH\
  );\
  // TODO: modify value (0: increase, 1: decrease)
//   sketch##num.read(meta.value_sketch##num, meta.index_sketch##num); \
//   meta.value_sketch##num = meta.value_sketch##num +1; \
//   sketch##num.write(meta.index_sketch##num, meta.value_sketch##num);

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

    register<time_t>(2) slice_ts;
    register<ipv4_tuple_bit_t>(QUEUE_CAPACITY) active_queue;
    register<bit<32>>(3) queue_property; // 0: size_index, 1: top_index, 2: tail_index

    SKETCH_REGISTER(0);
    SKETCH_REGISTER(1);
    SKETCH_REGISTER(2);
    //SKETCH_REGISTER(3);
    //SKETCH_REGISTER(4);

    action drop() {
        mark_to_drop(standard_metadata);
    }

    action sketch_count(){
        SKETCH_COUNT(0, crc32_custom, IPV4_TUPLE);
        SKETCH_COUNT(1, crc32_custom, IPV4_TUPLE);
        SKETCH_COUNT(2, crc32_custom, IPV4_TUPLE);
        //SKETCH_COUNT(3, crc32_custom);
        //SKETCH_COUNT(4, crc32_custom);

        // TODO:
        /*
        1、get the minimun value as current value
        2、if (value > Total_Capacity/queue_size) , drop()
        3、otherwise, increase 1
        */
    }

    action generate_token_and_update_queue() {
        // TODO:
        // 1、pop queue top and get its tuple_bit
        // 2、deparse tuple_bit to tuple
        // 3、hash tuple and decrase its sketch_value
        // 4、if its value doesn't become zero, push it back to queue 
        // 5、modify queue size (queue[0])
        ipv4_tuple_bit_t top_bit;
        active_queue.read(top_bit, QUEUE_SIZE_INDEX);
        BIT_TO_TUPLE(top_bit);
        ipv4_tuple_t top_ipv4_tuple = {srcAddr, dstAddr, srcPort, dstPort, protocol};
        SKETCH_COUNT(0, crc32_custom, top_ipv4_tuple);
        SKETCH_COUNT(1, crc32_custom, top_ipv4_tuple);
        SKETCH_COUNT(2, crc32_custom, top_ipv4_tuple);
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
        // if (delta >= 3294967296) {
        //     delta -= 3294967296;
        // }

        time_t spent_time;
        slice_ts.read(spent_time, REG_SPENT_TIME_INDEX);
        if (spent_time + delta >= GEN_TIME) {
            spent_time = spent_time + delta - GEN_TIME;
            generate_token_and_update_queue();
        }

        slice_ts.write(REG_SPENT_TIME_INDEX, spent_time);
    }

    action set_egress_port(bit<9> egress_port){
        standard_metadata.egress_spec = egress_port;
    }

    table forwarding {
        key = {
            standard_metadata.ingress_port: exact;
        }
        actions = {
            set_egress_port;
            drop;
            NoAction;
        }
        size = 64;
        default_action = drop;
    }

    apply {

        //apply sketch
        if (hdr.ipv4.isValid() && hdr.tcp.isValid()){
            sketch_count();
        }

        forwarding.apply();
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