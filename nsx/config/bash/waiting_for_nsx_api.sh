#!/bin/bash
#
if [ -f "../../variables.json" ]; then
  jsonFile="../../variables.json"
else
  echo "ERROR: no json file found"
  exit 1
fi
nsx_ip=$(jq -r .vcenter.vds.portgroup.management.nsx_ip $jsonFile)
retry=10
pause=60
attempt=0
while [[ "$(curl -u admin:$TF_VAR_nsx_password -k -s -o /dev/null -w ''%{http_code}'' https://$nsx_ip/api/v1/cluster/status)" != "200" ]]; do
  echo "waiting for NSX Manager API to be ready"
  sleep $pause
  ((attempt++))
  if [ $attempt -eq $retry ]; then
    echo "FAILED to get NSX Manager API to be ready after $retry"
    break
  fi
done
retry=10
pause=60
attempt=0
while [[ "$(curl -u admin:$TF_VAR_nsx_password -k -s  https://$nsx_ip/api/v1/cluster/status | jq -r .detailed_cluster_status.overall_status)" != "STABLE" ]]; do
  echo "waiting for NSX Manager API to be STABLE"
  sleep $pause
  ((attempt++))
  if [ $attempt -eq $retry ]; then
    echo "FAILED to get NSX Manager API to be STABLE after $retry"
    break
  fi
done