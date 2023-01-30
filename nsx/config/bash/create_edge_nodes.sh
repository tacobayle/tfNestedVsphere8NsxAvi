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
vcenter_password=$TF_VAR_vcenter_password
vcenter_fqdn="$(jq -r .vcenter.name $jsonFile).$(jq -r .external_gw.bind.domain $jsonFile)"
api_host="$(jq -r .vcenter.name $jsonFile).$(jq -r .external_gw.bind.domain $jsonFile)"
cookies_file="bash/create_edge_nodes_cookies.txt"
headers_file="bash/create_edge_nodes_headers.txt"
rm -f $cookies_file $headers_file
#
nsx_api () {
  # $1 is the amount of retry
  # $2 is the time to pause between each retry
  # $3 type of HTTP method (GET, POST, PUT, PATCH)
  # $4 cookie file
  # $5 http header
  # $6 http data
  # $7 NSX IP
  # $8 API endpoint
  retry=$1
  pause=$2
  attempt=0
  echo "HTTP $3 API call to https://$7/$8"
  while true ; do
    response=$(curl -k -s -X $3 --write-out "\n%{http_code}" -b $4 -H "`grep -i X-XSRF-TOKEN $5 | tr -d '\r\n'`" -H "Content-Type: application/json" -d "$6" https://$7/$8)
    response_body=$(sed '$ d' <<< "$response")
    response_code=$(tail -n1 <<< "$response")
    if [[ $response_code == 2[0-9][0-9] ]] ; then
      echo "  HTTP $3 API call to https://$7/$8 was successful"
      break
    else
      echo "  Retrying HTTP $3 API call to https://$7/$8, http response code: $response_code, attempt: $attempt"
    fi
    if [ $attempt -eq $retry ]; then
      echo "  FAILED HTTP $3 API call to https://$7/$8, response code was: $response_code"
      echo "$response_body"
      exit 255
    fi
    sleep $pause
    ((attempt++))
  done
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
  echo "HTTP $3 API call to https://$6/$7"
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
/bin/bash bash/create_nsx_api_session.sh admin $TF_VAR_nsx_password $nsx_ip $cookies_file $headers_file
nsx_api 6 10 "GET" $cookies_file $headers_file "" $nsx_ip "api/v1/fabric/compute-managers"
compute_managers=$(echo $response_body)
IFS=$'\n'
for item in $(echo $compute_managers | jq -c -r .results[])
do
  if [[ $(echo $item | jq -r .display_name) == $(jq -r .vcenter.name $jsonFile).$(jq -r .external_gw.bind.domain $jsonFile) ]] ; then
    vc_id=$(echo $item | jq -r .id)
  fi
done
token=$(/bin/bash ../../nested_vsphere/bash/create_vcenter_api_session.sh $vcenter_username $vcenter_domain $vcenter_password $api_host)
vcenter_api 6 10 "GET" $token "" $api_host "api/vcenter/datastore"
storage_id=$(echo $response_body | jq -r .[0].datastore)
vcenter_api 6 10 "GET" $token "" $api_host "api/vcenter/network"
vcenter_networks=$(echo $response_body)
data_network_ids=[]
for item in $(echo $vcenter_networks | jq -c -r .[])
do
  if [[ $(echo $item | jq -r .name) == $(jq -r .vcenter.vds.portgroup.management.name $jsonFile) ]] ; then
    management_network_id=$(echo $item | jq -r .network)
  fi
done
for item in $(echo $vcenter_networks | jq -c -r .[])
do
  if [[ $(echo $item | jq -r .name) == $(jq -r .vcenter.vds.portgroup.nsx_overlay_edge.name $jsonFile)-pg ]] ; then
    data_network_id=$(echo $item | jq -r .network)
    data_network_ids=$(echo $data_network_ids | jq '. += ["'$data_network_id'"]')
  fi
done
for item in $(echo $vcenter_networks | jq -c -r .[])
do
  if [[ $(echo $item | jq -r .name) == $(jq -r .vcenter.vds.portgroup.nsx_external.name $jsonFile)-pg ]] ; then
    data_network_id=$(echo $item | jq -r .network)
    data_network_ids=$(echo $data_network_ids | jq '. += ["'$data_network_id'"]')
  fi
done
vcenter_api 6 10 "GET" $token "" $api_host "api/vcenter/resource-pool"
vcenter_resource_pools=$(echo $response_body)
for item in $(echo $vcenter_resource_pools| jq -c -r .[])
do
  if [[ $(echo $item | jq -r .name) == "Resources" ]] ; then
    compute_id=$(echo $item | jq -r .resource_pool)
  fi
done
edge_ids="[]"
for edge_index in $(seq 1 $(jq -r '.vcenter.vds.portgroup.management.nsx_edge | length' $jsonFile ))
do
  edge_count=$((edge_index-1)) # starts at 0
  name=$(jq -r .nsx.config.edge_node.basename $jsonFile)$edge_index
  fqdn=$(jq -r .nsx.config.edge_node.basename $jsonFile)$edge_index.$(jq -r .external_gw.bind.domain $jsonFile)
  cpu=$(jq -r .nsx.config.edge_node.cpu $jsonFile)
  memory=$(jq -r .nsx.config.edge_node.memory $jsonFile)
  disk=$(jq -r .nsx.config.edge_node.disk $jsonFile)
  gateway=$(jq -r .vcenter.vds.portgroup.management.gateway $jsonFile)
  prefix_length=$(jq -r .vcenter.vds.portgroup.management.prefix $jsonFile)
  ip=$(jq -r .vcenter.vds.portgroup.management.nsx_edge[$edge_count] $jsonFile)
  host_switch_count=0
  new_json="{\"host_switch_spec\": {\"host_switches\": [], \"resource_type\": \"StandardHostSwitchSpec\"}}"
  for host_switch in $(jq -c -r .nsx.config.edge_node.host_switch_spec.host_switches[] $jsonFile)
  do
    new_json=$(echo $new_json | jq -r -c '.host_switch_spec.host_switches |= .+ ['$host_switch']')
    new_json=$(echo $new_json | jq '.host_switch_spec.host_switches['$host_switch_count'] += {"host_switch_profile_ids": []}')
    new_json=$(echo $new_json | jq '.host_switch_spec.host_switches['$host_switch_count'] += {"transport_zone_endpoints": []}')
    for host_switch_profile_name in $(echo $host_switch | jq -r .host_switch_profile_names[])
    do
      nsx_api 6 10 "GET" $cookies_file $headers_file "" $nsx_ip "api/v1/host-switch-profiles"
      host_switch_profiles=$(echo $response_body)
#      host_switch_profiles=$(curl -k -s -X GET -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" https://$nsx_ip/api/v1/host-switch-profiles)
      IFS=$'\n'
      for item in $(echo $host_switch_profiles | jq -c -r .results[])
      do
        if [[ $(echo $item | jq -r .display_name) == $host_switch_profile_name ]] ; then
          host_switch_profile_id=$(echo $item | jq -r .id)
        fi
      done
      new_json=$(echo $new_json | jq '.host_switch_spec.host_switches['$host_switch_count'].host_switch_profile_ids += [{"key": "UplinkHostSwitchProfile", "value": "'$host_switch_profile_id'"}]')
    done
    for tz_name in $(echo $host_switch | jq -r .transport_zone_names[])
    do
      nsx_api 6 10 "GET" $cookies_file $headers_file "" $nsx_ip "api/v1/transport-zones"
      transport_zones=$(echo $response_body)
#      transport_zones=$(curl -k -s -X GET -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" https://$nsx_ip/api/v1/transport-zones)
      IFS=$'\n'
      for item in $(echo $transport_zones | jq -c -r .results[])
      do
        if [[ $(echo $item | jq -r .display_name) == $tz_name ]] ; then
          transport_zone_id=$(echo $item | jq -r .id)
        fi
      done
      new_json=$(echo $new_json | jq '.host_switch_spec.host_switches['$host_switch_count'].transport_zone_endpoints += [{"transport_zone_id": "'$transport_zone_id'"}]')
    done
    if [[ $(echo $new_json | jq '.host_switch_spec.host_switches['$host_switch_count']' | grep ip_pool_name) ]] ; then
      nsx_api 6 10 "GET" $cookies_file $headers_file "" $nsx_ip "api/v1/infra/ip-pools"
      ip_pools=$(echo $response_body)
#      ip_pools=$(curl -k -s -X GET -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" https://$nsx_ip/policy/api/v1/infra/ip-pools)
      IFS=$'\n'
      for item in $(echo $ip_pools | jq -c -r .results[])
      do
        if [[ $(echo $item | jq -r .display_name) == $(echo $new_json | jq -r '.host_switch_spec.host_switches['$host_switch_count'].ip_pool_name') ]] ; then
          ip_pool_id=$(echo $item | jq -r .realization_id)
        fi
      done
      new_json=$(echo $new_json | jq '.host_switch_spec.host_switches['$host_switch_count'] += {"ip_assignment_spec": {"ip_pool_id": "'$ip_pool_id'", "resource_type": "StaticIpPoolSpec"}}')
      new_json=$(echo $new_json | jq 'del (.host_switch_spec.host_switches['$host_switch_count'].ip_pool_name)' )
    fi
    new_json=$(echo $new_json | jq 'del (.host_switch_spec.host_switches['$host_switch_count'].host_switch_profile_names)' )
    new_json=$(echo $new_json | jq 'del (.host_switch_spec.host_switches['$host_switch_count'].transport_zone_names)' )
    host_switch_count=$((host_switch_count+1))
  done
  new_json=$(echo $new_json | jq '. +=  {"maintenance_mode": "DISABLED"}')
  new_json=$(echo $new_json | jq '. +=  {"display_name":"'$name'"}')
  new_json=$(echo $new_json | jq '. +=  {"node_deployment_info": {"resource_type":"EdgeNode", "deployment_type": "VIRTUAL_MACHINE", "deployment_config": { "vm_deployment_config": {"vc_id": "'$vc_id'", "compute_id": "'$compute_id'", "storage_id": "'$storage_id'", "management_network_id": "'$management_network_id'", "management_port_subnets": [{"ip_addresses": ["'$ip'"], "prefix_length": '$prefix_length'}], "default_gateway_addresses": ["'$gateway'"], "data_network_ids": '$(echo $data_network_ids | jq -r -c .)', "reservation_info": { "memory_reservation" : {"reservation_percentage": 100 }, "cpu_reservation": { "reservation_in_shares": "HIGH_PRIORITY", "reservation_in_mhz": 0 }}, "resource_allocation": {"cpu_count": '$cpu', "memory_allocation_in_mb": '$memory' }, "placement_type": "VsphereDeploymentConfig"}, "form_factor": "MEDIUM", "node_user_settings": {"cli_username": "admin", "root_password": "'$TF_VAR_nsx_password'", "cli_password": "'$TF_VAR_nsx_password'"}}, "node_settings": {"hostname": "'$fqdn'", "enable_ssh": true, "allow_ssh_root_login": true }}}')
  nsx_api 6 10 "POST" $cookies_file $headers_file "$(echo $new_json | jq -r -c)" $nsx_ip "api/v1/transport-nodes"
  new_edge_node_response=$(echo $response_body)
  new_edge_node_id=$(echo $new_edge_node_response | jq -r .id)
  edge_ids=$(echo $edge_ids | jq '. += ["'$(echo $new_edge_node_id)'"]')
#  new_edge_node=$(curl -k -s -X POST -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" -d $(echo $new_json | jq -r -c) https://$nsx_ip/api/v1/transport-nodes)
#  new_edge_node_id=$(echo $new_edge_node | jq -r .id)
done
#
# Check the status of Nodes (including transport node and edge nodes)
#
IFS=$'\n'
retry_a=80
pause_a=60
attempt_a=0
#nsx_api 6 10 "GET" $cookies_file $headers_file "" $nsx_ip "policy/api/v1/infra/sites/default/enforcement-points/default/host-transport-nodes/state"
#compute_manager_runtime=$(echo $response_body)
#node_count=$(echo $compute_manager_runtime | jq -c -r '.results | length')
for edge_id in $(echo $edge_ids | jq -c -r .[] ); do
  while true ; do
    echo "attempt $attempt_a to get node id $edge_id ready"
    nsx_api 6 10 "GET" $cookies_file $headers_file "" $nsx_ip "policy/api/v1/infra/sites/default/enforcement-points/default/host-transport-nodes/state"
    edge_runtime=$(echo $response_body)
    for item in $(echo $edge_runtime | jq -c -r .results[])
    do
      if [[ $(echo $item | jq -r .transport_node_id) == $edge_id ]] && [[ $(echo $item | jq -r .state) == "success" ]] ; then
        echo "new edge node id $edge_id state is success after $attempt_a attempts"
        break 2
      fi
    done
    ((attempt_a++))
    if [ $attempt_a -eq $retry_a ]; then
      echo "Unable to get node id $edge_id ready after $attempt_a"
      exit 255
    fi
    sleep $pause_a
  done
done
