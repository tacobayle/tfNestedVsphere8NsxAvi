resource "vsphere_content_library" "nested_library_nsx" {
  count = (var.nsx.manager.create == true || var.nsx.content_library.create == true ? 1 : 0)
  name            = "NSX Library"
  storage_backing = [data.vsphere_datastore.datastore_nested.id]
}

resource "vsphere_content_library_item" "nested_library_nsx_item" {
  count = (var.nsx.manager.create == true || var.nsx.content_library.create == true ? 1 : 0)
  name            = basename(var.nsx.content_library.ova_location)
  library_id      = vsphere_content_library.nested_library_nsx[0].id
  file_url        = var.nsx.content_library.ova_location
}