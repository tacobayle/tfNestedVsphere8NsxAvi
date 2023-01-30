provider "vsphere" {
  user           = "administrator@${var.vcenter.sso.domain_name}"
  password       = var.vcenter_password
  vsphere_server = "${var.vcenter.name}.${var.external_gw.bind.domain}"
  allow_unverified_ssl = true
}

provider "nsxt" {
  host                     = var.vcenter.vds.portgroup.management.nsx_ip
  username                 = "admin"
  password                 = var.nsx_password
  allow_unverified_ssl     = true
  max_retries              = 10
  retry_min_delay          = 500
  retry_max_delay          = 5000
  retry_on_status_codes    = [429]
}