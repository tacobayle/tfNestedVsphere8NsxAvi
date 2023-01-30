resource "vsphere_content_library" "library_external_gw" {
  count = 1
  name            = "cl_tf_external_gw"
  storage_backing = [data.vsphere_datastore.datastore.id]
}

resource "vsphere_content_library_item" "file_external_gw" {
  count = 1
  name        = basename(var.vcenter_underlay.cl.ubuntu_focal_file_path)
  library_id  = vsphere_content_library.library_external_gw[0].id
  file_url = var.vcenter_underlay.cl.ubuntu_focal_file_path
}

data "template_file" "external_gw_userdata" {
  count = 1
  template = file("${path.module}/userdata/external_gw.userdata")
  vars = {
    pubkey        = file(var.external_gw.public_key_path)
    username = var.external_gw.username
    ipCidr  = "${var.vcenter.vds.portgroup.management.external_gw_ip}/${var.vcenter.vds.portgroup.management.prefix}"
    ip = var.vcenter.vds.portgroup.management.external_gw_ip
    defaultGw = var.vcenter.vds.portgroup.management.gateway
    password      = var.ubuntu_password
    hostname = var.external_gw.name
    ansible_version = var.external_gw.ansible_version
    avi_sdk_version = var.external_gw.avi_sdk_version
    ip_vcenter = var.vcenter.vds.portgroup.management.vcenter_ip
    vcenter_name = var.vcenter.name
    dns_domain = var.external_gw.bind.domain
//    ip_data_cidr  = "${var.vcenter.vds.portgroup.nsx_external.external_gw_ip}/${var.vcenter.vds.portgroup.nsx_external.prefix}"
    dns      = join(", ", var.external_gw.bind.forwarders)
    netplanFile = var.external_gw.netplanFile
    privateKey = var.external_gw.private_key_path
    forwarders = join("; ", var.external_gw.bind.forwarders)
    domain = var.external_gw.bind.domain
    reverse = var.external_gw.bind.reverse
    keyName = var.external_gw.bind.keyName
    secret = base64encode(var.bind_password)
    ntp = var.external_gw.ntp
    lastOctet = split(".", var.vcenter.vds.portgroup.management.external_gw_ip)[3]
    vcenter_ip = var.vcenter.vds.portgroup.management.vcenter_ip
    vcenter_name = var.vcenter.name
  }
}

resource "vsphere_virtual_machine" "external_gw" {
  count = 1
  name             = var.external_gw.name
  datastore_id     = data.vsphere_datastore.datastore.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  folder           = "/${var.vcenter_underlay.dc}/vm/${var.vcenter_underlay.folder}"

  network_interface {
    network_id = data.vsphere_network.vcenter_underlay_network_mgmt.id
  }

//  network_interface {
//    network_id = data.vsphere_network.vcenter_underlay_network_external.id
//  }

  num_cpus = var.external_gw.cpu
  memory = var.external_gw.memory
  guest_id = "ubuntu64Guest"

  disk {
    size             = var.external_gw.disk
    label            = "${var.external_gw.name}.lab_vmdk"
    thin_provisioned = true
  }

  cdrom {
    client_device = true
  }

  clone {
    template_uuid = vsphere_content_library_item.file_external_gw[0].id
  }

  vapp {
    properties = {
      hostname    = var.external_gw.name
      public-keys = file(var.external_gw.public_key_path)
      user-data   = base64encode(data.template_file.external_gw_userdata[0].rendered)
    }
  }

  connection {
    host        = var.vcenter.vds.portgroup.management.external_gw_ip
    type        = "ssh"
    agent       = false
    user        = var.external_gw.username
    private_key = file(var.external_gw.private_key_path)
  }

  provisioner "remote-exec" {
    inline      = [
      "while [ ! -f /tmp/cloudInitDone.log ]; do sleep 1; done"
    ]
  }
}

resource "null_resource" "clear_ssh_key_external_gw_locally" {
  provisioner "local-exec" {
    command = "ssh-keygen -f \"/home/ubuntu/.ssh/known_hosts\" -R \"${var.vcenter.vds.portgroup.management.external_gw_ip}\" || true"
  }
}

resource "null_resource" "add_nic_to_gw_network_nsx_external" {
  depends_on = [vsphere_virtual_machine.external_gw]

  provisioner "local-exec" {
    command = <<-EOT
      export GOVC_USERNAME=${var.vsphere_username}
      export GOVC_PASSWORD=${var.vsphere_password}
      export GOVC_DATACENTER=${var.vcenter_underlay.dc}
      export GOVC_URL=${var.vcenter_underlay.server}
      export GOVC_CLUSTER=${var.vcenter_underlay.cluster}
      export GOVC_INSECURE=true
      /usr/local/bin/govc vm.network.add -vm "${var.external_gw.name}" -net "${var.vcenter_underlay.network_nsx_external.name}"
    EOT
  }
}

resource "null_resource" "add_nic_to_gw_network_nsx_overlay" {
  depends_on = [vsphere_virtual_machine.external_gw, null_resource.add_nic_to_gw_network_nsx_external]

  provisioner "local-exec" {
    command = <<-EOT
      export GOVC_USERNAME=${var.vsphere_username}
      export GOVC_PASSWORD=${var.vsphere_password}
      export GOVC_DATACENTER=${var.vcenter_underlay.dc}
      export GOVC_URL=${var.vcenter_underlay.server}
      export GOVC_CLUSTER=${var.vcenter_underlay.cluster}
      export GOVC_INSECURE=true
      /usr/local/bin/govc vm.network.add -vm "${var.external_gw.name}" -net "${var.vcenter_underlay.network_nsx_overlay.name}"
    EOT
  }
}

resource "null_resource" "add_nic_to_gw_network_nsx_overlay_edge" {
  depends_on = [vsphere_virtual_machine.external_gw, null_resource.add_nic_to_gw_network_nsx_external, null_resource.add_nic_to_gw_network_nsx_overlay]

  provisioner "local-exec" {
    command = <<-EOT
      export GOVC_USERNAME=${var.vsphere_username}
      export GOVC_PASSWORD=${var.vsphere_password}
      export GOVC_DATACENTER=${var.vcenter_underlay.dc}
      export GOVC_URL=${var.vcenter_underlay.server}
      export GOVC_CLUSTER=${var.vcenter_underlay.cluster}
      export GOVC_INSECURE=true
      /usr/local/bin/govc vm.network.add -vm "${var.external_gw.name}" -net "${var.vcenter_underlay.network_nsx_overlay_edge.name}"
    EOT
  }
}

resource "null_resource" "adding_ip_to_nsx_external" {
  depends_on = [null_resource.add_nic_to_gw_network_nsx_external, null_resource.add_nic_to_gw_network_nsx_overlay, null_resource.add_nic_to_gw_network_nsx_overlay_edge]
  count = 1

  connection {
    host        = var.vcenter.vds.portgroup.management.external_gw_ip
    type        = "ssh"
    agent       = false
    user        = var.external_gw.username
    private_key = file(var.external_gw.private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "iface=`ip -o link show | awk -F': ' '{print $2}' | head -2 | tail -1`",
      "mac=`ip -o link show | awk -F'link/ether ' '{print $2}' | awk -F' ' '{print $1}' | head -2 | tail -1`",
      "ifaceSecond=`ip -o link show | awk -F': ' '{print $2}' | head -3 | tail -1`",
      "macSecond=`ip -o link show | awk -F'link/ether ' '{print $2}' | awk -F' ' '{print $1}' | head -3 | tail -1`",
      "sudo ip link set dev $ifaceThird mtu ${var.vcenter.vds.portgroup.nsx_overlay.max_mtu}",
      "sudo ip link set dev $ifaceLastName mtu ${var.vcenter.vds.portgroup.nsx_overlay_edge.max_mtu}",
      "echo \"network:\" | sudo tee ${var.external_gw.netplanFile}",
      "echo \"    ethernets:\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"        $iface:\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"            dhcp4: false\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"            addresses: [${var.vcenter.vds.portgroup.management.external_gw_ip}/${var.vcenter.vds.portgroup.management.prefix}]\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"            match:\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"                macaddress: $mac\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"            set-name: $iface\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"            gateway4: ${var.vcenter.vds.portgroup.management.gateway}\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"            nameservers:\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"              addresses: [${join(", ", var.external_gw.bind.forwarders)}]\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"        $ifaceSecond:\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"            dhcp4: false\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"            addresses: [${var.vcenter.vds.portgroup.nsx_external.external_gw_ip}/${var.vcenter.vds.portgroup.nsx_external.prefix}]\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"            routes:\" | sudo tee -a ${var.external_gw.netplanFile}",
    ]
  }
}

resource "null_resource" "set_initial_state" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = "echo \"0\" > current_state.txt"
  }
}




resource "null_resource" "update_ip_routes" {
  depends_on = [null_resource.adding_ip_to_nsx_external, null_resource.set_initial_state]
  count = length(var.external_gw.routes)

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = "while [[ $(cat current_state.txt) != \"${count.index}\" ]]; do echo \"${count.index} is waiting...\";sleep 5;done"
  }


  connection {
    host        = var.vcenter.vds.portgroup.management.external_gw_ip
    type        = "ssh"
    agent       = false
    user        = var.external_gw.username
    private_key = file(var.external_gw.private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "echo \"            - to: ${var.external_gw.routes[count.index].to}\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"              via: ${var.external_gw.routes[count.index].via}\" | sudo tee -a ${var.external_gw.netplanFile}"
    ]
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = "echo \"${count.index+1}\" > current_state.txt"
  }

}



resource "null_resource" "adding_ip_to_nsx_overlay_and_nsx_overlay_edge" {
  depends_on = [null_resource.update_ip_routes]
  count = 1

  connection {
    host        = var.vcenter.vds.portgroup.management.external_gw_ip
    type        = "ssh"
    agent       = false
    user        = var.external_gw.username
    private_key = file(var.external_gw.private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "iface=`ip -o link show | awk -F': ' '{print $2}' | head -2 | tail -1`",
      "ifaceSecond=`ip -o link show | awk -F': ' '{print $2}' | head -3 | tail -1`",
      "macSecond=`ip -o link show | awk -F'link/ether ' '{print $2}' | awk -F' ' '{print $1}' | head -3 | tail -1`",
      "ifaceThird=`ip -o link show | awk -F': ' '{print $2}' | head -4 | tail -1`",
      "macThird=`ip -o link show | awk -F'link/ether ' '{print $2}' | awk -F' ' '{print $1}' | head -4 | tail -1`",
      "ifaceLastName=`ip -o link show | awk -F': ' '{print $2}' | tail -1`",
      "macLast=`ip -o link show | awk -F'link/ether ' '{print $2}' | awk -F' ' '{print $1}'| tail -1`",
      "echo \"            match:\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"                macaddress: $macSecond\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"            set-name: $ifaceSecond\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"        $ifaceThird:\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"            dhcp4: false\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"            addresses: [${var.nsx.config.ip_pools[0].gateway}/${split("/", var.nsx.config.ip_pools[0].cidr)[1]}]\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"            match:\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"                macaddress: $macThird\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"            set-name: $ifaceThird\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"            mtu: ${var.vcenter.vds.portgroup.nsx_overlay.max_mtu}\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"        $ifaceLastName:\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"            dhcp4: false\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"            addresses: [${var.nsx.config.ip_pools[1].gateway}/${split("/", var.nsx.config.ip_pools[1].cidr)[1]}]\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"            match:\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"                macaddress: $macLast\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"            set-name: $ifaceLastName\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"            mtu: ${var.vcenter.vds.portgroup.nsx_overlay_edge.max_mtu}\" | sudo tee -a ${var.external_gw.netplanFile}",
      "echo \"    version: 2\" | sudo tee -a ${var.external_gw.netplanFile}",
      "sudo netplan apply",
      "sudo sysctl -w net.ipv4.ip_forward=1",
      "echo \"net.ipv4.ip_forward=1\" | sudo tee -a /etc/sysctl.conf",
      "sudo iptables -t nat -A POSTROUTING -o $iface -j MASQUERADE",
      "sudo iptables -A FORWARD -i $ifaceSecond -o $iface -j ACCEPT",
      "sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT",
      "sudo service ntp stop",
      "sleep 5",
      "sudo service ntp start",
    ]
  }
}