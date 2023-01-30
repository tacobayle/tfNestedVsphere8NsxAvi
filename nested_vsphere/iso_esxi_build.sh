#!/bin/bash
#
if [ -f "../variables.json" ]; then
  jsonFile="../variables.json"
else
  exit 1
fi
#
iso_mount_location="/tmp/esxi_cdrom_mount"
iso_build_location="/tmp/esxi_cdrom"
iso_source_location=$(cat $jsonFile | jq -r .esxi.iso_source_location)
boot_cfg_location=$(cat $jsonFile | jq -r .esxi.boot_cfg_location)
iso_location=$(cat $jsonFile | jq -r .esxi.iso_location)
count=$(cat $jsonFile | jq -r .esxi.count)
#
echo ""
echo "++++++++++++++++++++++++++++++++"
mkdir -p $iso_mount_location
if grep -qs $iso_mount_location /proc/mounts; then
    echo "Esxi ISO file already mounted"
else
    echo "Mounting ESXi ISO file"
    sudo mount -o loop $iso_source_location $iso_mount_location
fi
#
echo ""
echo "++++++++++++++++++++++++++++++++"
echo "Copying source ESXi ISO to Build directory"
sudo rm -fr $iso_build_location
mkdir -p $iso_build_location
cp -r $iso_mount_location/* $iso_build_location
#
echo ""
echo "++++++++++++++++++++++++++++++++"
if grep -qs $iso_mount_location /proc/mounts; then
    echo "unmounting ESXi ISO file"
    sudo umount $iso_mount_location
fi
rm -fr $iso_mount_location
#
echo ""
echo "++++++++++++++++++++++++++++++++"
echo "Modifying $iso_build_location/$boot_cfg_location"
IFS=$'\n'
for line in $(cat $jsonFile | jq -r .esxi.boot_cfg_lines[])
do
  echo $line | sudo tee -a $iso_build_location/$boot_cfg_location
done
#
for esx in $(seq 0 $(expr $count - 1))
do
echo ""
echo "++++++++++++++++++++++++++++++++"
echo "Building custom ESXi ISO for ESXi$esx"
  sudo rm -f $iso_location$esx.iso
  sudo rm -f $iso_build_location/ks_cust.cfg
  echo ""
  echo "+++++++++++++++++++"
  echo "Copying ks_cust.cfg"
  cp ks_cust.cfg.$esx $iso_build_location/ks_cust.cfg
  echo ""
  echo "+++++++++++++++++++"
  echo "Building new ISO"
  sudo genisoimage -relaxed-filenames -J -R -o $iso_location$esx.iso -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e efiboot.img -no-emul-boot $iso_build_location
  echo "+++++++++++++++++++"
done
#
sudo rm -fr $iso_build_location
