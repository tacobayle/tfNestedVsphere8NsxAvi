resource "null_resource" "ansible_hosts_avi_header_1" {
  provisioner "local-exec" {
    command = "echo '---' | tee hosts_avi; echo 'all:' | tee -a hosts_avi ; echo '  children:' | tee -a hosts_avi; echo '    controller:' | tee -a hosts_avi; echo '      hosts:' | tee -a hosts_avi"
  }
}

resource "null_resource" "ansible_hosts_avi_controllers" {
  depends_on = [null_resource.ansible_hosts_avi_header_1]
  provisioner "local-exec" {
    command = "echo '        ${cidrhost(var.avi.controller.cidr, var.avi.controller.ip)}:' | tee -a hosts_avi "
  }
}

data "template_file" "values" {
  template = file("templates/values_nsx.yml.template")
  vars = {
    avi_version = var.avi.controller.version
    controllerPrivateIp = cidrhost(var.avi.controller.cidr, var.avi.controller.ip)
    avi_old_password =  jsonencode(var.avi_old_password)
    avi_password = jsonencode(var.avi_password)
    avi_username = jsonencode(var.avi_username)
    ntp = var.vcenter.vds.portgroup.management.external_gw_ip
    dns = var.vcenter.vds.portgroup.management.external_gw_ip
    nsx_password = var.nsx_password
    nsx_server = var.vcenter.vds.portgroup.management.nsx_ip
    domain = var.external_gw.bind.domain
    cloud_name = var.avi.config.cloud.name
    cloud_obj_name_prefix = var.avi.config.cloud.obj_name_prefix
    transport_zone_name = var.avi.config.transport_zone_name
    network_management = jsonencode(var.avi.config.cloud.network_management)
    networks_data = jsonencode(var.avi.config.cloud.networks_data)
    sso_domain = var.vcenter.sso.domain_name
    vcenter_password = var.vcenter_password
    vcenter_ip = var.vcenter.vds.portgroup.management.vcenter_ip
    content_library = var.avi.config.content_library_avi
    service_engine_groups = jsonencode(var.avi.config.service_engine_groups)
    pools = jsonencode(var.avi.config.pools)
    virtual_services = jsonencode(var.avi.config.virtual_services)
  }
}


resource "null_resource" "ansible_avi" {
  depends_on = [null_resource.ansible_hosts_avi_controllers, vsphere_content_library.nested_library_avi, vsphere_folder.se_groups_folders]

  connection {
    host = var.vcenter.vds.portgroup.management.external_gw_ip
    type = "ssh"
    agent = false
    user        = var.external_gw.username
    private_key = file(var.external_gw.private_key_path)
  }

  provisioner "file" {
    source = "hosts_avi"
    destination = "hosts_avi"
  }

  provisioner "file" {
    content = data.template_file.values.rendered
    destination = "values.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "git clone ${var.avi.config.avi_config_repo} --branch ${var.avi.config.avi_config_tag}",
      "cd ${split("/", var.avi.config.avi_config_repo)[4]}",
      "ansible-playbook -i ../hosts_avi nsx.yml --extra-vars @../values.yml"
    ]
  }
}