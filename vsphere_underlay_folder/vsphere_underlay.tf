data "vsphere_datacenter" "dc" {
  name = var.vcenter_underlay.dc
}

resource "vsphere_folder" "esxi_folder" {
  path          = var.vcenter_underlay.folder
  type          = "vm"
  datacenter_id = data.vsphere_datacenter.dc.id
}