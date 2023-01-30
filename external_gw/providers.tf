provider "vsphere" {
  user           = var.vsphere_username
  password       = var.vsphere_password
  vsphere_server = var.vcenter_underlay.server
  allow_unverified_ssl = true
}

provider "dns" {
  update {
    server        = var.vcenter.vds.portgroup.management.external_gw_ip
    key_name      = "${var.external_gw.bind.keyName}."
    key_algorithm = "hmac-md5"
    key_secret    = base64encode(var.bind_password)
  }
}