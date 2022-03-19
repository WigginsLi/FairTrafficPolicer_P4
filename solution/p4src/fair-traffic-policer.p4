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

#define SKETCH_REGISTER(num) register<bit<SKETCH_CELL_BIT_WIDTH>>(SKETCH_BUCKET_LENGTH) sketch##num

/*#define SKETCH_COUNT(num, algorithm) hash(meta.index_sketch##num, HashAlgorithm.algorithm, (bit<16>)0, {(bit<32>)1}, (bit<32>)SKETCH_BUCKET_LENGTH);\
 sketch##num.read(meta.value_sketch##num, meta.index_sketch##num); \
 meta.value_sketch##num = meta.value_sketch##num +1; \
 sketch##num.write(meta.index_sketch##num, meta.value_sketch##num)
*/

#define SKETCH_COUNT(num, algorithm) \
  hash(\
    meta.index_sketch##num, \
    HashAlgorithm.algorithm,\
    (bit<16>)0, \
    {hdr.ipv4.srcAddr, hdr.ipv4.dstAddr, hdr.tcp.srcPort, hdr.tcp.dstPort, hdr.ipv4.protocol},\
    (bit<32>)SKETCH_BUCKET_LENGTH\
  );\
  sketch##num.read(meta.value_sketch##num, meta.index_sketch##num); \
  meta.value_sketch##num = meta.value_sketch##num +1; \
  sketch##num.write(meta.index_sketch##num, meta.value_sketch##num)

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
    SKETCH_REGISTER(0);
    SKETCH_REGISTER(1);
    SKETCH_REGISTER(2);
    //SKETCH_REGISTER(3);
    //SKETCH_REGISTER(4);

    action drop() {
        mark_to_drop(standard_metadata);
    }

    action sketch_count(){
        SKETCH_COUNT(0, crc32_custom);
        SKETCH_COUNT(1, crc32_custom);
        SKETCH_COUNT(2, crc32_custom);
        //SKETCH_COUNT(3, crc32_custom);
        //SKETCH_COUNT(4, crc32_custom);
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
            // TODO: update active queue
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