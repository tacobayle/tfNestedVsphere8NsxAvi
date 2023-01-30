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

resource "vsphere_content_library" "nested_library_avi" {
  name            = var.avi.config.content_library_avi
  storage_backing = [data.vsphere_datastore.datastore_nested.id]
}

resource "vsphere_folder" "se_groups_folders" {
  count            = length(var.avi.config.service_engine_groups)
  path          = var.avi.config.service_engine_groups[count.index].vcenter_folder
  type          = "vm"
  datacenter_id = data.vsphere_datacenter.dc_nested.id
}