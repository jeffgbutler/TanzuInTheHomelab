# NSX ALB Configuration Notes

## Step 1 - Setup Default Cloud

- Add vSphere Credentials
- Set management network to Supervisor-Management-Network (192.168.138.0/24) with IP Pool 192.168.138.180-192.168.138.187 (should be SE only)

## Step 2 - Setup VIP Network

- Configure Workload-VIP-Network (192.168.139.0/24) with IP Pool 192.168.139.2 - 192.168.139.126 (must be for SE and VIP - the default)

## Step 3 - Setup IPAM Profile

- Create IPAM profile and add both networks to it
- Update default cloud with the new IPAM profile

## Step 4 - Static Route

- Add static route in global VRF context: 0.0.0.0/0 -> 192.168.139.1

## Step 5 - SE Group

- Update Default-Group - VMs can have 2 CPU and 4GB RAM

## Step 6 - Certificate

- Create controller certificate with nsx-alb.tkgs.tanzuathome.net and 192.168.138.9
- Setup access using the new certificate and allow basic auth

## Step 7 - Licensing

- Change licensing model to enterprise and add the license key
