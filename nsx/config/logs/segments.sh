#!/bin/bash
#
if [ -f "../../variables.json" ]; then
  jsonFile="../../variables.json"
else
  echo "ERROR: no json file found"
  exit 1
fi
nsx_ip=$(jq -r .vcenter.vds.portgroup.management.nsx_ip $jsonFile)
vcenter_username=administrator
vcenter_domain=$(jq -r .vcenter.sso.domain_name $jsonFile)
vcenter_fqdn="$(jq -r .vcenter.name $jsonFile).$(jq -r .external_gw.bind.domain $jsonFile)"
rm -f cookies.txt headers.txt
curl -k -c cookies.txt -D headers.txt -X POST -d 'j_username=admin&j_password='$TF_VAR_nsx_password'' https://$nsx_ip/api/session/create
curl -k -s -X GET -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" https://$nsx_ip/api/v1/infra/segments