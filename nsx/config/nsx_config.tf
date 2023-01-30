resource "null_resource" "waiting_for_nsx_api" {
  provisioner "local-exec" {
    command = "/bin/bash bash/waiting_for_nsx_api.sh"
  }
}

resource "null_resource" "ansible_init_manager" {
  depends_on = [null_resource.waiting_for_nsx_api]

  provisioner "local-exec" {
    command = "ansible-playbook ansible/ansible_init_manager.yml -e @../../variables.json"
  }
}

resource "null_resource" "register_compute_manager" {
  depends_on = [null_resource.ansible_init_manager]
  provisioner "local-exec" {
    command = "/bin/bash bash/register_compute_manager.sh"
  }
}

resource "nsxt_policy_ip_pool" "pools" {
  depends_on = [null_resource.register_compute_manager]
  count = length(var.nsx.config.ip_pools)
  display_name = var.nsx.config.ip_pools[count.index].name
}

resource "nsxt_policy_ip_pool_static_subnet" "static_subnet" {
  depends_on = [null_resource.register_compute_manager]
  count = length(var.nsx.config.ip_pools)
  display_name = "${var.nsx.config.ip_pools[count.index].name}-static-subnet"
  pool_path    = nsxt_policy_ip_pool.pools[count.index].path
  cidr         = var.nsx.config.ip_pools[count.index].cidr
  gateway      = var.nsx.config.ip_pools[count.index].gateway

  allocation_range {
    start = var.nsx.config.ip_pools[count.index].start
    end   = var.nsx.config.ip_pools[count.index].end
  }

}

data "nsxt_policy_transport_zone" "transport_zone_vlan" {
  depends_on = [null_resource.register_compute_manager]
  count = length(var.nsx.config.segments)
  display_name        = var.nsx.config.segments[count.index].transport_zone
}

resource "nsxt_policy_segment" "segments_for_multiple_vds" {
  depends_on = [null_resource.register_compute_manager]
  count = length(var.nsx.config.segments)
  display_name        = var.nsx.config.segments[count.index].name
  vlan_ids = [var.nsx.config.segments[count.index].vlan]
  transport_zone_path = data.nsxt_policy_transport_zone.transport_zone_vlan[count.index].path
  description         = var.nsx.config.segments[count.index].description
}

resource "null_resource" "create_transport_node_profiles" {
  depends_on = [nsxt_policy_ip_pool.pools, nsxt_policy_ip_pool_static_subnet.static_subnet, nsxt_policy_segment.segments_for_multiple_vds]
  provisioner "local-exec" {
    command = "ansible-playbook ansible/create_transport_node_profiles.yml -e @../../variables.json"
  }
}

resource "null_resource" "create_host_transport_nodes" {
  depends_on = [null_resource.create_transport_node_profiles]
  provisioner "local-exec" {
    command = "/bin/bash bash/create_host_transport_nodes.sh"
  }
}

resource "null_resource" "create_edge_nodes" {
  depends_on = [null_resource.register_compute_manager]
  provisioner "local-exec" {
    command = "/bin/bash bash/create_edge_nodes.sh"
  }
}

resource "null_resource" "create_edge_clusters" {
  depends_on = [null_resource.create_edge_nodes]
  provisioner "local-exec" {
    command = "/bin/bash bash/create_edge_clusters.sh"
  }
}

resource "null_resource" "create_tier0s" {
  depends_on = [null_resource.create_edge_clusters]
  provisioner "local-exec" {
    command = "/bin/bash bash/create_tier0s.sh"
  }
}

data "nsxt_policy_tier0_gateway" "tier0s_for_tier1s" {
  depends_on = [null_resource.create_tier0s]
  count = length(var.nsx.config.tier1s)
  display_name = var.nsx.config.tier1s[count.index].tier0
}

resource "nsxt_policy_tier1_gateway" "tier1s" {
  count = length(var.nsx.config.tier1s)
  display_name              = var.nsx.config.tier1s[count.index].display_name
  tier0_path                = data.nsxt_policy_tier0_gateway.tier0s_for_tier1s[count.index].path
  route_advertisement_types = var.nsx.config.tier1s[count.index].route_advertisement_types
}

resource "time_sleep" "wait_tier1" {
  count = length(var.nsx.config.tier1s)
  depends_on = [nsxt_policy_tier1_gateway.tier1s]
  create_duration = "10s"
}

data "nsxt_policy_tier1_gateway" "tier1s_for_segments_overlay" {
  depends_on = [nsxt_policy_tier1_gateway.tier1s]
  count = length(var.nsx.config.segments_overlay)
  display_name = var.nsx.config.segments_overlay[count.index].tier1
}

data "nsxt_policy_transport_zone" "tzs_for_segments_overlay" {
  depends_on = [null_resource.create_tier0s]
  count = length(var.nsx.config.segments_overlay)
  display_name = var.nsx.config.segments_overlay[count.index].transport_zone
}

resource "nsxt_policy_fixed_segment" "segments" {
  count = length(var.nsx.config.segments_overlay)
  display_name        = var.nsx.config.segments_overlay[count.index].display_name
  connectivity_path   = data.nsxt_policy_tier1_gateway.tier1s_for_segments_overlay[count.index].path
  transport_zone_path = data.nsxt_policy_transport_zone.tzs_for_segments_overlay[count.index].path
  subnet {
    cidr        = "${cidrhost(var.nsx.config.segments_overlay[count.index].cidr, var.nsx.config.segments_overlay[count.index].gw)}/${split("/", var.nsx.config.segments_overlay[count.index].cidr)[1]}"
  }
}