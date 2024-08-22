# Basic Infrastructure Setup

The nested environments use VLANs for isolation. They also require a larger MTU than default. Here's what to change...

## Router/Switch Setup

| Item     | VLAN | IP Address       | MTU  |
|----------|------|------------------|------|
| switch0  | N/A  | None             | 2000 |
| VLAN 128 | 128  | 192.168.128.1/24 | 2000 |
| VLAN 137 | 137  | 192.168.137.1/24 | 2000 |
| VLAN 138 | 138  | 192.168.138.1/24 | 2000 |
| VLAN 139 | 139  | 192.168.139.1/24 | 2000 |
| VLAN 140 | 140  | 192.168.140.1/24 | 2000 |
| VLAN 141 | 141  | 192.168.141.1/24 | 2000 |

Switch VLAN Configuration:

| Port | pvid | vid                 |
|------|------|---------------------|
| eth1 | 128  | 137,138,139,140,141 |
| eth2 | 128  | 137,138,139,140,141 |
| eth3 | 128  | 137,138,139,140,141 |
| eth4 | 128  | 137,138,139,140,141 |

## vCenter Network Setup

1. Configure vSwitch0 for MTU 2000, allow Promiscuous Mode, Allow Forged Transmits
2. Configure vmk0 for MTU 2000
3. Add Port Groups:

   | Name           | VLAN ID |
   |----------------|---------|
   | vm-network-137 | 137     |
   | vm-network-138 | 138     |
   | vm-network-139 | 139     |
   | vm-network-140 | 140     |
   | vm-network-141 | 141     |

## vCenter Storage Setup

Mark the ssdVolume as flash: host > Configure > Storage Devices
