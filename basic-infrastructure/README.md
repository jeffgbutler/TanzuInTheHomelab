# Basic Infrastructure Setup

The nested environments use VLANs for isolation. They also require a larger MTU than default. Here's what to change...

## Router/Switch

| Item     | VLAN | IP Address       | MTU  |
|----------|------|------------------|------|
| switch0  | N/A  | None             | 1600 |
| VLAN 128 | 128  | 192.168.128.1/24 | 1600 |
| VLAN 138 | 138  | 192.168.138.1/24 | 1600 |
| VLAN 139 | 139  | 192.168.139.1/24 | 1600 |
| VLAN 140 | 140  | 192.168.140.1/24 | 1600 |
| VLAN 141 | 141  | 192.168.141.1/24 | 1600 |

Switch VLAN Configuration:

| Port | pvid | vid             |
|------|------|-----------------|
| eth1 | 128  | 138,139,140,141 |
| eth2 | 128  | 138,139,140,141 |
| eth3 | 128  | 138,139,140,141 |
| eth4 | 128  | 138,139,140,141 |

## vCenter

1. Configure vSwitch0 for MTU 1600, allow Promiscuous Mode, Allow Forged Transmits
2. Configure vmk0 for MTU 1600
3. Add Port Groups:

   | Name           | VLAN ID |
   |----------------|---------|
   | vm-network-138 | 138     |
   | vm-network-139 | 139     |
   | vm-network-140 | 140     |
   | vm-network-141 | 141     |

