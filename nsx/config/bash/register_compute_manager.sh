#!/bin/bash
#
if [ -f "../../variables.json" ]; then
  jsonFile="../../variables.json"
else
  echo "ERROR: no json file found"
  exit 1
fi
#
nsx_ip=$(jq -r .vcenter.vds.portgroup.management.nsx_ip $jsonFile)
vcenter_username=administrator
vcenter_domain=$(jq -r .vcenter.sso.domain_name $jsonFile)
vcenter_fqdn="$(jq -r .vcenter.name $jsonFile).$(jq -r .external_gw.bind.domain $jsonFile)"
cookies_file="bash/register_compute_manager_cookies.txt"
headers_file="bash/register_compute_manager_headers.txt"
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
ValidCmThumbPrint=$(openssl s_client -connect $vcenter_fqdn:443 < /dev/null 2>/dev/null | openssl x509 -fingerprint -sha256 -noout -in /dev/stdin | awk -F'Fingerprint=' '{print $2}')
nsx_api 6 10 "POST" $cookies_file $headers_file '{"display_name": "'$vcenter_fqdn'", "server": "'$vcenter_fqdn'", "create_service_account": true, "access_level_for_oidc": "FULL", "origin_type": "vCenter", "set_as_oidc_provider" : true, "credential": {"credential_type": "UsernamePasswordLoginCredential", "username": "'$vcenter_username'@'$vcenter_domain'", "password": "'$TF_VAR_vcenter_password'", "thumbprint": "'$ValidCmThumbPrint'"}}' $nsx_ip "api/v1/fabric/compute-managers"
compute_manager_id=$(echo $response_body | jq -r .id)
retry=6
pause=10
attempt=0
echo "Waiting for compute manager to be UP and REGISTERED"
while true ; do
  nsx_api 6 10 "GET" $cookies_file $headers_file "" $nsx_ip "api/v1/fabric/compute-managers/$compute_manager_id/status"
  if [[ $(echo $response_body | jq -r .connection_status) == "UP" && $(echo $response_body | jq -r .registration_status) == "REGISTERED" ]] ; then
    echo "compute manager UP and REGISTERED"
    break
  fi
  if [ $attempt -eq $retry ]; then
    echo "FAILED to get compute manager UP and REGISTERED after $retry retries"
    exit 255
  fi
  sleep $pause
  ((attempt++))
done
rm -f $cookies_file $headers_file