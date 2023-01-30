#!/bin/bash
#
if [ -f "../../variables.json" ]; then
  jsonFile="../../variables.json"
else
  echo "ERROR: no json file found"
  exit 1
fi
nsx_ip=$(jq -r .vcenter.vds.portgroup.management.nsx_ip $jsonFile)
cookies_file="bash/create_edge_clusters_cookies.txt"
headers_file="bash/create_edge_clusters_headers.txt"
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
IFS=$'\n'
#
# check the json syntax for tier0s (.nsx.config.edge_clusters)
#
if [[ $(jq 'has("nsx")' $jsonFile) && $(jq '.nsx | has("config")' $jsonFile) && $(jq '.nsx.config | has("edge_clusters")' $jsonFile) == "false" ]] ; then
  echo "no json valid entry for nsx.config.edge_clusters"
  exit
fi
#
# edge cluster creation
#
new_json=[]
edge_cluster_count=0
for edge_cluster in $(jq -c -r .nsx.config.edge_clusters[] $jsonFile)
do
  new_json=$(echo $new_json | jq -r -c '. |= .+ ['$edge_cluster']')
  new_json=$(echo $new_json | jq '.['$edge_cluster_count'] += {"members": []}')
  for name_edge_cluster in $(echo $edge_cluster | jq -r .members_name[])
  do
    nsx_api 6 10 "GET" $cookies_file $headers_file "" $nsx_ip "api/v1/transport-nodes"
    edge_node_ids=$(echo $response_body)
#    edge_node_ids=$(curl -k -s -X GET -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" https://$nsx_ip/api/v1/transport-nodes)
    IFS=$'\n'
    for item in $(echo $edge_node_ids | jq -c -r .results[])
    do
      if [[ $(echo $item | jq -r .display_name) == $name_edge_cluster ]] ; then
        edge_node_id=$(echo $item | jq -r .id)
      fi
    done
    new_json=$(echo $new_json | jq '.['$edge_cluster_count'].members += [{"transport_node_id": "'$edge_node_id'", "display_name": "'$name_edge_cluster'"}]')
  done
  new_json=$(echo $new_json | jq 'del (.['$edge_cluster_count'].members_name)' )
  edge_cluster_count=$((edge_cluster_count+1))
done
for edge_cluster in $(echo $new_json | jq .[] -c -r)
do
  echo "edge cluster creation"
  nsx_api 18 10 "POST" $cookies_file $headers_file "$(echo $edge_cluster)" $nsx_ip "api/v1/edge-clusters"
#  curl -k -s -X POST -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" -d $(echo $edge_cluster) https://$nsx_ip/api/v1/edge-clusters
done



#
#curl -k -c cookies.txt -D headers.txt -X POST -d 'j_username=admin&j_password='$TF_VAR_nsx_password'' https://$nsx_ip/api/session/create
#IFS=$'\n'
##
## check the json syntax for tier0s (.nsx.config.edge_clusters)
##
#if [[ $(jq 'has("nsx")' $jsonFile) && $(jq '.nsx | has("config")' $jsonFile) && $(jq '.nsx.config | has("edge_clusters")' $jsonFile) == "false" ]] ; then
#  echo "no json valid entry for nsx.config.edge_clusters"
#  exit
#fi
##
## edge cluster creation
##
#new_json=[]
#edge_cluster_count=0
#for edge_cluster in $(jq -c -r .nsx.config.edge_clusters[] $jsonFile)
#do
#  new_json=$(echo $new_json | jq -r -c '. |= .+ ['$edge_cluster']')
#  new_json=$(echo $new_json | jq '.['$edge_cluster_count'] += {"members": []}')
#  for name_edge_cluster in $(echo $edge_cluster | jq -r .members_name[])
#  do
#    edge_node_ids=$(curl -k -s -X GET -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" https://$nsx_ip/api/v1/transport-nodes)
#    IFS=$'\n'
#    for item in $(echo $edge_node_ids | jq -c -r .results[])
#    do
#      if [[ $(echo $item | jq -r .display_name) == $name_edge_cluster ]] ; then
#        edge_node_id=$(echo $item | jq -r .id)
#      fi
#    done
#    new_json=$(echo $new_json | jq '.['$edge_cluster_count'].members += [{"transport_node_id": "'$edge_node_id'", "display_name": "'$name_edge_cluster'"}]')
#  done
#  new_json=$(echo $new_json | jq 'del (.['$edge_cluster_count'].members_name)' )
#  edge_cluster_count=$((edge_cluster_count+1))
#done
#for edge_cluster in $(echo $new_json | jq .[] -c -r)
#do
#  echo "edge cluster creation"
#  curl -k -s -X POST -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" -d $(echo $edge_cluster) https://$nsx_ip/api/v1/edge-clusters
#done
