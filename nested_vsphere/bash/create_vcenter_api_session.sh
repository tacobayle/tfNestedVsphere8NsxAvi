#!/bin/bash
#
# $1 is the username
# $2 is the SSO domain
# $3 is the password
# $4 is the vCenter FQDN
#
retry=6
pause=10
attempt=0
while true ; do
  response=$(curl -k -s --write-out "\n%{http_code}" -X POST -u "$1@$2:$3" https://$4/api/session -H "Content-Type: application/json")
  http_code=$(tail -n1 <<< "$response")
  content=$(sed '$ d' <<< "$response")
  if [[ $http_code == 20[0-9] ]] ; then
    echo $content | tr -d \"
    break
  fi
  if [ $attempt -eq $retry ]; then
    echo "  FAILED to create vCenter API session failed, http_response_code: $http_code"
    exit 255
  fi
  sleep $pause
  ((attempt++))
done