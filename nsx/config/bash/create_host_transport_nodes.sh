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
cookies_file="bash/create_host_transport_nodes_cookies.txt"
headers_file="bash/create_host_transport_nodes_headers.txt"
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
/bin/bash bash/create_nsx_api_session.sh admin $TF_VAR_nsx_password $nsx_ip $cookies_file $headers_file
nsx_api 6 10 "GET" $cookies_file $headers_file "" $nsx_ip "api/v1/fabric/compute-collections"
compute_collections=$(echo $response_body)
IFS=$'\n'
for item in $(echo $compute_collections | jq -c -r .results[])
do
  if [[ $(echo $item | jq -r .display_name) == $(jq -r .vcenter.cluster $jsonFile) ]] ; then
    compute_collection_external_id=$(echo $item | jq -r .external_id)
  fi
done
nsx_api 6 10 "GET" $cookies_file $headers_file "" $nsx_ip "api/v1/infra/host-transport-node-profiles"
transport_node_profiles=$(echo $response_body)
IFS=$'\n'
for item in $(echo $transport_node_profiles | jq -c -r .results[])
do
  if [[ $(echo $item | jq -r .display_name) == $(jq -r .nsx.config.transport_node_profiles[0].name $jsonFile) ]] ; then
    transport_node_profile_id=$(echo $item | jq -r .id)
  fi
done
nsx_api 6 10 "POST" $cookies_file $headers_file '{"resource_type": "TransportNodeCollection", "display_name": "TransportNodeCollection-1", "description": "Transport Node Collections 1", "compute_collection_id": "'$compute_collection_external_id'", "transport_node_profile_id": "'$transport_node_profile_id'"}' $nsx_ip "api/v1/transport-node-collections"
#
# waiting for host transport node to be ready
#
sleep 60
nsx_api 10 60 "GET" $cookies_file $headers_file "" $nsx_ip "api/v1/infra/sites/default/enforcement-points/default/host-transport-nodes"
discovered_nodes=$(echo $response_body)
retry_1=60 ; pause_1=30 ; attempt_1=0
IFS=$'\n'
for item in $(echo $discovered_nodes | jq -c -r .results[])
do
  echo "Waiting for host transport nodes to be ready, attempt: $retry_1"
  unique_id=$(echo $item | jq -c -r .unique_id)
  while true ; do
    nsx_api 10 60 "GET" $cookies_file $headers_file "" $nsx_ip "api/v1/infra/sites/default/enforcement-points/default/host-transport-nodes/$unique_id/state"
    hosts_host_transport_node_state=$(echo $response_body)
    if [[ "$(echo $hosts_host_transport_node_state | jq -r .deployment_progress_state.progress)" == 100 ]] && [[ "$(echo $hosts_host_transport_node_state | jq -r .state)" == "success"  ]] ; then
      echo "  Host transport node id $unique_id progress at 100% and host transport node state success"
      break
    else
      echo "  Waiting for host transport node id $unique_id to be ready, attempt: $attempt_1 on $retry_1"
    fi
    if [ $attempt_1 -eq $retry_1 ]; then
      echo "  FAILED to get transport node deployment progress at 100% after $attempt_1"
      echo "$response_body"
      exit 255
    fi
    sleep $pause_1
    ((attempt_1++))
  done
done
rm -f $cookies_file $headers_file




## Retrieve session based details
##
#curl -k -c cookies.txt -D headers.txt -X POST -d 'j_username=admin&j_password='$TF_VAR_nsx_password'' https://$nsx_ip/api/session/create
##
## create host transport node
##
#compute_collections=$(curl -k -s -X GET -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" https://$nsx_ip/api/v1/fabric/compute-collections)
#IFS=$'\n'
#for item in $(echo $compute_collections | jq -c -r .results[])
#do
#  if [[ $(echo $item | jq -r .display_name) == $(jq -r .vcenter.cluster $jsonFile) ]] ; then
#    compute_collection_external_id=$(echo $item | jq -r .external_id)
#  fi
#done
#transport_node_profiles=$(curl -k -s -X GET -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" https://$nsx_ip/policy/api/v1/infra/host-transport-node-profiles)
#IFS=$'\n'
#for item in $(echo $transport_node_profiles | jq -c -r .results[])
#do
#  if [[ $(echo $item | jq -r .display_name) == $(jq -r .nsx.config.transport_node_profiles[0].name $jsonFile) ]] ; then
#    transport_node_profile_id=$(echo $item | jq -r .id)
#  fi
#done
#curl -k -s -X POST -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" -d '{"resource_type": "TransportNodeCollection", "display_name": "TransportNodeCollection-1", "description": "Transport Node Collections 1", "compute_collection_id": "'$compute_collection_external_id'", "transport_node_profile_id": "'$transport_node_profile_id'"}' https://$nsx_ip/api/v1/transport-node-collections
##
## waiting for host transport node to be ready
##
#sleep 60
#discovered_nodes=$(curl -k -s -X GET -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" https://$nsx_ip/policy/api/v1/infra/sites/default/enforcement-points/default/host-transport-nodes)
#IFS=$'\n'
#for item in $(echo $discovered_nodes | jq -c -r .results[])
#do
#  unique_id=$(echo $item | jq -c -r .unique_id)
#  retry=10 ; pause=60 ; attempt=0
#  while [[ "$(curl -k -s -X GET -b cookies.txt -o /dev/null -w ''%{http_code}'' -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" https://$nsx_ip/policy/api/v1/infra/sites/default/enforcement-points/default/host-transport-nodes/$unique_id/state)" != "200" ]]; do
#    echo "waiting for transport node status HTTP code to be 200"
#    sleep $pause
#    ((attempt++))
#    if [ $attempt -eq $retry ]; then
#      echo "FAILED to get NSX Manager API to be ready after $retry"
#      exit 255
#    fi
#  done
#  retry=10 ; pause=60 ; attempt=0
#  while [[ "$(curl -k -s -X GET -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" https://$nsx_ip/policy/api/v1/infra/sites/default/enforcement-points/default/host-transport-nodes/$unique_id/state | jq -r .deployment_progress_state.progress)" != 100 ]]; do
#    echo "waiting for transport node deployment progress at 100%"
#    sleep $pause
#    ((attempt++))
#    if [ $attempt -eq $retry ]; then
#      echo "FAILED to get transport node deployment progress at 100% after $retry"
#      exit 255
#    fi
#  done
#  retry=10 ; pause=60 ; attempt=0
#  while [[ "$(curl -k -s -X GET -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" https://$nsx_ip/policy/api/v1/infra/sites/default/enforcement-points/default/host-transport-nodes/$unique_id/state | jq -r .state)" != "success" ]]; do
#    echo "waiting for transport node status success"
#    sleep $pause
#    ((attempt++))
#    if [ $attempt -eq $retry ]; then
#      echo "FAILED to get transport node status success after $retry"
#      exit 255
#    fi
#  done
#done