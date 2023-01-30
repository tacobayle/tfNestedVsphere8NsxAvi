#!/bin/bash
#
if [ -f "../variables.json" ]; then
  jsonFile="../variables.json"
else
  exit 1
fi
#
export GOVC_USERNAME=root
export GOVC_PASSWORD=$(echo $TF_VAR_esxi_root_password)
export GOVC_INSECURE=true
unset GOVC_DATACENTER
unset GOVC_CLUSTER
unset GOVC_URL
#
IFS=$'\n'
echo ""
echo "++++++++++++++++++++++++++++++++"
echo "Configure ESXi disks as SSD"
for ip in $(cat $jsonFile | jq -c -r .vcenter.vds.portgroup.management.esxi_ips[])
do
  export GOVC_URL=$ip
  echo "+++++++++++++++++++"
  echo "Mark all disks as SSD for ESXi host $ip"
  EsxiMarkDiskAsSsd=$(govc host.storage.info -rescan | grep /vmfs/devices/disks | awk '{print $1}' | sort)
  for u in ${EsxiMarkDiskAsSsd[@]} ; do govc host.storage.mark -ssd $u ; done
done
