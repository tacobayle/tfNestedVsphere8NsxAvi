ansible-playbook vmk.yml --extra-vars @variables.json
ssh root@10.41.134.138
portid=$(esxcfg-vswitch -l |grep vmk4 |awk '{print $1}')
esxcli network ip interface remove --interface-name=vmk0
esxcli network ip interface remove --interface-name=vmk4
esxcli network ip interface add --interface-name=vmk0 --dvs-name=dvs-0-mgmt --dvport-id=$portid
esxcli network ip interface ipv4 set --interface-name=vmk0 --ipv4=10.41.134.133 --netmask=255.255.252.0 --type=static
exit
ssh root@10.41.134.133
esxcli network ip interface remove --interface-name=vmk3
exit