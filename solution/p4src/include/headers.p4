/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

const bit<16> TYPE_IPV4 = 0x800;

/* tuple bit size */
#define IPV4_TUPLE_BIT_SIZE 104

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;


header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<6>    dscp;
    bit<2>    ecn;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

header tcp_t{
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4>  dataOffset;
    bit<4>  res;
    bit<1>  cwr;
    bit<1>  ece;
    bit<1>  urg;
    bit<1>  ack;
    bit<1>  psh;
    bit<1>  rst;
    bit<1>  syn;
    bit<1>  fin;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}

struct metadata {
    bit<32> index_sketch0;
    bit<32> index_sketch1;
    bit<32> index_sketch2;
    bit<32> index_sketch3;
    bit<32> index_sketch4;
    bit<32> index_sketch5;
    bit<32> index_sketch6;
    bit<32> index_sketch7;

    bit<64> value_sketch0;
    bit<64> value_sketch1;
    bit<64> value_sketch2;
    bit<64> value_sketch3;
    bit<64> value_sketch4;
    bit<64> value_sketch5;
    bit<64> value_sketch6;
    bit<64> value_sketch7;

    bit<32> _srcAddr;
    bit<32> _dstAddr;
    bit<16> _srcPort; 
    bit<16> _dstPort; 
    bit<8> _protocol; 

    bit<IPV4_TUPLE_BIT_SIZE> top_bit;
    bit<1> become_zero;
    bit<1> should_gen_token;
    bit<1> queue_is_empty;
    bit<1> queue_is_full;
    bit<1> enough_token;
    bit<1> should_add_queue;
    bit<64> minimun_value;

    bit<1> should_drop;
}

struct headers {
    ethernet_t   ethernet;
    ipv4_t       ipv4;
    tcp_t        tcp;
}

