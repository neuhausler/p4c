#include <core.p4>
#define V1MODEL_VERSION 20200408
#include <v1model.p4>

struct egress_metadata_t {
    bit<16> mirror_port;
}

struct ingress_metadata_t {
    bit<10> port_lag;
    bit<32> ip_src;
    bit<32> ip_dest;
    bit<8>  ip_prefix;
    bit<1>  routed;
    bit<16> vrf;
    bit<16> nhop;
    bit<16> ecmp_nhop;
    bit<16> router_intf;
    bit<16> label;
    bit<1>  copy_to_cpu;
    bit<3>  pri;
    bit<8>  qos_selector;
    bit<3>  cos_index;
    bit<16> rif_id;
    bit<16> mac_limit;
    bit<12> def_vlan;
    bit<48> def_smac;
    bit<16> cpu_port;
    bit<8>  max_ports;
    bit<1>  mac_type;
    bit<2>  oper_status;
    bit<2>  port_type;
    bit<3>  stp_state;
    bit<2>  flow_ctrl;
    bit<2>  port_mode;
    bit<4>  port_speed;
    bit<1>  drop_vlan;
    bit<1>  drop_tagged;
    bit<1>  drop_untagged;
    bit<1>  update_dscp;
    bit<14> mtu;
    bit<2>  learning;
    bit<1>  interface_type;
    bit<1>  v4_enable;
    bit<1>  v6_enable;
    bit<12> vlan_id;
    bit<16> srcPort;
    bit<16> dstPort;
    bit<1>  router_mac;
}

struct ingress_intrinsic_metadata_t {
    bit<9> ingress_port;
}

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> ethType;
}

header ipv4_t {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<16> ipv4_length;
    bit<16> id;
    bit<3>  flags;
    bit<13> offset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> checksum;
    bit<32> srcAddr;
    bit<32> dstAddr;
}

header vlan_t {
    bit<3>  pcp;
    bit<1>  cfi;
    bit<12> vid;
    bit<16> ethType;
}

struct metadata {
    @name(".egress_metadata") 
    egress_metadata_t  egress_metadata;
    @name(".ingress_metadata") 
    ingress_metadata_t ingress_metadata;
}

struct headers {
    @name(".eth") 
    ethernet_t eth;
    @name(".ipv4") 
    ipv4_t     ipv4;
    @name(".vlan") 
    vlan_t     vlan;
}

parser ParserImpl(packet_in packet, out headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    @name(".parse_eth") state parse_eth {
        packet.extract(hdr.eth);
        transition select(hdr.eth.ethType) {
            16w0x8100: parse_vlan;
            16w0x800: parse_ipv4;
            default: accept;
        }
    }
    @name(".parse_ipv4") state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }
    @name(".parse_vlan") state parse_vlan {
        packet.extract(hdr.vlan);
        transition accept;
    }
    @name(".start") state start {
        transition parse_eth;
    }
}

@name(".next_hop_group") action_selector(HashAlgorithm.crc16, 32w0, 32w16) next_hop_group;

@name(".vlan") action_profile(32w0) vlan;

control egress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    apply {
        if (meta.ingress_metadata.oper_status == 2w1) {
        }
    }
}

@name("mac_learn_digest") struct mac_learn_digest {
    bit<12> vlan_id;
    bit<48> srcAddr;
    bit<9>  ingress_port;
    bit<2>  learning;
}

control ingress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    @name(".port_counters") direct_counter(CounterType.packets) port_counters;
    @name(".fdb_set") action fdb_set(bit<1> type_, bit<9> port_id) {
        meta.ingress_metadata.mac_type = type_;
        standard_metadata.egress_spec = port_id;
        meta.ingress_metadata.routed = 1w0;
    }
    @name(".nop") action nop() {
    }
    @name(".generate_learn_notify") action generate_learn_notify() {
        digest<mac_learn_digest>((bit<32>)1024, { meta.ingress_metadata.vlan_id, hdr.eth.srcAddr, standard_metadata.ingress_port, meta.ingress_metadata.learning });
    }
    @name(".set_dmac") action set_dmac(bit<48> dst_mac_address, bit<9> port_id) {
        hdr.eth.dstAddr = dst_mac_address;
        hdr.eth.srcAddr = (bit<48>)meta.ingress_metadata.def_smac;
        standard_metadata.egress_spec = port_id;
    }
    @name(".set_next_hop") action set_next_hop(bit<8> type_, bit<8> ip, bit<16> router_interface_id) {
        meta.ingress_metadata.router_intf = router_interface_id;
    }
    @name(".set_in_port") action set_in_port(bit<10> port, bit<2> type_, bit<2> oper_status, bit<4> speed, bit<8> admin_state, bit<12> default_vlan, bit<8> default_vlan_priority, bit<1> ingress_filtering, bit<1> drop_untagged, bit<1> drop_tagged, bit<2> port_loopback_mode, bit<2> fdb_learning, bit<3> stp_state, bit<1> update_dscp, bit<14> mtu, bit<8> sflow, bit<8> flood_storm_control, bit<8> broadcast_storm_control, bit<8> multicast_storm_control, bit<2> global_flow_control, bit<16> max_learned_address, bit<8> fdb_learning_limit_violation) {
        meta.ingress_metadata.port_lag = port;
        meta.ingress_metadata.mac_limit = max_learned_address;
        meta.ingress_metadata.port_type = type_;
        meta.ingress_metadata.oper_status = oper_status;
        meta.ingress_metadata.flow_ctrl = global_flow_control;
        meta.ingress_metadata.port_speed = speed;
        meta.ingress_metadata.drop_vlan = ingress_filtering;
        meta.ingress_metadata.drop_tagged = drop_tagged;
        meta.ingress_metadata.drop_untagged = drop_untagged;
        meta.ingress_metadata.port_mode = port_loopback_mode;
        meta.ingress_metadata.learning = fdb_learning;
        meta.ingress_metadata.stp_state = stp_state;
        meta.ingress_metadata.update_dscp = update_dscp;
        meta.ingress_metadata.mtu = mtu;
        meta.ingress_metadata.vlan_id = default_vlan;
    }
    @name(".copy_to_cpu") action copy_to_cpu() {
        meta.ingress_metadata.copy_to_cpu = 1w1;
    }
    @name(".route_set_trap") action route_set_trap(bit<3> trap_priority) {
        meta.ingress_metadata.pri = trap_priority;
        copy_to_cpu();
    }
    @name(".route_set_nexthop") action route_set_nexthop(bit<16> next_hop_id) {
        meta.ingress_metadata.nhop = next_hop_id;
        meta.ingress_metadata.routed = 1w1;
        meta.ingress_metadata.ip_dest = (bit<32>)hdr.ipv4.dstAddr;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 8w1;
    }
    @name(".route_set_nexthop_group") action route_set_nexthop_group(bit<16> next_hop_group_id) {
        meta.ingress_metadata.ecmp_nhop = next_hop_group_id;
        meta.ingress_metadata.routed = 1w1;
        meta.ingress_metadata.ip_dest = (bit<32>)hdr.ipv4.dstAddr;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 8w1;
    }
    @name(".set_router_interface") action set_router_interface(bit<16> virtual_router_id, bit<1> type_, bit<9> port_id, bit<12> vlan_id, bit<48> src_mac_address, bit<1> admin_v4_state, bit<1> admin_v6_state, bit<14> mtu) {
        meta.ingress_metadata.vrf = virtual_router_id;
        meta.ingress_metadata.interface_type = type_;
        standard_metadata.egress_spec = port_id;
        meta.ingress_metadata.vlan_id = vlan_id;
        meta.ingress_metadata.def_smac = src_mac_address;
        meta.ingress_metadata.v4_enable = admin_v4_state;
        meta.ingress_metadata.v6_enable = admin_v6_state;
        meta.ingress_metadata.mtu = mtu;
        meta.ingress_metadata.router_mac = 1w1;
    }
    @name(".router_interface_miss") action router_interface_miss() {
        meta.ingress_metadata.router_mac = 1w0;
    }
    @name(".set_switch") action set_switch(bit<8> port_number, bit<16> cpu_port, bit<8> max_virtual_routers, bit<8> fdb_table_size, bit<8> on_link_route_supported, bit<2> oper_status, bit<8> max_temp, bit<8> switching_mode, bit<8> cpu_flood_enable, bit<8> ttl1_action, bit<12> port_vlan_id, bit<48> src_mac_address, bit<8> fdb_aging_time, bit<8> fdb_unicast_miss_action, bit<8> fdb_broadcast_miss_action, bit<8> fdb_multicast_miss_action, bit<8> ecmp_hash_seed, bit<8> ecmp_hash_type, bit<8> ecmp_hash_fields, bit<8> ecmp_max_paths, bit<16> vr_id) {
        meta.ingress_metadata.def_vlan = port_vlan_id;
        meta.ingress_metadata.vrf = vr_id;
        meta.ingress_metadata.def_smac = src_mac_address;
        meta.ingress_metadata.cpu_port = cpu_port;
        meta.ingress_metadata.max_ports = port_number;
        meta.ingress_metadata.oper_status = oper_status;
        standard_metadata.ingress_port = (bit<9>)standard_metadata.ingress_port;
    }
    @name(".set_router") action set_router(bit<1> admin_v4_state, bit<1> admin_v6_state, bit<48> src_mac_address, bit<8> violation_ttl1_action, bit<8> violation_ip_options) {
        meta.ingress_metadata.def_smac = src_mac_address;
        meta.ingress_metadata.v4_enable = admin_v4_state;
        meta.ingress_metadata.v6_enable = admin_v6_state;
    }
    @name(".fdb") table fdb {
        actions = {
            fdb_set;
        }
        key = {
            meta.ingress_metadata.vlan_id: exact;
            hdr.eth.dstAddr              : exact;
        }
    }
    @name(".learn_notify") table learn_notify {
        actions = {
            nop;
            generate_learn_notify;
        }
        key = {
            standard_metadata.ingress_port: exact;
            meta.ingress_metadata.vlan_id : exact;
            hdr.eth.srcAddr               : exact;
        }
    }
    @name(".neighbor") table neighbor {
        actions = {
            set_dmac;
        }
        key = {
            meta.ingress_metadata.vrf        : exact;
            meta.ingress_metadata.ip_dest    : exact;
            meta.ingress_metadata.router_intf: exact;
        }
    }
    @name(".next_hop") table next_hop {
        actions = {
            set_next_hop;
        }
        key = {
            meta.ingress_metadata.nhop: exact;
        }
    }
    @name(".set_in_port") action set_in_port_0(bit<10> port, bit<2> type_, bit<2> oper_status, bit<4> speed, bit<8> admin_state, bit<12> default_vlan, bit<8> default_vlan_priority, bit<1> ingress_filtering, bit<1> drop_untagged, bit<1> drop_tagged, bit<2> port_loopback_mode, bit<2> fdb_learning, bit<3> stp_state, bit<1> update_dscp, bit<14> mtu, bit<8> sflow, bit<8> flood_storm_control, bit<8> broadcast_storm_control, bit<8> multicast_storm_control, bit<2> global_flow_control, bit<16> max_learned_address, bit<8> fdb_learning_limit_violation) {
        port_counters.count();
        meta.ingress_metadata.port_lag = port;
        meta.ingress_metadata.mac_limit = max_learned_address;
        meta.ingress_metadata.port_type = type_;
        meta.ingress_metadata.oper_status = oper_status;
        meta.ingress_metadata.flow_ctrl = global_flow_control;
        meta.ingress_metadata.port_speed = speed;
        meta.ingress_metadata.drop_vlan = ingress_filtering;
        meta.ingress_metadata.drop_tagged = drop_tagged;
        meta.ingress_metadata.drop_untagged = drop_untagged;
        meta.ingress_metadata.port_mode = port_loopback_mode;
        meta.ingress_metadata.learning = fdb_learning;
        meta.ingress_metadata.stp_state = stp_state;
        meta.ingress_metadata.update_dscp = update_dscp;
        meta.ingress_metadata.mtu = mtu;
        meta.ingress_metadata.vlan_id = default_vlan;
    }
    @name(".port") table port {
        actions = {
            set_in_port_0;
        }
        key = {
            standard_metadata.ingress_port: exact;
        }
        counters = port_counters;
    }
    @name(".route") table route {
        actions = {
            route_set_trap;
            route_set_nexthop;
            route_set_nexthop_group;
        }
        key = {
            meta.ingress_metadata.vrf: exact;
            hdr.ipv4.dstAddr         : lpm;
        }
    }
    @name(".router_interface") table router_interface {
        actions = {
            set_router_interface;
            router_interface_miss;
        }
        key = {
            hdr.eth.dstAddr: exact;
        }
    }
    @name(".switch") table switch_0 {
        actions = {
            set_switch;
        }
    }
    @name(".virtual_router") table virtual_router {
        actions = {
            set_router;
        }
        key = {
            meta.ingress_metadata.vrf: exact;
        }
    }
    apply {
        switch_0.apply();
        port.apply();
        if (meta.ingress_metadata.oper_status == 2w1) {
            router_interface.apply();
            if (meta.ingress_metadata.learning != 2w0) {
                learn_notify.apply();
            }
            if (meta.ingress_metadata.router_mac == 1w0) {
                fdb.apply();
            } else {
                virtual_router.apply();
                if (hdr.ipv4.isValid() && meta.ingress_metadata.v4_enable != 1w0) {
                    route.apply();
                }
                next_hop.apply();
            }
            if (meta.ingress_metadata.routed != 1w0) {
                neighbor.apply();
            }
        }
    }
}

control DeparserImpl(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.eth);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.vlan);
    }
}

control verifyChecksum(inout headers hdr, inout metadata meta) {
    apply {
        verify_checksum(hdr.ipv4.ihl == 4w5, { hdr.ipv4.version, hdr.ipv4.ihl, hdr.ipv4.diffserv, hdr.ipv4.ipv4_length, hdr.ipv4.id, hdr.ipv4.flags, hdr.ipv4.offset, hdr.ipv4.ttl, hdr.ipv4.protocol, hdr.ipv4.srcAddr, hdr.ipv4.dstAddr }, hdr.ipv4.checksum, HashAlgorithm.csum16);
    }
}

control computeChecksum(inout headers hdr, inout metadata meta) {
    apply {
        update_checksum(hdr.ipv4.ihl == 4w5, { hdr.ipv4.version, hdr.ipv4.ihl, hdr.ipv4.diffserv, hdr.ipv4.ipv4_length, hdr.ipv4.id, hdr.ipv4.flags, hdr.ipv4.offset, hdr.ipv4.ttl, hdr.ipv4.protocol, hdr.ipv4.srcAddr, hdr.ipv4.dstAddr }, hdr.ipv4.checksum, HashAlgorithm.csum16);
    }
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(), DeparserImpl()) main;

