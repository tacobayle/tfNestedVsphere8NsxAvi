provider "vsphere" {
  user           = "administrator@${var.vcenter.sso.domain_name}"
  password       = var.vcenter_password
  vsphere_server = "${var.vcenter.name}.${var.external_gw.bind.domain}"
  allow_unverified_ssl = true
}