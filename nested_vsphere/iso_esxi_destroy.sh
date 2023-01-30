#!/bin/bash
#
if [ -f "../variables.json" ]; then
  jsonFile="../variables.json"
else
  exit 1
fi
#
iso_location=$(cat $jsonFile | jq -r .esxi.iso_location)
count=$(cat $jsonFile | jq -r .esxi.count)
#
for esx in $(seq 0 $(expr $count - 1))
do
  echo ""
  echo "++++++++++++++++++++++++++++++++"
  echo "removing ESXi Custom ISOs"
  sudo rm -f $iso_location$esx.iso
done
