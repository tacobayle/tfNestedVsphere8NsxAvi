data "vsphere_datacenter" "dc" {
  name = var.vcenter_underlay.dc
}

data "vsphere_compute_cluster" "compute_cluster" {
  name          = var.vcenter_underlay.cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "datastore" {
  name = var.vcenter_underlay.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  name          = var.vcenter_underlay.resource_pool
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "esxi_networks" {
  count = length(values(var.vcenter_underlay.networks))
  name = values(var.vcenter_underlay.networks)[count.index].name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "vcenter_underlay_network_mgmt" {
  count = 1
  name = var.vcenter_underlay.networks.management.name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network_nsx_external" {
  count = 1
  name = var.vcenter_underlay.network_nsx_external.name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network_nsx_overlay" {
  count = 1
  name = var.vcenter_underlay.network_nsx_overlay.name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network_nsx_overlay_edge" {
  count = 1
  name = var.vcenter_underlay.network_nsx_overlay_edge.name
  datacenter_id = data.vsphere_datacenter.dc.id
}