data "vsphere_datacenter" "dc_nested" {
  count            = 1
  name = var.vcenter.datacenter
}

data "vsphere_compute_cluster" "compute_cluster_nested" {
  count            = 1
  name          = var.vcenter.cluster
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
}

data "vsphere_datastore" "datastore_nested" {
  count            = 1
  name = "vsanDatastore"
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
}

data "vsphere_resource_pool" "resource_pool_nested" {
  count            = 1
  name          = "${var.vcenter.cluster}/Resources"
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
}

data "vsphere_network" "vcenter_network_mgmt_nested" {
  count = 1
  name = var.avi.controller.network_ref
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
}

resource "vsphere_content_library" "nested_library_avi" {
  count = 1
  name            = "avi_controller"
  storage_backing = [data.vsphere_datastore.datastore_nested[0].id]
  description     = "avi_controller"
}

resource "vsphere_content_library_item" "nested_library_avi_item" {
  count = 1
  name        = basename(var.avi.content_library.ova_location)
  description = basename(var.avi.content_library.ova_location)
  library_id  = vsphere_content_library.nested_library_avi[0].id
  file_url = "../${basename(var.avi.content_library.ova_location)}"
}
