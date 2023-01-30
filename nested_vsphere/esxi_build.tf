resource "local_file" "ks_cust_multiple_vswitch" {
  count = var.esxi.count
  content     = templatefile("${path.module}/templates/ks_cust_multiple_vswitch.cfg.tmpl",
  { esxi_root_password = var.esxi_root_password,
    keyboard_type = var.esxi.keyboard_type,
    ip_mgmt = var.vcenter.vds.portgroup.management.esxi_ips[count.index],
    netmask = var.vcenter.vds.portgroup.management.netmask,
    gateway = var.vcenter.vds.portgroup.management.gateway,
    ip_vmotion = var.vcenter.vds.portgroup.VMotion.esxi_ips[count.index],
    netmask_vmotion = var.vcenter.vds.portgroup.VMotion.netmask,
    ip_vsan = var.vcenter.vds.portgroup.VSAN.esxi_ips[count.index],
    netmask_vsan = var.vcenter.vds.portgroup.VSAN.netmask,
    ntp = var.vcenter.vds.portgroup.management.external_gw_ip,
    nameserver = var.vcenter.vds.portgroup.management.external_gw_ip,
    hostname = "${var.esxi.basename}${count.index + 1}.${var.external_gw.bind.domain}"
  }
  )
  filename = "${path.module}/ks_cust.cfg.${count.index}"
}

resource "null_resource" "iso_build" {
  depends_on = [local_file.ks_cust_multiple_vswitch]
  provisioner "local-exec" {
    command = "/bin/bash iso_esxi_build.sh"
  }
}

resource "vsphere_file" "iso_upload" {
  depends_on = [null_resource.iso_build]
  count = var.esxi.count
  datacenter       = var.vcenter_underlay.dc
  datastore        = var.vcenter_underlay.datastore
  source_file      = "${var.esxi.iso_location}${count.index}.iso"
  destination_file = "isos/${basename(var.esxi.iso_location)}${count.index}.iso"
}

resource "null_resource" "iso_destroy" {
  depends_on = [vsphere_file.iso_upload]
  provisioner "local-exec" {
    command = "/bin/bash iso_esxi_destroy.sh"
  }
}

resource "vsphere_virtual_machine" "esxi_host" {
  depends_on = [ vsphere_file.iso_upload ]
  count = var.esxi.count
  name             = "${var.esxi.basename}${count.index + 1}"
  datastore_id     = data.vsphere_datastore.datastore.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  folder           = "/${var.vcenter_underlay.dc}/vm/${var.vcenter_underlay.folder}"

  dynamic "network_interface" {
    for_each = data.vsphere_network.esxi_networks
    content {
      network_id = network_interface.value["id"]
    }
  }

  dynamic "network_interface" {
    for_each = data.vsphere_network.esxi_networks
    content {
      network_id = network_interface.value["id"]
    }
  }

  network_interface {
    network_id = data.vsphere_network.network_nsx_external[0].id
  }

  network_interface {
    network_id = data.vsphere_network.network_nsx_overlay[0].id
  }

  network_interface {
    network_id = data.vsphere_network.network_nsx_overlay_edge[0].id
  }

  num_cpus = var.esxi.cpu
  memory = var.esxi.memory
  guest_id = var.esxi.guest_id
  wait_for_guest_net_timeout = var.esxi.wait_for_guest_net_timeout
  nested_hv_enabled = var.esxi.nested_hv_enabled
  firmware = var.esxi.bios

  dynamic "disk" {
    for_each = var.esxi.disks
    content {
      size = disk.value["size"]
      label = "${var.esxi.basename}${count.index + 1}-${disk.value["label"]}.lab_vmdk"
      unit_number = disk.value["unit_number"]
      thin_provisioned = disk.value["thin_provisioned"]
    }
  }

  cdrom {
    datastore_id = data.vsphere_datastore.datastore.id
    path         = "isos/${basename(var.esxi.iso_location)}${count.index}.iso"
  }
}

resource "null_resource" "wait_esxi" {
  depends_on = [vsphere_virtual_machine.esxi_host]
  count = var.esxi.count

  provisioner "local-exec" {
    command = "count=1 ; until $(curl --output /dev/null --silent --head -k https://${var.vcenter.vds.portgroup.management.esxi_ips[count.index]}); do echo \"Attempt $count: Waiting for ESXi host ${count.index} to be reachable...\"; sleep 40 ; count=$((count+1)) ;  if [ \"$count\" = 30 ]; then echo \"ERROR: Unable to connect to ESXi host\" ; exit 1 ; fi ; done"
  }
}

resource "null_resource" "esxi_customization_disk" {
  depends_on = [null_resource.wait_esxi]

  provisioner "local-exec" {
    command = "/bin/bash esxi_customization_disk.sh"
  }
}

resource "null_resource" "vcenter_underlay_clean_up" {
  depends_on = [null_resource.esxi_customization_disk]

  provisioner "local-exec" {
    command = "/bin/bash vcenter_underlay_clean_up.sh"
  }
}

resource "null_resource" "clear_ssh_key_esxi_locally" {
  count = length(var.vcenter.vds.portgroup.management.esxi_ips)
  provisioner "local-exec" {
    command = "ssh-keygen -f \"/home/ubuntu/.ssh/known_hosts\" -R \"${var.vcenter.vds.portgroup.management.esxi_ips[count.index]}\" || true"
  }
}