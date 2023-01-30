resource "dns_a_record_set" "esxi" {
  depends_on = [vsphere_virtual_machine.external_gw]
  count = length(var.vcenter.vds.portgroup.management.esxi_ips)
  zone  = "${var.external_gw.bind.domain}."
  name  = "${var.esxi.basename}${count.index + 1}"
  addresses = [element(var.vcenter.vds.portgroup.management.esxi_ips, count.index)]
  ttl = 60
}

resource "dns_a_record_set" "nsx" {
  depends_on = [vsphere_virtual_machine.external_gw]
  count = 1
  zone  = "${var.external_gw.bind.domain}."
  name  = "${var.nsx.manager.basename}"
  addresses = [var.vcenter.vds.portgroup.management.nsx_ip]
  ttl = 60
}

resource "dns_cname_record" "nsx_cname" {
  depends_on = [dns_a_record_set.nsx, vsphere_virtual_machine.external_gw]
  zone  = "${var.external_gw.bind.domain}."
  name  = "nsx"
  cname = "${var.nsx.manager.basename}.${var.external_gw.bind.domain}."
  ttl   = 300
}

resource "dns_ptr_record" "esxi" {
  depends_on = [vsphere_virtual_machine.external_gw]
  count = length(var.vcenter.vds.portgroup.management.esxi_ips)
  zone = "${var.external_gw.bind.reverse}.in-addr.arpa."
  name = split(".", element(var.vcenter.vds.portgroup.management.esxi_ips, count.index))[3]
  ptr  = "${var.esxi.basename}${count.index + 1}.${var.external_gw.bind.domain}."
  ttl  = 60
}

resource "dns_a_record_set" "vcenter" {
  count = 1
  depends_on = [vsphere_virtual_machine.external_gw]
  zone  = "${var.external_gw.bind.domain}."
  name  = var.vcenter.name
  addresses = [var.vcenter.vds.portgroup.management.vcenter_ip]
  ttl = 60
}

resource "dns_cname_record" "vcenter_cname" {
  depends_on = [dns_a_record_set.vcenter, vsphere_virtual_machine.external_gw]
  zone  = "${var.external_gw.bind.domain}."
  name  = "vcenter"
  cname = "${var.vcenter.name}.${var.external_gw.bind.domain}."
  ttl   = 300
}

resource "dns_ptr_record" "vcenter" {
  count = 1
  depends_on = [vsphere_virtual_machine.external_gw]
  zone = "${var.external_gw.bind.reverse}.in-addr.arpa."
  name = split(".", var.vcenter.vds.portgroup.management.vcenter_ip)[3]
  ptr  = "${var.vcenter.name}.${var.external_gw.bind.domain}."
  ttl  = 60
}