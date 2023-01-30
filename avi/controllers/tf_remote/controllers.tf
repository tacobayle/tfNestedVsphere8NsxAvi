resource "vsphere_folder" "avi" {
  count            = var.avi.controller.create == true ? 1 : 0
  path          = "avi-controllers"
  type          = "vm"
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
}

resource "vsphere_virtual_machine" "controller" {
  count = var.avi.controller.create == true ? 1 : 0
  name             = "${var.avi.controller.basename}-${count.index + 1}"
  datastore_id     = data.vsphere_datastore.datastore_nested[0].id
  resource_pool_id = data.vsphere_resource_pool.resource_pool_nested[0].id
  folder           = vsphere_folder.avi[0].path

  network_interface {
    network_id = data.vsphere_network.vcenter_network_mgmt_nested[0].id
  }

  num_cpus = var.avi.controller.cpu
  memory = var.avi.controller.memory
  wait_for_guest_net_timeout = 4
  guest_id = "ubuntu64Guest"

  disk {
    size             = var.avi.controller.disk
    label            = "controller--${count.index + 1}.lab_vmdk"
    thin_provisioned = true
  }

  clone {
    template_uuid = vsphere_content_library_item.nested_library_avi_item[0].id
  }

  vapp {
    properties = {
      "mgmt-ip"     = cidrhost(var.avi.controller.cidr, var.avi.controller.ip)
      "mgmt-mask"   = cidrnetmask(var.avi.controller.cidr)
      "default-gw"  = cidrhost(var.avi.controller.cidr, var.avi.controller.gw)
    }
  }
}

resource "null_resource" "wait_https_controller" {
  depends_on = [vsphere_virtual_machine.controller]
  count = var.avi.controller.create == true ? 1 : 0

  provisioner "local-exec" {
    command = "until $(curl --output /dev/null --silent --head -k https://${cidrhost(var.avi.controller.cidr, var.avi.controller.ip)}); do echo 'Waiting for Avi Controllers to be ready'; sleep 60 ; done"
  }
}

