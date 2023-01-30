#!/bin/bash
#
if [ -f "../variables.json" ]; then
  jsonFile="../variables.json"
else
  exit 1
fi
#
api_host="$(jq -r .vcenter.name $jsonFile).$(jq -r .external_gw.bind.domain $jsonFile)"
vcenter_username=administrator
vcenter_domain=$(jq -r .vcenter.sso.domain_name $jsonFile)
vcenter_password=$TF_VAR_vcenter_password
#
load_govc_env () {
  export GOVC_USERNAME="$vcenter_username@$vcenter_domain"
  export GOVC_PASSWORD=$vcenter_password
  export GOVC_DATACENTER=$(jq -r .vcenter.datacenter $jsonFile)
  export GOVC_INSECURE=true
  export GOVC_CLUSTER=$(jq -r .vcenter.cluster $jsonFile)
  export GOVC_URL=$api_host
}
#
load_govc_esxi () {
  export GOVC_USERNAME="root"
  export GOVC_PASSWORD=$TF_VAR_esxi_root_password
  export GOVC_INSECURE=true
  unset GOVC_DATACENTER
  unset GOVC_CLUSTER
  unset GOVC_URL
}
#
# Cleaning unused Standard vswitch config and VM port group
#
echo "++++++++++++++++++++++++++++++++"
echo "Cleaning unused Standard vswitch config"
IFS=$'\n'
load_govc_esxi
echo ""
echo "++++++++++++++++++++++++++++++++"
for ip in $(cat $jsonFile | jq -c -r .vcenter.vds.portgroup.management.esxi_ips[])
do
  export GOVC_URL=$ip
  echo "Deleting port group called VM Network for Host $ip"
  govc host.esxcli network vswitch standard portgroup remove -p "VM Network" -v "vSwitch0"
  echo "Deleting port group called Management Network for Host $ip"
  govc host.esxcli network vswitch standard portgroup remove -p "Management Network" -v "vSwitch0"
  echo "Deleting vswitch called vSwitch0 for Host $ip"
  govc host.esxcli network vswitch standard remove -v vSwitch0
  echo "Deleting vswitch called vSwitch1 for Host $ip"
  govc host.esxcli network vswitch standard remove -v vSwitch1
  echo "Deleting vswitch called vSwitch2 for Host $ip"
  govc host.esxcli network vswitch standard remove -v vSwitch2
done
#
# VSAN Configuration
#
load_govc_env
echo "Enabling VSAN configuration"
govc cluster.change -drs-enabled -ha-enabled -vsan-enabled -vsan-autoclaim "$(jq -r .vcenter.cluster $jsonFile)"
IFS=$'\n'
count=0
for ip in $(jq -r .vcenter.vds.portgroup.management.esxi_ips[] $jsonFile)
do
  load_govc_esxi
  if [[ $count -ne 0 ]] ; then
    export GOVC_URL=$ip
    echo "make sure vmk2 is tagged with service VSAN"
    govc host.esxcli network ip interface tag add -i vmk2 -t VSAN || true
    echo "Adding host $ip in VSAN configuration"
    govc host.esxcli vsan storage tag add -t capacityFlash -d "$(jq -r .vcenter.capacity_disk $jsonFile)"
    govc host.esxcli vsan storage add --disks "$(jq -r .vcenter.capacity_disk $jsonFile)" -s "$(jq -r .vcenter.cache_disk $jsonFile)"
  fi
  count=$((count+1))
done