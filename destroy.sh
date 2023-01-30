#!/bin/bash
#
# Script to destroy the infrastructure
#
if [ -f "variables.json" ]; then
  jsonFile="variables.json"
else
  exit 1
fi
#
#
#
echo "--------------------------------------------------------------------------------------------------------------------"
#
# destroying ip route to reach overlay segments
#
#for route in $(jq -c -r .external_gw.routes[] $jsonFile)
#do
#  sudo ip route del $(echo $route | jq -c -r '.to') via $(jq -c -r .vcenter.vds.portgroup.management.external_gw_ip $jsonFile)
#done
#echo "--------------------------------------------------------------------------------------------------------------------"
#
# Destroy DNS/NTP server on the underlay infrastructure
#
#echo "Destroy DNS/NTP server on the underlay infrastructure"
#cd dns_ntp
#terraform destroy -auto-approve -var-file=../dns_ntp_json.json
#cd ..
#echo "--------------------------------------------------------------------------------------------------------------------"
#
# Destroy External GW server on the underlay infrastructure
#
echo "Destroy External GW server on the underlay infrastructure"
cd external_gw
terraform destroy -auto-approve -var-file=../external_gw.json
cd ..
echo "--------------------------------------------------------------------------------------------------------------------"
#
# Destroy the nested ESXi/vCenter infrastructure
#
echo "Destroy the nested ESXi/vCenter infrastructure"
cd nested_vsphere
terraform refresh -var-file=../$jsonFile ; terraform destroy -auto-approve -var-file=../$jsonFile
cd ..
echo "--------------------------------------------------------------------------------------------------------------------"
#
# Destroy of a folder on the underlay infrastructure
#
echo "--------------------------------------------------------------------------------------------------------------------"
echo "Destroy of a folder on the underlay infrastructure"
cd vsphere_underlay_folder
terraform init
terraform destroy -auto-approve -var-file=../$jsonFile
cd ..
echo "--------------------------------------------------------------------------------------------------------------------"
#
# Delete terraform.tfstate files
#
echo "Delete terraform cache files"
cd nsx/networks
rm -fr terraform.tfstate .terraform.lock.hcl .terraform
cd ../..
cd nsx/manager
rm -fr terraform.tfstate .terraform.lock.hcl .terraform
cd ../..
cd nsx/config
rm -fr terraform.tfstate .terraform.lock.hcl .terraform
cd ../..
cd avi/controllers
rm -fr terraform.tfstate .terraform.lock.hcl .terraform
cd ../..
cd avi/app
rm -fr terraform.tfstate .terraform.lock.hcl .terraform
cd ../..
cd avi/config
rm -fr terraform.tfstate .terraform.lock.hcl .terraform
cd ../..