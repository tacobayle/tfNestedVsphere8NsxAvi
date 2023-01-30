data "template_file" "environment_variables" {
  template = file("templates/environment_variables.json.template")
  vars = {
    vcenter_password = var.vcenter_password
    avi_password = var.avi_password
  }
}

resource "null_resource" "tf_avi_controller" {

  connection {
    host = var.vcenter.vds.portgroup.management.external_gw_ip
    type = "ssh"
    agent = false
    user = var.external_gw.username
    private_key = file(var.external_gw.private_key_path)
  }

  provisioner "file" {
    source = var.avi.content_library.ova_location
    destination = basename(var.avi.content_library.ova_location)
  }

  provisioner "file" {
    source = "../../avi.json"
    destination = "avi.json"
  }

  provisioner "file" {
    source = "tf_remote"
    destination = "tf_remote_avi_controller"
  }

  provisioner "file" {
    content = data.template_file.environment_variables.rendered
    destination = ".environment_variables.json"
  }

  provisioner "remote-exec" {
    inline = [
      "cd tf_remote_avi_controller",
      "terraform init",
      "terraform apply -auto-approve -var-file=../avi.json -var-file=../.environment_variables.json"
    ]
  }
}