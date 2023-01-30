data "template_file" "environment_variables" {
  template = file("templates/environment_variables.json.template")
  vars = {
    vcenter_password = var.vcenter_password
    avi_password = var.avi_password
    docker_registry_username = var.docker_registry_username
    docker_registry_password = var.docker_registry_password
    ubuntu_password = var.ubuntu_password
    nsx_password = var.nsx_password
  }
}

resource "null_resource" "tf_avi_app" {

  connection {
    host = var.vcenter.vds.portgroup.management.external_gw_ip
    type = "ssh"
    agent = false
    user = var.external_gw.username
    private_key = file(var.external_gw.private_key_path)
  }

  provisioner "file" {
    source = var.avi.app.public_key_path
    destination = basename(var.avi.app.public_key_path)
  }

  provisioner "file" {
    source = var.avi.app.private_key_path
    destination = basename(var.avi.app.private_key_path)
  }

  provisioner "file" {
    source = var.avi.app.ova_location
    destination = basename(var.avi.app.ova_location)
  }

  provisioner "file" {
    source = "../../app.json"
    destination = "app.json"
  }

  provisioner "file" {
    source = "tf_remote"
    destination = "tf_remote_avi_app"
  }

  provisioner "file" {
    content = data.template_file.environment_variables.rendered
    destination = ".environment_variables_app.json"
  }

  provisioner "remote-exec" {
    inline = [
      "cd tf_remote_avi_app",
      "terraform init",
      "terraform apply -auto-approve -var-file=../app.json -var-file=../.environment_variables_app.json",
    ]
  }
}