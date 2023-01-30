```shell
ubuntu@jump-sofia:~/nestedEsxiVcenter/nsx/config$
ubuntu@jump-sofia:~/nestedEsxiVcenter/nsx/config$ ansible-playbook ansible/tnp.yml -e @../../variables.json
[WARNING]: No inventory was parsed, only implicit localhost is available
[WARNING]: provided hosts list is empty, only localhost is available. Note that the implicit localhost does not match 'all'

PLAY [localhost] ****************************************************************************************************************************************************************************

TASK [List Transport Node Profiles] *********************************************************************************************************************************************************
ok: [localhost]

TASK [Debug] ********************************************************************************************************************************************************************************
ok: [localhost] => {
    "msg": {
        "changed": false,
        "failed": false,
        "result_count": 1,
        "results": [
            {
                "_create_time": 1632547791283,
                "_create_user": "admin",
                "_last_modified_time": 1632547791283,
                "_last_modified_user": "admin",
                "_protection": "NOT_PROTECTED",
                "_revision": 0,
                "_system_owned": false,
                "description": "descr",
                "display_name": "tnp-1",
                "host_switch_spec": {
                    "host_switches": [
                        {
                            "cpu_config": [],
                            "host_switch_id": "50 1b e1 cc 25 39 d4 e4-95 95 8b 93 7d 0f e4 7d",
                            "host_switch_mode": "STANDARD",
                            "host_switch_name": "nsx_overlay_vds",
                            "host_switch_profile_ids": [
                                {
                                    "key": "UplinkHostSwitchProfile",
                                    "value": "632416fb-bb76-4ae7-aadd-d1e76800ebb3"
                                }
                            ],
                            "host_switch_type": "VDS",
                            "ip_assignment_spec": {
                                "ip_pool_id": "689a7b6f-d11d-4cda-80bf-72b8d88c5aea",
                                "resource_type": "StaticIpPoolSpec"
                            },
                            "is_migrate_pnics": false,
                            "not_ready": false,
                            "pnics": [],
                            "pnics_uninstall_migration": [],
                            "transport_zone_endpoints": [
                                {
                                    "transport_zone_id": "125b9f0b-1933-443a-9081-280e8102552a",
                                    "transport_zone_profile_ids": [
                                        {
                                            "profile_id": "52035bb3-ab02-4a08-9884-18631312e50a",
                                            "resource_type": "BfdHealthMonitoringProfile"
                                        }
                                    ]
                                }
                            ],
                            "uplinks": [
                                {
                                    "uplink_name": "uplink-1",
                                    "vds_uplink_name": "uplink1"
                                }
                            ],
                            "vmk_install_migration": [],
                            "vmk_uninstall_migration": []
                        }
                    ],
                    "resource_type": "StandardHostSwitchSpec"
                },
                "id": "d33fc6ef-c05b-4d5f-aa39-de654d04fb65",
                "ignore_overridden_hosts": false,
                "resource_type": "TransportNodeProfile",
                "tags": [],
                "transport_zone_endpoints": []
            }
        ],
        "sort_ascending": true,
        "sort_by": "display_name"
    }
}

PLAY RECAP **********************************************************************************************************************************************************************************
localhost                  : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

ubuntu@jump-sofia:~/nestedEsxiVcenter/nsx/config$

```