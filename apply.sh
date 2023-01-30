#!/bin/bash
type terraform >/dev/null 2>&1 || { echo >&2 "terraform is not installed - please visit: https://learn.hashicorp.com/tutorials/terraform/install-cli to install it - Aborting." ; exit 255; }
type jq >/dev/null 2>&1 || { echo >&2 "jq is not installed - please install it - Aborting." ; exit 255; }
type govc >/dev/null 2>&1 || { echo >&2 "govc is not installed - please install it - Aborting." ; exit 255; }
type genisoimage >/dev/null 2>&1 || { echo >&2 "genisoimage is not installed - please install it - Aborting." ; exit 255; }
type ansible-playbook >/dev/null 2>&1 || { echo >&2 "ansible-playbook is not installed - please install it - Aborting." ; exit 255; }
type openssl >/dev/null 2>&1 || { echo >&2 "openssl is not installed - please install it - Aborting." ; exit 255; }
if ! ansible-galaxy collection list | grep community.vmware > /dev/null ; then echo "ansible collection community.vmware is not installed - please install it - Aborting." ; exit 255 ; fi
if ! ansible-galaxy collection list | grep ansible_for_nsxt > /dev/null ; then echo "ansible collection vmware.ansible_for_nsxt is not installed - please install it - Aborting." ; exit 255 ; fi
if ! pip3 list | grep  pyvmomi > /dev/null ; then echo "python pyvmomi is not installed - please install it - Aborting." ; exit 255 ; fi
#
# Script to run before TF
#
if [ -f "variables.json" ]; then
  jsonFile="variables.json"
else
  echo "variables.json file not found!!"
  exit 255
fi
IFS=$'\n'
#
#
#
test_if_file_exists () {
  # $1 file path to check
  # $2 message to display
  # $3 message to display if file is present
  # $4 error to display
  echo "$2"
  if [ -f $1 ]; then
    echo "$3$1: OK."
  else
    echo "$4$1: file not found!!"
    exit 255
  fi
}
#
test_if_ref_from_list_exists_in_another_list () {
  # $1 list + ref to check
  # $2 list + ref to check against
  # $3 json file
  # $4 message to display
  # $5 message to display if match
  # $6 error to display
  echo $4
  for ref in $(jq -c -r $1 $3)
  do
    check_status=0
    for item_name in $(jq -c -r $2 $3)
    do
      if [[ $ref = $item_name ]] ; then check_status=1 ; echo "$5found: $ref, OK"; fi
    done
  done
  if [[ $check_status -eq 0 ]] ; then echo "$6$ref" ; exit 255 ; fi
}
#
tf_init_apply () {
  # $1 messsage to display
  # $2 is the folder to init/apply tf
  # $3 is the log path file for tf stdout
  # $4 is the log path file for tf error
  # $5 is var-file to feed TF with variables
  echo "-----------------------------------------------------"
  echo $1
  echo "Starting timestamp: $(date)"
  cd $2
  terraform init > $3 2>$4
  if [ -s "$4" ] ; then
    echo "TF Init ERRORS:"
    cat $4
    exit 1
  else
    rm $3 $4
  fi
  terraform apply -auto-approve -var-file=$5 > $3 2>$4
  if [ -s "$4" ] ; then
    echo "TF Apply ERRORS:"
    cat $4
#    echo "Waiting for 30 seconds - retrying TF Apply..."
#    sleep 10
#    rm -f $3 $4
#    terraform apply -auto-approve -var-file=$5 > $3 2>$4
#    if [ -s "$4" ] ; then
#      echo "TF Apply ERRORS:"
#      cat $4
#      exit 1
#    fi
    exit 1
  fi
  echo "Ending timestamp: $(date)"
  cd - > /dev/null
}
#
vcenter_api () {
  # $1 is the amount of retry
  # $2 is the time to pause between each retry
  # $3 type of HTTP method (GET, POST, PUT, PATCH)
  # $4 vCenter token
  # $5 http data
  # $6 vCenter FQDN
  # $7 API endpoint
  retry=$1
  pause=$2
  attempt=0
  # echo "HTTP $3 API call to https://$6/$7"
  while true ; do
    response=$(curl -k -s -X $3 --write-out "\n%{http_code}" -H "vmware-api-session-id: $4" -H "Content-Type: application/json" -d "$5" https://$6/$7)
    response_body=$(sed '$ d' <<< "$response")
    response_code=$(tail -n1 <<< "$response")
    if [[ $response_code == 2[0-9][0-9] ]] ; then
      echo "  HTTP $3 API call to https://$6/$7 was successful"
      break
    else
      echo "  Retrying HTTP $3 API call to https://$6/$7, http response code: $response_code, attempt: $attempt"
    fi
    if [ $attempt -eq $retry ]; then
      echo "  FAILED HTTP $3 API call to https://$6/$7, response code was: $response_code"
      echo "$response_body"
      exit 255
    fi
    sleep $pause
    ((attempt++))
  done
}
#
#
# Sanity checks
#
echo ""
echo "==> Checking vSphere folders for name conflict..."
api_host="$(jq -r .vcenter_underlay.server $jsonFile)"
vcenter_username=$TF_VAR_vsphere_username
vcenter_domain=''
vcenter_password=$TF_VAR_vsphere_password
token=$(/bin/bash bash/create_vcenter_api_session.sh "$vcenter_username" "$vcenter_domain" "$vcenter_password" "$api_host")
vcenter_api 6 10 "GET" $token "" $api_host "rest/vcenter/folder"
response_folder=$(echo $response_body)
IFS=$'\n'
for folder_entry in $(echo $response_folder | jq -c -r .value[])
do
  if [[ $(echo $folder_entry | jq -c -r .type) == "VIRTUAL_MACHINE" ]] ; then
    if [[ $(echo $folder_entry | jq -c -r .name) == $(jq -c -r .vcenter_underlay.folder $jsonFile) ]] ; then
      echo "  +++ ERROR +++ folder $(jq -c -r .vcenter_underlay.folder $jsonFile) already exists"
      #exit 255
    fi
  fi
done
echo "  +++ No conflict found, OK"
#
echo ""
echo "==> Checking vSphere VMs for name conflict..."
vcenter_api 6 10 "GET" $token "" $api_host "rest/vcenter/vm"
response_vm=$(echo $response_body)
for vm_entry in $(echo $response_vm | jq -c -r .value[])
do
  if [[ $(echo $vm_entry | jq -c -r .name) == $(jq -c -r .external_gw.name $jsonFile) ]] ; then
    echo "  +++ ERROR +++ VM called $(jq -c -r .external_gw.name $jsonFile) already exists"
    exit 255
  fi
done
echo "  +++ No conflict found, OK"
#
echo ""
echo "==> Checking Ubuntu Settings for external gw..."
test_if_file_exists $(jq -c -r .vcenter_underlay.cl.ubuntu_focal_file_path $jsonFile) "   +++ Checking Ubuntu OVA..." "   ++++++ " "   ++++++ERROR++++++ "
#
#
#
echo ""
echo "==> Checking SSH Keys for external_gw server..."
test_if_file_exists $(jq -c -r .external_gw.public_key_path $jsonFile) "   +++ Checking SSH public key path..." "   ++++++ " "   ++++++ERROR++++++ "
test_if_file_exists $(jq -c -r .external_gw.private_key_path $jsonFile) "   +++ Checking SSH private key path..." "   ++++++ " "   ++++++ERROR++++++ "
#
#
echo ""
echo "==> Creating External gateway json file..."
echo "   +++ Creating External gateway routes to subnet segments..."
rm -f external_gw.json
new_routes="[]"
external_gw_json=$(jq -c -r . $jsonFile | jq .)
# adding routes to external gw from nsx.config.segments_overlay
if [[ $(jq -c -r '.nsx.config.segments_overlay | length' $jsonFile) -gt 0 ]] ; then
  for segment in $(jq -c -r .nsx.config.segments_overlay[] $jsonFile)
  do
    for tier1 in $(jq -c -r .nsx.config.tier1s[] $jsonFile)
    do
      if [[ $(echo $segment | jq -c -r .tier1) == $(echo $tier1 | jq -c -r .display_name) ]] ; then
        count=0
        for tier0 in $(jq -c -r .nsx.config.tier0s[] $jsonFile)
        do
          if [[ $(echo $tier1 | jq -c -r .tier0) == $(echo $tier0 | jq -c -r .display_name) ]] ; then
            new_routes=$(echo $new_routes | jq '. += [{"to": "'$(echo $segment | jq -c -r .cidr)'", "via": "'$(jq -c -r .vcenter.vds.portgroup.nsx_external.tier0_vips["$count"] $jsonFile)'"}]')
            echo "   ++++++ Route to $(echo $segment | jq -c -r .cidr) via $(jq -c -r .vcenter.vds.portgroup.nsx_external.tier0_vips["$count"] $jsonFile) added: OK"
          fi
          ((count++))
        done
      fi
    done
  done
fi
echo "   +++ Creating External gateway routes to Avi VIP subnets..."
if [[ $(jq -c -r '.avi.config.cloud.networks_data | length' $jsonFile) -gt 0 ]] ; then
  for network in $(jq -c -r .avi.config.cloud.networks_data[] $jsonFile)
  do
    for segment in $(jq -c -r .nsx.config.segments_overlay[] $jsonFile)
    do
      if [[ $(echo $network | jq -c -r .name) == $(echo $segment | jq -c -r .display_name) ]] ; then
        for tier1 in $(jq -c -r .nsx.config.tier1s[] $jsonFile)
        do
          if [[ $(echo $segment | jq -c -r .tier1) == $(echo $tier1 | jq -c -r .display_name) ]] ; then
            count=0
            for tier0 in $(jq -c -r .nsx.config.tier0s[] $jsonFile)
            do
              if [[ $(echo $tier1 | jq -c -r .tier0) == $(echo $tier0 | jq -c -r .display_name) ]] ; then
                new_routes=$(echo $new_routes | jq '. += [{"to": "'$(echo $network | jq -c -r .avi_ipam_vip.cidr)'", "via": "'$(jq -c -r .vcenter.vds.portgroup.nsx_external.tier0_vips["$count"] $jsonFile)'"}]')
                echo "   ++++++ Route to $(echo $network | jq -c -r .avi_ipam_vip.cidr) via $(jq -c -r .vcenter.vds.portgroup.nsx_external.tier0_vips["$count"] $jsonFile) added: OK"
              fi
              ((count++))
            done
          fi
        done
      fi
    done
  done
fi
external_gw_json=$(echo $external_gw_json | jq '.external_gw += {"routes": '$(echo $new_routes)'}')
echo "   +++ Adding reverse DNS zone..."
ip_external_gw=$(jq -c -r .vcenter.vds.portgroup.management.external_gw_ip $jsonFile)
octets=""
addr=""
IFS="." read -r -a octets <<< "$ip_external_gw"
count=0
for octet in "${octets[@]}"; do if [ $count -eq 3 ]; then break ; fi ; addr=$octet"."$addr ;((count++)) ; done
reverse=${addr%.}
echo "   ++++++ Found: $reverse"
external_gw_json=$(echo $external_gw_json | jq '.external_gw.bind += {"reverse": "'$(echo $reverse)'"}')
echo $external_gw_json | jq . | tee external_gw.json > /dev/null
#
#
echo ""
echo "==> Checking ESXi Settings..."
test_if_file_exists $(jq -c -r .esxi.iso_source_location $jsonFile) "   +++ Checking ESXi ISO..." "   ++++++ " "   ++++++ERROR++++++ "
#
#
echo ""
echo "==> Checking vCenter Settings..."
test_if_file_exists $(jq -c -r .vcenter.iso_source_location $jsonFile) "   +++ Checking vCenter ISO..." "   ++++++ " "   ++++++ERROR++++++ "
#
#
echo ""
echo "==> Checking NSX Settings..."
test_if_file_exists $(jq -c -r .nsx.content_library.ova_location $jsonFile) "   +++ Checking NSX OVA..." "   ++++++ " "   ++++++ERROR++++++ "
#
echo "   +++ Checking NSX if the amount of mgmt edge IP(s) are enough for all the edge node(s)..."
ip_count_mgmt_edge=$(jq -c -r '.vcenter.vds.portgroup.management.nsx_edge | length' $jsonFile)
edge_node_count=0
for edge_cluster in $(jq -c -r .nsx.config.edge_clusters[] $jsonFile)
do
  edge_node_count=$(($edge_node_count + $(echo $edge_cluster | jq -c -r '.members_name | length' )))
done
if [[ ip_count_mgmt_edge -ge $edge_node_count ]] ; then
  echo "   ++++++ Found mgmt edge IP(s): $ip_count_mgmt_edge required: $edge_node_count, OK"
else
  echo "   ++++++ERROR++++++ Found mgmt edge IP(s): $ip_count_mgmt_edge required: $edge_node_count"
  exit 255
fi
#
echo "   +++ Checking NSX if the amount of external IP(s) are enough for all the interfaces of the tier0(s)..."
ip_count_external_tier0=$(jq -c -r '.vcenter.vds.portgroup.nsx_external.tier0_ips | length' $jsonFile)
tier0_ifaces=0
for tier0 in $(jq -c -r .nsx.config.tier0s[] $jsonFile)
do
  tier0_ifaces=$((tier0_ifaces+$(echo $tier0 | jq -c -r '.interfaces | length')))
done
if [[ $tier0_ifaces -gt $ip_count_external_tier0 ]] ; then
  echo "   ++++++ERROR++++++ Amount of IPs (.vcenter.vds.portgroup.nsx_external.tier0_ips) cannot cover the amount of tier0 interfaces defined in .nsx.config.tier0s[].interfaces"
  exit 255
fi
echo "   ++++++ Amount of tier0(s) interfaces: $tier0_ifaces, Amount of of IP(s): $ip_count_external_tier0, OK"
#
#
echo "   +++ Checking NSX if if the amount of interfaces in vip config is equal to two for each tier0..."
for tier0 in $(jq -c -r .nsx.config.tier0s[] $jsonFile)
do
  for vip in $(echo $tier0 | jq -c -r .ha_vips[])
  do
    if [[ $(echo $vip | jq -c -r '.interfaces | length') -ne 2 ]] ; then
      echo "   ++++++ERROR++++++ Amount of interfaces (.nsx.config.tier0s[].ha_vips[].interfaces) needs to be equal to 2; tier0 called $(echo $tier0 | jq -c -r .display_name) has $(echo $vip | jq -c -r '.interfaces | length') interfaces for its ha_vips"
      exit 255
    fi
    echo "   ++++++ Amount of interfaces for $(echo $tier0 | jq -c -r .display_name): $(echo $vip | jq -c -r '.interfaces | length'), OK"
  done
done
#
#
echo "   +++ Checking NSX if the amount of external vip is enough for all the vips of the tier0s..."
tier0_vips=0
for tier0 in $(jq -c -r .nsx.config.tier0s[] $jsonFile)
do
  for vip in $(echo $tier0 | jq -c -r .ha_vips[])
  do
    tier0_vips=$((tier0_vips+$(echo $tier0 | jq -c -r '.ha_vips | length')))
  done
  if [[ $tier0_vips -gt $(jq -c -r '.vcenter.vds.portgroup.nsx_external.tier0_vips | length' $jsonFile) ]] ; then
    echo "   ++++++ERROR++++++ Amount of VIPs (.vcenter.vds.portgroup.nsx_external.tier0_vips) cannot cover the amount of ha_vips defined in .nsx.config.tier0s[].ha_vips"
    exit 255
  fi
done
echo "   ++++++ Amount of external vip is $(jq -c -r '.vcenter.vds.portgroup.nsx_external.tier0_vips | length' $jsonFile), amount of vip needed: $tier0_vips, OK"
#
test_if_ref_from_list_exists_in_another_list ".nsx.config.tier1s[].tier0" \
                                             ".nsx.config.tier0s[].display_name" \
                                             "$jsonFile" \
                                             "   +++ Checking Tiers 0 in tiers 1" \
                                             "   ++++++ Tier0 " \
                                             "   ++++++ERROR++++++ Tier0 not found: "
#
test_if_ref_from_list_exists_in_another_list ".nsx.config.segments_overlay[].tier1" \
                                             ".nsx.config.tier1s[].display_name" \
                                             "$jsonFile" \
                                             "   +++ Checking Tiers 1 in segments_overlay" \
                                             "   ++++++ Tier1 " \
                                             "   ++++++ERROR++++++ Tier1 not found: "
#
# check Avi Parameters
rm -f avi.json
IFS=$'\n'
avi_json=""
avi_networks="[]"
echo ""
echo "==> Checking Avi Settings..."
test_if_file_exists $(jq -c -r .avi.content_library.ova_location $jsonFile) "   +++ Checking Avi OVA" "   ++++++ " "   ++++++ERROR++++++ "
# check Avi Controller Network
# copying segment info (ip, cidr, and gw keys) to avi.controller
echo "   +++ Checking Avi Controller network settings"
avi_controller_network=0
for segment in $(jq -c -r .nsx.config.segments_overlay[] $jsonFile)
do
  if [[ $(echo $segment | jq -r .display_name) == $(jq -c -r .avi.controller.network_ref $jsonFile) ]] ; then
    avi_controller_network=1
    echo "   ++++++ Avi Controller segment found: $(echo $segment | jq -r .display_name), OK"
    echo "   ++++++ Avi Controller CIDR is: $(echo $segment | jq -r .cidr), OK"
    echo "   ++++++ Avi Controller IP is: $(echo $segment | jq -r .avi_controller), OK"
    avi_json=$(jq -c -r . $jsonFile | jq '.avi.controller += {"ip": '$(echo $segment | jq .avi_controller)'}' | jq '.avi.controller += {"cidr": '$(echo $segment | jq .cidr)'}' | jq '.avi.controller += {"gw": '$(echo $segment | jq .gw)'}')
  fi
done
if [[ $avi_controller_network -eq 0 ]] ; then
  echo "   ++++++ERROR++++++ $(jq -c -r .avi.controller.network_ref $jsonFile) segment not found!!"
  exit 255
fi
#
echo "   +++ Checking Avi Cloud networks settings"
for segment in $(jq -c -r .nsx.config.segments_overlay[] $jsonFile)
do
  if [[ $(echo $segment | jq -r .display_name) == $(jq -c -r .avi.config.cloud.network_management.name $jsonFile) ]] ; then
    avi_cloud_network=1
    echo "   ++++++ Avi cloud network found in NSX overlay segments: $(echo $segment | jq -r .display_name), OK"
    tier1=$(echo $segment | jq -r .tier1)
  fi
done
if [[ $avi_cloud_network -eq 0 ]] ; then
  echo "   ++++++ERROR++++++ $(echo $network | jq -c -r .name) segment not found!!"
  exit 255
fi
new_network=$(echo $(jq -c -r .avi.config.cloud.network_management $jsonFile) | jq '. += {"tier1": "'$(echo $tier1)'"}')
avi_json=$(echo $avi_json | jq '. | del (.avi.config.cloud.network_management)')
avi_json=$(echo $avi_json | jq '.avi.config.cloud += {"network_management": '$(echo $new_network)'}')
for network in $(jq -c -r .avi.config.cloud.networks_data[] $jsonFile)
do
  network_name=$(echo $network | jq -c -r .name)
  avi_cloud_network=0
  for segment in $(jq -c -r .nsx.config.segments_overlay[] $jsonFile)
  do
    if [[ $(echo $segment | jq -r .display_name) == $(echo $network | jq -c -r .name) ]] ; then
      avi_cloud_network=1
      echo "   ++++++ Avi cloud network found in NSX overlay segments: $(echo $segment | jq -r .display_name), OK"
      tier1=$(echo $segment | jq -r .tier1)
    fi
  done
  if [[ $avi_cloud_network -eq 0 ]] ; then
    echo "   ++++++ERROR++++++ $(echo $network | jq -c -r .name) segment not found!!"
    exit 255
  fi
  new_network=$(echo $network | jq '. += {"tier1": "'$(echo $tier1)'"}')
  avi_networks=$(echo $avi_networks | jq '. += ['$(echo $new_network)']')
done
avi_json=$(echo $avi_json | jq '. | del (.avi.config.cloud.networks_data)')
avi_json=$(echo $avi_json | jq '.avi.config.cloud += {"networks_data": '$(echo $avi_networks)'}')
#
echo $avi_json | jq . | tee avi.json > /dev/null
#
# checking if seg ref in DNS VS exist in seg list
if [ $(jq -c -r '.avi.config.virtual_services.dns | length' $jsonFile) -gt 0 ] ; then
  test_if_ref_from_list_exists_in_another_list ".avi.config.virtual_services.dns[].se_group_ref" \
                                               ".avi.config.service_engine_groups[].name" \
                                               "$jsonFile" \
                                               "   +++ Checking Service Engine Group in DNS VS" \
                                               "   ++++++ Service Engine Group " \
                                               "   ++++++ERROR++++++ segment not found: "
fi
# checking if seg ref in HTTP VS exist in seg list
if [ $(jq -c -r '.avi.config.virtual_services.http | length' $jsonFile) -gt 0 ] ; then
  test_if_ref_from_list_exists_in_another_list ".avi.config.virtual_services.http[].se_group_ref" \
                                               ".avi.config.service_engine_groups[].name" \
                                               "$jsonFile" \
                                               "   +++ Checking Service Engine Group in HTTP VS" \
                                               "   ++++++ Service Engine Group " \
                                               "   ++++++ERROR++++++ segment not found: "
fi
#
# check of the app parameters
#
rm -f app.json
IFS=$'\n'
app_json=""
app_network="[]"
echo ""
echo "==> Checking Avi App Settings..."
test_if_file_exists $(jq -c -r .avi.app.ova_location $jsonFile) "   +++ Checking Avi App OVA" "   ++++++ " "   ++++++ERROR++++++ "
# check Avi App Network
# copying segment info (ip, cidr, and gw keys) to avi.app
echo "   +++ Checking Avi App network settings"
avi_app_network=0
for segment in $(jq -c -r .nsx.config.segments_overlay[] $jsonFile)
do
  if [[ $(echo $segment | jq -r .display_name) == $(jq -c -r .avi.app.network_ref $jsonFile) ]] ; then
    avi_app_network=1
    echo "   ++++++ Avi App segment found: $(echo $segment | jq -r .display_name), OK"
    echo "   ++++++ Avi App CIDR is: $(echo $segment | jq -r .cidr), OK"
    echo "   ++++++ Avi App IP is: $(echo $segment | jq -c -r .avi_app_server_ips), OK"
    app_json=$(jq -c -r . $jsonFile | jq '.avi.app += {"ips": '$(echo $segment | jq -c -r .avi_app_server_ips)'}' | jq '.avi.app += {"cidr": '$(echo $segment | jq .cidr)'}' | jq '.avi.app += {"gw": '$(echo $segment | jq .gw)'}')
  fi
done
if [[ $avi_app_network -eq 0 ]] ; then
  echo "   ++++++ERROR++++++ $(jq -c -r .avi.app.network_ref $jsonFile) segment not found!!"
  exit 255
fi
echo $app_json | jq . | tee app.json > /dev/null
#
# Build of a folder on the underlay infrastructure
#
tf_init_apply "Build of a folder on the underlay infrastructure - This should take less than a minute" vsphere_underlay_folder ../logs/tf_vsphere_underlay_folder.stdout ../logs/tf_vsphere_underlay_folder.errors ../$jsonFile
#
# Build of an external GW server on the underlay infrastructure
#
tf_init_apply "Build of an external GW server on the underlay infrastructure - This should take less than 10 minutes" external_gw ../logs/tf_external_gw.stdout ../logs/tf_external_gw.errors ../external_gw.json
#
# Build of the nested ESXi/vCenter infrastructure
#
tf_init_apply "Build of the nested ESXi/vCenter infrastructure - This should take less than 45 minutes" nested_vsphere ../logs/tf_nested_vsphere.stdout ../logs/tf_nested_vsphere.errors ../$jsonFile
 echo "waiting for 20 minutes to finish the vCenter config..."
 sleep 1200
#
# Build of the NSX Nested Networks
#
if [[ $(jq -c -r .nsx.networks.create $jsonFile) == true ]] ; then
  tf_init_apply "Build of NSX Nested Networks - This should take less than a minute" nsx/networks ../../logs/tf_nsx_networks.stdout ../../logs/tf_nsx_networks.errors ../../$jsonFile
fi
#
# Build of the nested NSXT Manager
#
if [[ $(jq -c -r .nsx.manager.create $jsonFile) == true ]] || [[ $(jq -c -r .nsx.content_library.create $jsonFile) == true ]] ; then
  tf_init_apply "Build of the nested NSXT Manager - This should take less than 20 minutes" nsx/manager ../../logs/tf_nsx.stdout ../../logs/tf_nsx.errors ../../$jsonFile
  if [[ $(jq -c -r .nsx.manager.create $jsonFile) == true ]] ; then
    echo "waiting for 5 minutes to finish the NSXT bootstrap..."
    sleep 300
  fi
fi
#
# Build of the config of NSX-T
#
if [[ $(jq -c -r .nsx.config.create $jsonFile) == true ]] ; then
  tf_init_apply "Build of the config of NSX-T - This should take less than 60 minutes" nsx/config ../../logs/tf_nsx_config.stdout ../../logs/tf_nsx_config.errors ../../$jsonFile
fi
#
# Build of the Nested Avi Controllers
#
if [[ $(jq -c -r .avi.controller.create $jsonFile) == true ]]  ; then
  tf_init_apply "Build of Nested Avi Controllers - This should take around 20 minutes" avi/controllers ../../logs/tf_avi_controller.stdout ../../logs/tf_avi_controller.errors ../../avi.json
fi
#
# Build of the Nested Avi App
#
if [[ $(jq -c -r .avi.app.create $jsonFile) == true ]] ; then
  tf_init_apply "Build of Nested Avi App - This should take less than 10 minutes" avi/app ../../logs/tf_avi_app.stdout ../../logs/tf_avi_app.errors ../../app.json
fi
#
# Build of the config of Avi
#
if [[ $(jq -c -r .avi.controller.create $jsonFile) == true ]] && [[ $(jq -c -r .avi.config.create $jsonFile) == true ]] ; then
  tf_init_apply "Build of the config of Avi - This should take less than 20 minutes" avi/config ../../logs/tf_avi_config.stdout ../../logs/tf_avi_config.errors ../../avi.json
fi
#
# Output message
#
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "Configure your local DNS by using $(jq -c -r .vcenter.vds.portgroup.management.external_gw_ip $jsonFile)"
echo "vCenter url: https://$(jq -c -r .vcenter.name $jsonFile).$(jq -c -r .external_gw.bind.domain $jsonFile)"
echo "NSX url: https://$(jq -c -r .nsx.manager.basename $jsonFile).$(jq -c -r .external_gw.bind.domain $jsonFile)"
echo "To access Avi UI:"
echo "  - configure $(jq -c -r .vcenter.vds.portgroup.management.external_gw_ip $jsonFile) as a socks proxy"
echo "  - Avi url: https://$(jq -c -r .nsx.config.segments_overlay[0].cidr $jsonFile | cut -d'/' -f1 | cut -d'.' -f1-3).$(jq -c -r .nsx.config.segments_overlay[0].avi_controller $jsonFile)"
