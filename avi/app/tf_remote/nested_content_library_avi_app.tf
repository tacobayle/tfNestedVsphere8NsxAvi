resource "vsphere_content_library" "nested_library_avi_app" {
  name            = "avi_app"
  storage_backing = [data.vsphere_datastore.datastore_nested.id]
}

resource "vsphere_content_library_item" "nested_library_item_avi_app" {
  name        = basename(var.avi.app.ova_location)
  library_id  = vsphere_content_library.nested_library_avi_app.id
  file_url = "../${basename(var.avi.app.ova_location)}"
}
