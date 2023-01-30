resource "vsphere_folder" "nsx" {
  count            = (var.nsx.manager.create == true ? 1 : 0)
  path          = "nsx"
  type          = "vm"
  datacenter_id = data.vsphere_datacenter.dc_nested.id
}

# https://docs.vmware.com/en/VMware-NSX-T-Data-Center/3.1/installation/GUID-AECA2EE0-90FC-48C4-8EDB-66517ACFE415.html

resource "vsphere_virtual_machine" "nsx_extra_small" {
  count            = (var.nsx.manager.create == true && var.nsx.manager.deployment == "Extra Small" ? 1 : 0)
  name             = "${var.nsx.manager.basename}-${count.index}"
  datastore_id     = data.vsphere_datastore.datastore_nested.id
  resource_pool_id = data.vsphere_resource_pool.resource_pool_nested.id
  folder           = vsphere_folder.nsx[0].path
  wait_for_guest_net_timeout = 10

  network_interface {
    network_id = data.vsphere_network.vcenter_network_mgmt_nested.id
  }

  num_cpus = 2
  memory = 8192

  disk {
    size             = 200
    label            = "{var.nsx.manager.basename}-${count.index}.lab_vmdk"
    thin_provisioned = true
  }

  clone {
    template_uuid = vsphere_content_library_item.nested_library_nsx_item[0].id
  }

  vapp {
    properties = {
      nsx_allowSSHRootLogin = "True"
      nsx_cli_audit_passwd_0 = var.nsx_password
      nsx_cli_passwd_0 = var.nsx_password
      nsx_dns1_0 = var.vcenter.vds.portgroup.management.external_gw_ip
      nsx_gateway_0 = var.vcenter.vds.portgroup.management.gateway
      nsx_hostname = "${var.nsx.manager.basename}-${count.index}"
      nsx_ip_0 = var.vcenter.vds.portgroup.management.nsx_ip
      nsx_isSSHEnabled = "True"
      nsx_netmask_0 = var.vcenter.vds.portgroup.management.netmask
      nsx_ntp_0 = var.vcenter.vds.portgroup.management.external_gw_ip
      nsx_passwd_0 = var.nsx_password
      nsx_role = var.nsx.manager.role
      nsx_swIntegrityCheck = "False"
    }
  }
}

resource "vsphere_virtual_machine" "nsx_small" {
  count            = (var.nsx.manager.create == true && var.nsx.manager.deployment == "Small" ? 1 : 0)
  name             = "${var.nsx.manager.basename}-${count.index}"
  datastore_id     = data.vsphere_datastore.datastore_nested.id
  resource_pool_id = data.vsphere_resource_pool.resource_pool_nested.id
  folder           = vsphere_folder.nsx[0].path
  wait_for_guest_net_timeout = 10
  //  deployment_option = var.nsx.manager.deployment

  network_interface {
    network_id = data.vsphere_network.vcenter_network_mgmt_nested.id
  }

  num_cpus = 4
  memory = 16384

  disk {
    size             = 200
    label            = "{var.nsx.manager.basename}-${count.index}.lab_vmdk"
    thin_provisioned = true
  }

  clone {
    template_uuid = vsphere_content_library_item.nested_library_nsx_item[0].id
  }

  vapp {
    properties = {
      nsx_allowSSHRootLogin = "True"
      nsx_cli_audit_passwd_0 = var.nsx_password
      nsx_cli_passwd_0 = var.nsx_password
      nsx_dns1_0 = var.vcenter.vds.portgroup.management.external_gw_ip
      nsx_gateway_0 = var.vcenter.vds.portgroup.management.gateway
      nsx_hostname = "${var.nsx.manager.basename}-${count.index}"
      nsx_ip_0 = var.vcenter.vds.portgroup.management.nsx_ip
      nsx_isSSHEnabled = "True"
      nsx_netmask_0 = var.vcenter.vds.portgroup.management.netmask
      nsx_ntp_0 = var.vcenter.vds.portgroup.management.external_gw_ip
      nsx_passwd_0 = var.nsx_password
      nsx_role = var.nsx.manager.role
      nsx_swIntegrityCheck = "False"
    }
  }
}

resource "vsphere_virtual_machine" "nsx_medium" {
  count            = (var.nsx.manager.create == true && var.nsx.manager.deployment == "Medium" ? 1 : 0)
  name             = "${var.nsx.manager.basename}-${count.index}"
  datastore_id     = data.vsphere_datastore.datastore_nested.id
  resource_pool_id = data.vsphere_resource_pool.resource_pool_nested.id
  folder           = vsphere_folder.nsx[0].path
  wait_for_guest_net_timeout = 10
//  deployment_option = var.nsx.manager.deployment

  network_interface {
    network_id = data.vsphere_network.vcenter_network_mgmt_nested.id
  }

  num_cpus = 6
  memory = 24576

  disk {
    size             = 200
    label            = "{var.nsx.manager.basename}-${count.index}.lab_vmdk"
    thin_provisioned = true
  }

  clone {
    template_uuid = vsphere_content_library_item.nested_library_nsx_item[0].id
  }

  vapp {
    properties = {
      nsx_allowSSHRootLogin = "True"
      nsx_cli_audit_passwd_0 = var.nsx_password
      nsx_cli_passwd_0 = var.nsx_password
      nsx_dns1_0 = var.vcenter.vds.portgroup.management.external_gw_ip
      nsx_gateway_0 = var.vcenter.vds.portgroup.management.gateway
      nsx_hostname = "${var.nsx.manager.basename}-${count.index}"
      nsx_ip_0 = var.vcenter.vds.portgroup.management.nsx_ip
      nsx_isSSHEnabled = "True"
      nsx_netmask_0 = var.vcenter.vds.portgroup.management.netmask
      nsx_ntp_0 = var.vcenter.vds.portgroup.management.external_gw_ip
      nsx_passwd_0 = var.nsx_password
      nsx_role = var.nsx.manager.role
      nsx_swIntegrityCheck = "False"
    }
  }
}

resource "vsphere_virtual_machine" "nsx_large" {
  count            = (var.nsx.manager.create == true && var.nsx.manager.deployment == "Large" ? 1 : 0)
  name             = "${var.nsx.manager.basename}-${count.index}"
  datastore_id     = data.vsphere_datastore.datastore_nested.id
  resource_pool_id = data.vsphere_resource_pool.resource_pool_nested.id
  folder           = vsphere_folder.nsx[0].path
  wait_for_guest_net_timeout = 10

  network_interface {
    network_id = data.vsphere_network.vcenter_network_mgmt_nested.id
  }

  num_cpus = 12
  memory = 49152

  disk {
    size             = 200
    label            = "{var.nsx.manager.basename}-${count.index}.lab_vmdk"
    thin_provisioned = true
  }

  clone {
    template_uuid = vsphere_content_library_item.nested_library_nsx_item[0].id
  }

  vapp {
    properties = {
      nsx_allowSSHRootLogin = "True"
      nsx_cli_audit_passwd_0 = var.nsx_password
      nsx_cli_passwd_0 = var.nsx_password
      nsx_dns1_0 = var.vcenter.vds.portgroup.management.external_gw_ip
      nsx_gateway_0 = var.vcenter.vds.portgroup.management.gateway
      nsx_hostname = "${var.nsx.manager.basename}-${count.index}"
      nsx_ip_0 = var.vcenter.vds.portgroup.management.nsx_ip
      nsx_isSSHEnabled = "True"
      nsx_netmask_0 = var.vcenter.vds.portgroup.management.netmask
      nsx_ntp_0 = var.vcenter.vds.portgroup.management.external_gw_ip
      nsx_passwd_0 = var.nsx_password
      nsx_role = var.nsx.manager.role
      nsx_swIntegrityCheck = "False"
    }
  }
}

resource "null_resource" "wait_nsx" {
  depends_on = [vsphere_virtual_machine.nsx_extra_small, vsphere_virtual_machine.nsx_small, vsphere_virtual_machine.nsx_medium, vsphere_virtual_machine.nsx_large]

  provisioner "local-exec" {
    command = "count=1 ; until $(curl --output /dev/null --silent --head -k https://${var.vcenter.vds.portgroup.management.nsx_ip}); do echo \"Attempt $count: Waiting for NSX Manager to be reachable...\"; sleep 30 ; count=$((count+1)) ;  if [ \"$count\" = 60 ]; then echo \"ERROR: Unable to connect to NSX Manager\" ; exit 1 ; fi ; done"
  }
}