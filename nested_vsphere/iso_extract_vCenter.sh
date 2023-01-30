#!/bin/bash
#
if [ -f "../variables.json" ]; then
  jsonFile="../variables.json"
else
  exit 1
fi
#
iso_source_location=$(jq -r .vcenter.iso_source_location $jsonFile)
iso_mount_location="/tmp/vcenter_cdrom_mount"
iso_tmp_location="/tmp/vcenter_cdrom"
#
echo ""
echo "++++++++++++++++++++++++++++++++"
mkdir -p $iso_mount_location
if grep -qs $iso_mount_location /proc/mounts; then
    echo "vCenter ISO file already mounted"
else
    echo "Mounting vCenter ISO file"
    sudo mount -o loop $iso_source_location $iso_mount_location
fi
#
echo ""
echo "++++++++++++++++++++++++++++++++"
echo "Copying JSON template file to template directory"
cp -r $iso_mount_location/$(jq -r .vcenter.json_config_file $jsonFile) templates/
#
echo ""
echo "++++++++++++++++++++++++++++++++"
echo "Copying source vCenter ISO to temporary folder $iso_tmp_location"
sudo rm -fr $iso_tmp_location
mkdir -p $iso_tmp_location
cp -r $iso_mount_location/* $iso_tmp_location
#
echo ""
echo "++++++++++++++++++++++++++++++++"
if grep -qs $iso_mount_location /proc/mounts; then
    echo "unmounting vCenter ISO file"
    sudo umount $iso_mount_location
fi
rm -fr $iso_mount_location
#
echo ""
echo "++++++++++++++++++++++++++++++++"
echo "Building template file"
template_file_location="templates/$(basename $(jq -r .vcenter.json_config_file $jsonFile))"
contents="$(jq '.new_vcsa.esxi.hostname = "'$(jq -r .esxi.basename $jsonFile)'1.'$(jq -r .external_gw.bind.domain $jsonFile)'" |
         .new_vcsa.esxi.username = "root" |
         .new_vcsa.esxi.password = "'$TF_VAR_esxi_root_password'" |
         .new_vcsa.esxi.VCSA_cluster.datacenter = "'$(jq -r .vcenter.datacenter $jsonFile)'" |
         .new_vcsa.esxi.VCSA_cluster.cluster = "'$(jq -r .vcenter.cluster $jsonFile)'" |
         .new_vcsa.esxi.VCSA_cluster.disks_for_vsan.cache_disk[0] = "'$(jq -r .vcenter.cache_disk $jsonFile)'" |
         .new_vcsa.esxi.VCSA_cluster.disks_for_vsan.capacity_disk[0] = "'$(jq -r .vcenter.capacity_disk $jsonFile)'" |
         .new_vcsa.esxi.VCSA_cluster.enable_vsan_esa = '$(jq -r .vcenter.enable_vsan_esa $jsonFile)' |
         .new_vcsa.appliance.thin_disk_mode = '$(jq -r .vcenter.thin_disk_mode $jsonFile)' |
         .new_vcsa.appliance.deployment_option = "'$(jq -r .vcenter.deployment_option $jsonFile)'" |
         .new_vcsa.appliance.name = "'$(jq -r .vcenter.name $jsonFile)'" |
         .new_vcsa.network.ip = "'$(jq -r .vcenter.vds.portgroup.management.vcenter_ip $jsonFile)'" |
         .new_vcsa.network.dns_servers[0] = "'$(jq -r .vcenter.vds.portgroup.management.external_gw_ip $jsonFile)'" |
         .new_vcsa.network.prefix = "'$(jq -r .vcenter.vds.portgroup.management.prefix $jsonFile)'" |
         .new_vcsa.network.gateway = "'$(jq -r .vcenter.vds.portgroup.management.gateway $jsonFile)'" |
         .new_vcsa.network.system_name = "'$(jq -r .vcenter.name $jsonFile)'.'$(jq -r .external_gw.bind.domain $jsonFile)'" |
         .new_vcsa.os.password = "'$TF_VAR_vcenter_password'" |
         .new_vcsa.os.ntp_servers = "'$(jq -r .vcenter.vds.portgroup.management.external_gw_ip $jsonFile)'" |
         .new_vcsa.os.ssh_enable = '$(jq -r .vcenter.ssh_enable $jsonFile)' |
         .new_vcsa.sso.password = "'$TF_VAR_vcenter_password'" |
         .new_vcsa.sso.domain_name = "'$(jq -r .vcenter.sso.domain_name $jsonFile)'" |
         .ceip.settings.ceip_enabled = '$(jq -r .vcenter.ceip_enabled $jsonFile)' ' $template_file_location)"
echo "${contents}" | tee vcenter_config.json
#
echo ""
echo "++++++++++++++++++++++++++++++++"
echo "updating local /etc/hosts with vCenter and esxi0"
contents=$(cat /etc/hosts | grep -v $(jq -r .vcenter.vds.portgroup.management.vcenter_ip $jsonFile))
echo "${contents}" | sudo tee /etc/hosts
contents="$(jq -r .vcenter.vds.portgroup.management.vcenter_ip $jsonFile) $(jq -r .vcenter.name $jsonFile).$(jq -r .external_gw.bind.domain $jsonFile)"
echo "${contents}" | sudo tee -a /etc/hosts
IFS=$'\n'
count=1
for ip in $(cat $jsonFile | jq -c -r .vcenter.vds.portgroup.management.esxi_ips[])
do
  contents=$(cat /etc/hosts | grep -v $ip)
  echo "${contents}" | sudo tee /etc/hosts
  contents="$ip $(jq -r .esxi.basename $jsonFile)$count.$(jq -r .external_gw.bind.domain $jsonFile)"
  echo "${contents}" | sudo tee -a /etc/hosts
  count=$((count+1))
done
#
echo ""
echo "++++++++++++++++++++++++++++++++"
echo "starting vCenter Installation"
$iso_tmp_location/vcsa-cli-installer/lin64/vcsa-deploy install --accept-eula --acknowledge-ceip --no-esx-ssl-verify vcenter_config.json
