```
root@edg01:~#
root@edg01:~# su - admin

NSX CLI (Edge 3.2.0.0.0.19067089). Press ? for command list or enter: help
edg01>
edg01>
edg01>
edg01> help
NSX CLI help is available via a variety of different ways:

1. From the command prompt, enter: help
   This full help message is shown.

2. Tab completion
   Tab completion is always available to either complete a valid
   command word or complete a valid argument. If completion cannot
   be performed, a message is shown to indicate the reason.
   For example: ge<tab>

3. Pressing ?
   At any time, pressing ? shows possible options for the command
   entered. If no options are available, a helpful message is
   shown to indicate the reason.
   For example: get ?

4. From the command prompt, enter: list
   View all supported commands and command parameters.

edg01> get logical-router
Tue Feb 22 2022 UTC 13:16:03.514
Logical Router
UUID                                   VRF    LR-ID  Name                              Type                        Ports   Neighbors
736a80e3-23f6-5a2d-81d6-bbefb2786666   0      0                                        TUNNEL                      3       1/5000
687cc1c7-a4e7-4e8f-abf2-e02c35cfaeb3   1      2      SR-tier0-01                       SERVICE_ROUTER_TIER0        6       0/50000
9bc71065-9c9e-4681-8533-3e28d980db8d   3      1      DR-tier0-01                       DISTRIBUTED_ROUTER_TIER0    5       2/50000
122e750b-60b5-44a6-930f-31cee494fdaa   4      3      DR-tier1-01                       DISTRIBUTED_ROUTER_TIER1    5       2/50000

edg01>
edg01>
edg01> vrf 0
edg01(vrf)>
clear        Clear setting
exit         Exit from current mode
get          Retrieve the current configuration
help         Display help
list         List all available commands
ping         Send echo messages for IPv4 addresses
ping6        Send echo messages for IPv6 addresses
reset        Reset settings
set          Change the current configuration
traceroute   Trace route to destination hostname or IP address
traceroute6  Trace route to IPv6 destination address

edg01(vrf)> get interfaces
Tue Feb 22 2022 UTC 13:16:32.272
Logical Router
UUID                                   VRF    LR-ID  Name                              Type
736a80e3-23f6-5a2d-81d6-bbefb2786666   0      0                                        TUNNEL
Interfaces (IPv6 DAD Status A-DAD_Success, F-DAD_Duplicate, T-DAD_Tentative, U-DAD_Unavailable)
Interface     : 8f6a05bd-e029-5be4-ac5f-d5a9f5823ca0
Ifuid         : 259
Mode          : cpu
Port-type     : cpu
Enable-mcast  : true

    Interface     : 15bf0648-c24c-500f-9336-b3eb23135563
    Ifuid         : 260
    Mode          : blackhole
    Port-type     : blackhole

    Interface     : 8cd64f93-7e49-557a-b013-62f829d81fbb
    Ifuid         : 261
    Name          :
    Fwd-mode      : IPV4_ONLY
    Internal name : uplink-261
    Mode          : lif
    Port-type     : uplink
    IP/Mask       : 10.8.1.37/27
    MAC           : 00:50:56:a1:0f:e2
    VLAN          : untagged
    Access-VLAN   : untagged
    LS port       : 7a88ce54-3e17-55e4-acde-1f14b0d4ac89
    Urpf-mode     : PORT_CHECK
    DAD-mode      : LOOSE
    RA-mode       : RA_INVALID
    Admin         : up
    Op_state      : up
    Enable-mcast  : True
    MTU           : 1700
    arp_proxy     :

edg01(vrf)> ping 10.8.1.34
PING 10.8.1.34 (10.8.1.34): 56 data bytes
64 bytes from 10.8.1.34: icmp_seq=0 ttl=64 time=2.834 ms
64 bytes from 10.8.1.34: icmp_seq=1 ttl=64 time=2.341 ms
^C^[[A
--- 10.8.1.34 ping statistics ---
3 packets transmitted, 2 packets received, 33.3% packet loss
round-trip min/avg/max/stddev = 2.341/2.588/2.834/0.246 ms

edg01(vrf)> ping 10.8.1.35
PING 10.8.1.35 (10.8.1.35): 56 data bytes
64 bytes from 10.8.1.35: icmp_seq=0 ttl=64 time=5.127 ms
64 bytes from 10.8.1.35: icmp_seq=1 ttl=64 time=1.261 ms
^C
--- 10.8.1.35 ping statistics ---
3 packets transmitted, 2 packets received, 33.3% packet loss
round-trip min/avg/max/stddev = 1.261/3.194/5.127/1.933 ms

edg01(vrf)>
edg01(vrf)> ping 10.8.1.36
PING 10.8.1.36 (10.8.1.36): 56 data bytes
64 bytes from 10.8.1.36: icmp_seq=0 ttl=64 time=4.931 ms
64 bytes from 10.8.1.36: icmp_seq=1 ttl=64 time=2.063 ms
^C
--- 10.8.1.36 ping statistics ---
3 packets transmitted, 2 packets received, 33.3% packet loss
round-trip min/avg/max/stddev = 2.063/3.497/4.931/1.434 ms

edg01(vrf)>
edg01(vrf)>
```