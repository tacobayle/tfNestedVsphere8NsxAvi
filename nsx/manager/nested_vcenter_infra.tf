data "vsphere_datacenter" "dc_nested" {
  name = var.vcenter.datacenter
}

data "vsphere_compute_cluster" "compute_cluster_nested" {
  name          = var.vcenter.cluster
  datacenter_id = data.vsphere_datacenter.dc_nested.id
}

data "vsphere_datastore" "datastore_nested" {
  name = "vsanDatastore"
  datacenter_id = data.vsphere_datacenter.dc_nested.id
}

data "vsphere_resource_pool" "resource_pool_nested" {
  name          = "${var.vcenter.cluster}/Resources"
  datacenter_id = data.vsphere_datacenter.dc_nested.id
}


data "vsphere_network" "vcenter_network_mgmt_nested" {
  name = var.vcenter.vds.portgroup.management.name
  datacenter_id = data.vsphere_datacenter.dc_nested.id
}