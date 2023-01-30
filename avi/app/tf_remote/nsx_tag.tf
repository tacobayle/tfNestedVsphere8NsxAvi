resource "nsxt_vm_tags" "avi_app_tag" {
  count = length(var.avi.app.ips) - 1
  instance_id = vsphere_virtual_machine.avi_app[count.index].id
  tag {
    tag   = var.avi.app.nsxt_vm_tags
  }
}

resource "nsxt_policy_group" "backend" {
  display_name = var.avi.app.nsxt_group_name

  criteria {
    condition {
      key = "Tag"
      member_type = "VirtualMachine"
      operator = "EQUALS"
      value = var.avi.app.nsxt_vm_tags
    }
  }
}