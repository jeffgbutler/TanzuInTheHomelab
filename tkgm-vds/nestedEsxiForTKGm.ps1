# Script to install a neseted vCenter and EXSi to prepare for TKGm installation with Tanzu Service Installer
#
# Adapted from the original by William Lam (www.williamlam.com)
# Author: Jeff Butler

# vCenter Server used to deploy vSphere with Tanzu with NSX Advanced Load Balancer Lab
$VIServer = "vcsa.tanzuathome.net"
$VIUsername = "administrator@vsphere.local"
$VIPassword = "entered interactively"

# Full Path to both the Nested ESXi 7.0 VA and Extracted VCSA 7.0 ISO
$NestedESXiApplianceOVA = "/Users/jeffbutler/NestedVCF/Nested_ESXi7.0u3c_Appliance_Template_v1.ova"
$VCSAInstallerPath = "/Users/jeffbutler/NestedVCF/VMware-VCSA-all-7.0.3-19234570"
$NSXAdvLBOVA = "/Users/jeffbutler/NestedVCF/controller-20.1.7-9154.ova"

# Nested ESXi VMs to deploy
$NestedESXiHostnameToIPs = @{
    "tkgm-esxi-1" = "192.168.136.4"
    "tkgm-esxi-2" = "192.168.136.5"
    "tkgm-esxi-3" = "192.168.136.6"
}

# Nested ESXi VM Resources
$NestedESXivCPU = "16"
$NestedESXiCoresPerSocket = "4"
$NestedESXivMEM = "96" #GB
$NestedESXiCachingvDisk = "32" #GB
$NestedESXiCapacityvDisk = "500" #GB

# VCSA Deployment Configuration
$VCSADeploymentSize = "small"
$VCSADisplayName = "tkgm-vcsa"
$VCSAIPAddress = "192.168.136.3"
$VCSAHostname = "vcsa.tkgm.tanzuathome.net" #Change to IP if you don't have valid DNS
$VCSAPrefix = "24"
$VCSASSODomainName = "vsphere.local"
$VCSASSOPassword = "VMware1!"
$VCSARootPassword = "VMware1!"
$VCSASSHEnable = "true"

# Networks for TKGm
$VMNetwork2 = "vm-network-132"
$VMNetwork3 = "vm-network-133"
$VMNetwork4 = "vm-network-134"
$VMNetwork5 = "vm-network-135"
$VMNetwork6 = "vm-network-137"

# Portgroup Names for Nested vCenter
$Portgroup1 = "vlan-136"
$Portgroup2 = "vlan-132"
$Portgroup3 = "vlan-dhcp-133"
$Portgroup4 = "vlan-dhcp-134"
$Portgroup5 = "vlan-135"
$Portgroup6 = "vlan-137"

# General Deployment Configuration for Nested ESXi, & VCSA
$VMDatacenter = "Datacenter"
$VMCluster = "LabCluster"
$VMNetwork1 = "vm-network-136"
$VMDatastore = "VMStorage"
$VMNetmask = "255.255.255.0"
$VMGateway = "192.168.136.1"
$VMDNS = "192.168.128.1"
$VMNTP = "pool.ntp.org"
$VMPassword = "VMware1!"
$VMDomain = "tkgm.tanzuathome.net"
$VMFolder = "NESTED-TKGM-NSX-ALB"
# Applicable to Nested ESXi only
$VMSSH = "true"
$VMVMFS = "false"

# Name of new vSphere Datacenter/Cluster when VCSA is deployed
$NewVCDatacenterName = "Tanzu-Datacenter"
$NewVCVSANClusterName = "Workload-Cluster"
$NewVCVDSName = "Tanzu-VDS"

# Tanzu Configuration
$StoragePolicyName = "tanzu-gold-storage-policy"
$StoragePolicyTagCategory = "tanzu-demo-tag-category"
$StoragePolicyTagName = "tanzu-demo-storage"

# Advanced Configurations
# Set to 1 only if you have DNS (forward/reverse) for ESXi hostnames
$addHostByDnsName = 1

#### DO NOT EDIT BEYOND HERE ####

$verboseLogFile = "tkgm-lab-deployment.log"
$random_string = -join ((65..90) + (97..122) | Get-Random -Count 8 | ForEach-Object {[char]$_})
$VAppName = "Nested-TKGM-Lab-$random_string"

$preCheck = 1
$confirmDeployment = 1
$deployNestedESXiVMs = 1
$deployVCSA = 1
$setupNewVC = 1
$addESXiHostsToVC = 1
$configureVSANDiskGroup = 1
$configureVDS = 1
$clearVSANHealthCheckAlarm = 1
$setupTanzuStoragePolicy = 1
$moveVMsIntovApp = 1
$setupAVIContentLibrary = 1

$vcsaSize2MemoryStorageMap = @{
"tiny"=@{"cpu"="2";"mem"="12";"disk"="415"};
"small"=@{"cpu"="4";"mem"="19";"disk"="480"};
"medium"=@{"cpu"="8";"mem"="28";"disk"="700"};
"large"=@{"cpu"="16";"mem"="37";"disk"="1065"};
"xlarge"=@{"cpu"="24";"mem"="56";"disk"="1805"}
}

$esxiTotalCPU = 0
$vcsaTotalCPU = 0
$esxiTotalMemory = 0
$vcsaTotalMemory = 0
$esxiTotalStorage = 0
$vcsaTotalStorage = 0

$StartTime = Get-Date

Function My-Logger {
    param(
    [Parameter(Mandatory=$true)][String]$message,
    [Parameter(Mandatory=$false)][String]$color="green"
    )

    $timeStamp = Get-Date -Format "MM-dd-yyyy_hh:mm:ss"

    Write-Host -NoNewline -ForegroundColor White "[$timestamp]"
    Write-Host -ForegroundColor $color " $message"
    $logMessage = "[$timeStamp] $message"
    $logMessage | Out-File -Append -LiteralPath $verboseLogFile
}

$VIPassword = Read-Host -Prompt "Please Enter vSphere Password"
Clear-Host

if($preCheck -eq 1) {
    if(!(Test-Path $NestedESXiApplianceOVA)) {
        Write-Host -ForegroundColor Red "`nUnable to find $NestedESXiApplianceOVA ...`n"
        exit
    }

    if(!(Test-Path $VCSAInstallerPath)) {
        Write-Host -ForegroundColor Red "`nUnable to find $VCSAInstallerPath ...`n"
        exit
    }

    if( !(Test-Path $NSXAdvLBOVA) -and $setupAVIContentLibrary -eq 1) {
        Write-Host -ForegroundColor Red "`nUnable to find $NSXAdvLBOVA ...`n"
        exit
    }

    if($PSVersionTable.PSEdition -ne "Core") {
        Write-Host -ForegroundColor Red "`tPowerShell Core was not detected, please install that before continuing ... `n"
        exit
    }
}

if($confirmDeployment -eq 1) {
    Write-Host -ForegroundColor Magenta "`nPlease confirm the following configuration will be deployed:`n"

    Write-Host -ForegroundColor Yellow "---- vSphere with Tanzu Basic Automated Lab Deployment Configuration ---- "
    Write-Host -NoNewline -ForegroundColor Green "Nested ESXi Image Path: "
    Write-Host -ForegroundColor White $NestedESXiApplianceOVA
    Write-Host -NoNewline -ForegroundColor Green "VCSA Image Path: "
    Write-Host -ForegroundColor White $VCSAInstallerPath

    Write-Host -ForegroundColor Yellow "`n---- vCenter Server Deployment Target Configuration ----"
    Write-Host -NoNewline -ForegroundColor Green "vCenter Server Address: "
    Write-Host -ForegroundColor White $VIServer
    Write-Host -NoNewline -ForegroundColor Green "VM Network: "
    Write-Host -ForegroundColor White $VMNetwork1

    Write-Host -NoNewline -ForegroundColor Green "VM Storage: "
    Write-Host -ForegroundColor White $VMDatastore
    Write-Host -NoNewline -ForegroundColor Green "VM Cluster: "
    Write-Host -ForegroundColor White $VMCluster
    Write-Host -NoNewline -ForegroundColor Green "VM vApp: "
    Write-Host -ForegroundColor White $VAppName

    Write-Host -ForegroundColor Yellow "`n---- vESXi Configuration ----"
    Write-Host -NoNewline -ForegroundColor Green "# of Nested ESXi VMs: "
    Write-Host -ForegroundColor White $NestedESXiHostnameToIPs.count
    Write-Host -NoNewline -ForegroundColor Green "vCPU: "
    Write-Host -ForegroundColor White $NestedESXivCPU
    Write-Host -NoNewline -ForegroundColor Green "vMEM: "
    Write-Host -ForegroundColor White "$NestedESXivMEM GB"
    Write-Host -NoNewline -ForegroundColor Green "Caching VMDK: "
    Write-Host -ForegroundColor White "$NestedESXiCachingvDisk GB"
    Write-Host -NoNewline -ForegroundColor Green "Capacity VMDK: "
    Write-Host -ForegroundColor White "$NestedESXiCapacityvDisk GB"
    Write-Host -NoNewline -ForegroundColor Green "IP Address(s): "
    Write-Host -ForegroundColor White $NestedESXiHostnameToIPs.Values
    Write-Host -NoNewline -ForegroundColor Green "Netmask "
    Write-Host -ForegroundColor White $VMNetmask
    Write-Host -NoNewline -ForegroundColor Green "Gateway: "
    Write-Host -ForegroundColor White $VMGateway
    Write-Host -NoNewline -ForegroundColor Green "DNS: "
    Write-Host -ForegroundColor White $VMDNS
    Write-Host -NoNewline -ForegroundColor Green "NTP: "
    Write-Host -ForegroundColor White $VMNTP
    Write-Host -NoNewline -ForegroundColor Green "Enable SSH: "
    Write-Host -ForegroundColor White $VMSSH
    Write-Host -NoNewline -ForegroundColor Green "Create VMFS Volume: "
    Write-Host -ForegroundColor White $VMVMFS

    Write-Host -ForegroundColor Yellow "`n---- VCSA Configuration ----"
    Write-Host -NoNewline -ForegroundColor Green "Deployment Size: "
    Write-Host -ForegroundColor White $VCSADeploymentSize
    Write-Host -NoNewline -ForegroundColor Green "SSO Domain: "
    Write-Host -ForegroundColor White $VCSASSODomainName
    Write-Host -NoNewline -ForegroundColor Green "Enable SSH: "
    Write-Host -ForegroundColor White $VCSASSHEnable
    Write-Host -NoNewline -ForegroundColor Green "Hostname: "
    Write-Host -ForegroundColor White $VCSAHostname
    Write-Host -NoNewline -ForegroundColor Green "IP Address: "
    Write-Host -ForegroundColor White $VCSAIPAddress
    Write-Host -NoNewline -ForegroundColor Green "Netmask "
    Write-Host -ForegroundColor White $VMNetmask
    Write-Host -NoNewline -ForegroundColor Green "Gateway: "
    Write-Host -ForegroundColor White $VMGateway

    $esxiTotalCPU = $NestedESXiHostnameToIPs.count * [int]$NestedESXivCPU
    $esxiTotalMemory = $NestedESXiHostnameToIPs.count * [int]$NestedESXivMEM
    $esxiTotalStorage = ($NestedESXiHostnameToIPs.count * [int]$NestedESXiCachingvDisk) + ($NestedESXiHostnameToIPs.count * [int]$NestedESXiCapacityvDisk)
    $vcsaTotalCPU = $vcsaSize2MemoryStorageMap.$VCSADeploymentSize.cpu
    $vcsaTotalMemory = $vcsaSize2MemoryStorageMap.$VCSADeploymentSize.mem
    $vcsaTotalStorage = $vcsaSize2MemoryStorageMap.$VCSADeploymentSize.disk

    Write-Host -ForegroundColor Yellow "`n---- Resource Requirements ----"
    Write-Host -NoNewline -ForegroundColor Green "ESXi     VM CPU: "
    Write-Host -NoNewline -ForegroundColor White $esxiTotalCPU
    Write-Host -NoNewline -ForegroundColor Green " ESXi    VM Memory: "
    Write-Host -NoNewline -ForegroundColor White $esxiTotalMemory "GB "
    Write-Host -NoNewline -ForegroundColor Green "ESXi     VM Storage: "
    Write-Host -ForegroundColor White $esxiTotalStorage "GB"
    Write-Host -NoNewline -ForegroundColor Green "VCSA     VM CPU: "
    Write-Host -NoNewline -ForegroundColor White $vcsaTotalCPU
    Write-Host -NoNewline -ForegroundColor Green " VCSA     VM Memory: "
    Write-Host -NoNewline -ForegroundColor White $vcsaTotalMemory "GB "
    Write-Host -NoNewline -ForegroundColor Green "VCSA     VM Storage: "
    Write-Host -ForegroundColor White $vcsaTotalStorage "GB"

    Write-Host -ForegroundColor White "---------------------------------------------"
    Write-Host -NoNewline -ForegroundColor Green "Total CPU: "
    Write-Host -ForegroundColor White ($esxiTotalCPU + $vcsaTotalCPU + $nsxManagerTotalCPU)
    Write-Host -NoNewline -ForegroundColor Green "Total Memory: "
    Write-Host -ForegroundColor White ($esxiTotalMemory + $vcsaTotalMemory) "GB"
    Write-Host -NoNewline -ForegroundColor Green "Total Storage: "
    Write-Host -ForegroundColor White ($esxiTotalStorage + $vcsaTotalStorage) "GB"

    Write-Host -ForegroundColor Magenta "`nWould you like to proceed with this deployment?`n"
    $answer = Read-Host -Prompt "Do you accept (Y or N)"
    if($answer -ne "Y" -or $answer -ne "y") {
        exit
    }
    Clear-Host
}

if( $deployNestedESXiVMs -eq 1 -or $deployVCSA -eq 1) {
    My-Logger "Connecting to Management vCenter Server $VIServer ..."
    $viConnection = Connect-VIServer $VIServer -User $VIUsername -Password $VIPassword -WarningAction SilentlyContinue

    $datastore = Get-Datastore -Server $viConnection -Name $VMDatastore | Select-Object -First 1
    $cluster = Get-Cluster -Server $viConnection -Name $VMCluster
    $datacenter = $cluster | Get-Datacenter
    $vmhost = $cluster | Get-VMHost | Select-Object -First 1
}

if($deployNestedESXiVMs -eq 1) {
    $NestedESXiHostnameToIPs.GetEnumerator() | Sort-Object -Property Value | Foreach-Object {
        $VMName = $_.Key
        $VMIPAddress = $_.Value

        $ovfconfig = Get-OvfConfiguration $NestedESXiApplianceOVA
        $networkMapLabel = ($ovfconfig.ToHashTable().keys | Where-Object {$_ -Match "NetworkMapping"}).replace("NetworkMapping.","").replace("-","_").replace(" ","_")
        $ovfconfig.NetworkMapping.$networkMapLabel.value = $VMNetwork1

        $ovfconfig.common.guestinfo.hostname.value = $VMName
        $ovfconfig.common.guestinfo.ipaddress.value = $VMIPAddress
        $ovfconfig.common.guestinfo.netmask.value = $VMNetmask
        $ovfconfig.common.guestinfo.gateway.value = $VMGateway
        $ovfconfig.common.guestinfo.dns.value = $VMDNS
        $ovfconfig.common.guestinfo.domain.value = $VMDomain
        $ovfconfig.common.guestinfo.ntp.value = $VMNTP
        $ovfconfig.common.guestinfo.password.value = $VMPassword
        if($VMSSH -eq "true") {
            $VMSSHVar = $true
        } else {
            $VMSSHVar = $false
        }
        $ovfconfig.common.guestinfo.ssh.value = $VMSSHVar

        My-Logger "Deploying Nested ESXi VM $VMName ..."
        $vm = Import-VApp -Source $NestedESXiApplianceOVA -OvfConfiguration $ovfconfig -Name $VMName -Location $cluster -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin

        My-Logger "Adding vmnic2/vmnic3/vmnic4/vmnic5/vmnic6/vmnic7 for `"$VMNetwork1`" and `"$VMNetwork2`" and `"$VMNetwork3`" and `"$VMNetwork4`" and `"$VMNetwork5`" and `"$VMNetwork5`" to passthrough to Nested ESXi VMs ..."
        New-NetworkAdapter -VM $vm -Type Vmxnet3 -NetworkName $VMNetwork1 -StartConnected -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        New-NetworkAdapter -VM $vm -Type Vmxnet3 -NetworkName $VMNetwork2 -StartConnected -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        New-NetworkAdapter -VM $vm -Type Vmxnet3 -NetworkName $VMNetwork3 -StartConnected -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        New-NetworkAdapter -VM $vm -Type Vmxnet3 -NetworkName $VMNetwork4 -StartConnected -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        New-NetworkAdapter -VM $vm -Type Vmxnet3 -NetworkName $VMNetwork5 -StartConnected -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        New-NetworkAdapter -VM $vm -Type Vmxnet3 -NetworkName $VMNetwork6 -StartConnected -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        $vm | New-AdvancedSetting -name "ethernet2.filter4.name" -value "dvfilter-maclearn" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile
        $vm | New-AdvancedSetting -Name "ethernet2.filter4.onFailure" -value "failOpen" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile

        $vm | New-AdvancedSetting -name "ethernet3.filter4.name" -value "dvfilter-maclearn" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile
        $vm | New-AdvancedSetting -Name "ethernet3.filter4.onFailure" -value "failOpen" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile

        $vm | New-AdvancedSetting -name "ethernet4.filter4.name" -value "dvfilter-maclearn" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile
        $vm | New-AdvancedSetting -Name "ethernet4.filter4.onFailure" -value "failOpen" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile

        $vm | New-AdvancedSetting -name "ethernet5.filter4.name" -value "dvfilter-maclearn" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile
        $vm | New-AdvancedSetting -Name "ethernet5.filter4.onFailure" -value "failOpen" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile

        $vm | New-AdvancedSetting -name "ethernet6.filter4.name" -value "dvfilter-maclearn" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile
        $vm | New-AdvancedSetting -Name "ethernet6.filter4.onFailure" -value "failOpen" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile

        $vm | New-AdvancedSetting -name "ethernet7.filter4.name" -value "dvfilter-maclearn" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile
        $vm | New-AdvancedSetting -Name "ethernet7.filter4.onFailure" -value "failOpen" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile

        My-Logger "Updating vCPU Count to $NestedESXivCPU & vMEM to $NestedESXivMEM GB ..."
        Set-VM -Server $viConnection -VM $vm -NumCpu $NestedESXivCPU -CoresPerSocket $NestedESXiCoresPerSocket -MemoryGB $NestedESXivMEM -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        My-Logger "Updating vSAN Cache VMDK size to $NestedESXiCachingvDisk GB & Capacity VMDK size to $NestedESXiCapacityvDisk GB ..."
        Get-HardDisk -Server $viConnection -VM $vm -Name "Hard disk 2" | Set-HardDisk -CapacityGB $NestedESXiCachingvDisk -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        Get-HardDisk -Server $viConnection -VM $vm -Name "Hard disk 3" | Set-HardDisk -CapacityGB $NestedESXiCapacityvDisk -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        My-Logger "Powering On $vmname ..."
        $vm | Start-Vm -RunAsync | Out-Null
    }
}

if($deployVCSA -eq 1) {
    if($IsWindows) {
        $config = (Get-Content -Raw "$($VCSAInstallerPath)\vcsa-cli-installer\templates\install\embedded_vCSA_on_VC.json") | convertfrom-json
    } else {
        $config = (Get-Content -Raw "$($VCSAInstallerPath)/vcsa-cli-installer/templates/install/embedded_vCSA_on_VC.json") | convertfrom-json
    }

    $config.'new_vcsa'.vc.hostname = $VIServer
    $config.'new_vcsa'.vc.username = $VIUsername
    $config.'new_vcsa'.vc.password = $VIPassword
    $config.'new_vcsa'.vc.deployment_network = $VMNetwork1
    $config.'new_vcsa'.vc.datastore = $datastore
    $config.'new_vcsa'.vc.datacenter = $datacenter.name
    $config.'new_vcsa'.vc.target = $VMCluster
    $config.'new_vcsa'.appliance.thin_disk_mode = $true
    $config.'new_vcsa'.appliance.deployment_option = $VCSADeploymentSize
    $config.'new_vcsa'.appliance.name = $VCSADisplayName
    $config.'new_vcsa'.network.ip_family = "ipv4"
    $config.'new_vcsa'.network.mode = "static"
    $config.'new_vcsa'.network.ip = $VCSAIPAddress
    $config.'new_vcsa'.network.dns_servers[0] = $VMDNS
    $config.'new_vcsa'.network.prefix = $VCSAPrefix
    $config.'new_vcsa'.network.gateway = $VMGateway
    $config.'new_vcsa'.os.ntp_servers = $VMNTP
    $config.'new_vcsa'.network.system_name = $VCSAHostname
    $config.'new_vcsa'.os.password = $VCSARootPassword
    if($VCSASSHEnable -eq "true") {
        $VCSASSHEnableVar = $true
    } else {
        $VCSASSHEnableVar = $false
    }
    $config.'new_vcsa'.os.ssh_enable = $VCSASSHEnableVar
    $config.'new_vcsa'.sso.password = $VCSASSOPassword
    $config.'new_vcsa'.sso.domain_name = $VCSASSODomainName

    if($IsWindows) {
        My-Logger "Creating VCSA JSON Configuration file for deployment ..."
        $config | ConvertTo-Json | Set-Content -Path "$($ENV:Temp)\jsontemplate.json"

        My-Logger "Deploying the VCSA (Windows) ..."
        Invoke-Expression "$($VCSAInstallerPath)\vcsa-cli-installer\win32\vcsa-deploy.exe install --no-esx-ssl-verify --no-ssl-certificate-verification --accept-eula --acknowledge-ceip $($ENV:Temp)\jsontemplate.json"| Out-File -Append -LiteralPath $verboseLogFile
    } elseif($IsMacOS) {
        My-Logger "Creating VCSA JSON Configuration file for deployment ..."
        $config | ConvertTo-Json | Set-Content -Path "$($ENV:TMPDIR)jsontemplate.json"

        My-Logger "Deploying the VCSA (Mac) ..."
        Invoke-Expression "$($VCSAInstallerPath)/vcsa-cli-installer/mac/vcsa-deploy install --no-esx-ssl-verify --no-ssl-certificate-verification --accept-eula --acknowledge-ceip $($ENV:TMPDIR)jsontemplate.json"| Out-File -Append -LiteralPath $verboseLogFile
    } elseif ($IsLinux) {
        My-Logger "Creating VCSA JSON Configuration file for deployment ..."
        $config | ConvertTo-Json | Set-Content -Path "/tmp/jsontemplate.json"

        My-Logger "Deploying the VCSA (Linux) ..."
        Invoke-Expression "$($VCSAInstallerPath)/vcsa-cli-installer/lin64/vcsa-deploy install --no-esx-ssl-verify --no-ssl-certificate-verification --accept-eula --acknowledge-ceip /tmp/jsontemplate.json"| Out-File -Append -LiteralPath $verboseLogFile
    }
}

if($moveVMsIntovApp -eq 1) {
    My-Logger "Creating vApp $VAppName ..."
    $VApp = New-VApp -Name $VAppName -Server $viConnection -Location $cluster

    if(-Not (Get-Folder $VMFolder -ErrorAction Ignore)) {
        My-Logger "Creating VM Folder $VMFolder ..."
        New-Folder -Name $VMFolder -Server $viConnection -Location (Get-Datacenter $VMDatacenter | Get-Folder vm)
    }

    if($deployNestedESXiVMs -eq 1) {
        My-Logger "Moving Nested ESXi VMs into $VAppName vApp ..."
        $NestedESXiHostnameToIPs.GetEnumerator() | Sort-Object -Property Value | Foreach-Object {
            $vm = Get-VM -Name $_.Key -Server $viConnection
            Move-VM -VM $vm -Server $viConnection -Destination $VApp -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        }
    }

    if($deployVCSA -eq 1) {
        $vcsaVM = Get-VM -Name $VCSADisplayName -Server $viConnection
        My-Logger "Moving $VCSADisplayName into $VAppName vApp ..."
        Move-VM -VM $vcsaVM -Server $viConnection -Destination $VApp -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
    }

    My-Logger "Moving $VAppName to VM Folder $VMFolder ..."
    Move-VApp -Server $viConnection $VAppName -Destination (Get-Folder -Server $viConnection $VMFolder) | Out-File -Append -LiteralPath $verboseLogFile
}

if( $deployNestedESXiVMs -eq 1 -or $deployVCSA -eq 1) {
    My-Logger "Disconnecting from $VIServer ..."
    Disconnect-VIServer -Server $viConnection -Confirm:$false
}

if($setupNewVC -eq 1) {
    My-Logger "Connecting to the new VCSA ..."
    $vc = Connect-VIServer $VCSAIPAddress -User "administrator@$VCSASSODomainName" -Password $VCSASSOPassword -WarningAction SilentlyContinue

    $d = Get-Datacenter -Server $vc $NewVCDatacenterName -ErrorAction Ignore
    if( -Not $d) {
        My-Logger "Creating Datacenter $NewVCDatacenterName ..."
        New-Datacenter -Server $vc -Name $NewVCDatacenterName -Location (Get-Folder -Type Datacenter -Server $vc) | Out-File -Append -LiteralPath $verboseLogFile
    }

    $c = Get-Cluster -Server $vc $NewVCVSANClusterName -ErrorAction Ignore
    if( -Not $c) {
        My-Logger "Creating VSAN Cluster $NewVCVSANClusterName ..."
        New-Cluster -Server $vc -Name $NewVCVSANClusterName -Location (Get-Datacenter -Name $NewVCDatacenterName -Server $vc) -DrsEnabled -HAEnabled -VsanEnabled | Out-File -Append -LiteralPath $verboseLogFile

        (Get-Cluster $NewVCVSANClusterName) | New-AdvancedSetting -Name "das.ignoreRedundantNetWarning" -Type ClusterHA -Value $true -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
    }

    if($addESXiHostsToVC -eq 1) {
        $NestedESXiHostnameToIPs.GetEnumerator() | Sort-Object -Property Value | Foreach-Object {
            $VMName = $_.Key
            $VMIPAddress = $_.Value

            $targetVMHost = $VMIPAddress
            if($addHostByDnsName -eq 1) {
                $targetVMHost = $VMName
            }
            My-Logger "Adding ESXi host $targetVMHost to Cluster ..."
            Add-VMHost -Server $vc -Location (Get-Cluster -Name $NewVCVSANClusterName) -User "root" -Password $VMPassword -Name $targetVMHost -Force | Out-File -Append -LiteralPath $verboseLogFile
        }

        $haRuntime = (Get-Cluster $NewVCVSANClusterName).ExtensionData.RetrieveDasAdvancedRuntimeInfo
        $totalHaHosts = $haRuntime.TotalHosts
        $totalHaGoodHosts = $haRuntime.TotalGoodHosts
        while($totalHaGoodHosts -ne $totalHaHosts) {
            My-Logger "Waiting for vSphere HA configuration to complete ..."
            Start-Sleep -Seconds 60
            $haRuntime = (Get-Cluster $NewVCVSANClusterName).ExtensionData.RetrieveDasAdvancedRuntimeInfo
            $totalHaHosts = $haRuntime.TotalHosts
            $totalHaGoodHosts = $haRuntime.TotalGoodHosts
        }
    }

    if($configureVSANDiskGroup -eq 1) {
        My-Logger "Enabling VSAN & disabling VSAN Health Check ..."

        Get-VsanClusterConfiguration -Server $vc -Cluster $NewVCVSANClusterName | Set-VsanClusterConfiguration -HealthCheckIntervalMinutes 0 | Out-File -Append -LiteralPath $verboseLogFile

        foreach ($vmhost in Get-Cluster -Server $vc | Get-VMHost) {
            $luns = $vmhost | Get-ScsiLun | Select-Object CanonicalName, CapacityGB

            My-Logger "Querying ESXi host disks to create VSAN Diskgroups ..."
            foreach ($lun in $luns) {
                if(([int]($lun.CapacityGB)).toString() -eq "$NestedESXiCachingvDisk") {
                    $vsanCacheDisk = $lun.CanonicalName
                }
                if(([int]($lun.CapacityGB)).toString() -eq "$NestedESXiCapacityvDisk") {
                    $vsanCapacityDisk = $lun.CanonicalName
                }
            }
            My-Logger "Creating VSAN DiskGroup for $vmhost ..."
            New-VsanDiskGroup -Server $vc -VMHost $vmhost -SsdCanonicalName $vsanCacheDisk -DataDiskCanonicalName $vsanCapacityDisk | Out-File -Append -LiteralPath $verboseLogFile
        }
    }

    if($configureVDS -eq 1) {
        # vmnic0 = VMNetwork1
        # vmnic1 = VMNetwork1 (unused)
        # vmnic2 = VMNetwork1 (uplink1)
        # vmnic3 = VMNetwork2 (uplink2)
        # vmnic4 = VMNetwork3 (uplink3)
        # vmnic5 = VMNetwork4 (uplink4)
        # vmnic6 = VMNetwork5 (uplink5)
        # vmnic7 = VMNetwork6 (uplink6)

        $vds = New-VDSwitch -Server $vc -Name $NewVCVDSName -Location (Get-Datacenter -Name $NewVCDatacenterName) -Mtu 1600 -NumUplinkPorts 6

        New-VDPortgroup -Server $vc -Name $Portgroup1 -Vds $vds | Out-File -Append -LiteralPath $verboseLogFile
        Get-VDPortgroup -Server $vc $Portgroup1 | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort @("dvUplink1") -UnusedUplinkPort @("dvUplink2", "dvUplink3", "dvUplink4", "dvUplink5", "dvUplink6") | Out-File -Append -LiteralPath $verboseLogFile

        New-VDPortgroup -Server $vc -Name $Portgroup2 -Vds $vds -NumPorts 256 | Out-File -Append -LiteralPath $verboseLogFile
        Get-VDPortgroup -Server $vc $Portgroup2 | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort @("dvUplink2") -UnusedUplinkPort @("dvUplink1", "dvUplink3", "dvUplink4", "dvUplink5", "dvUplink6") | Out-File -Append -LiteralPath $verboseLogFile

        New-VDPortgroup -Server $vc -Name $Portgroup3 -Vds $vds -NumPorts 256 | Out-File -Append -LiteralPath $verboseLogFile
        Get-VDPortgroup -Server $vc $Portgroup3 | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort @("dvUplink3") -UnusedUplinkPort @("dvUplink1", "dvUplink2", "dvUplink4", "dvUplink5", "dvUplink6") | Out-File -Append -LiteralPath $verboseLogFile

        New-VDPortgroup -Server $vc -Name $Portgroup4 -Vds $vds | Out-File -Append -LiteralPath $verboseLogFile
        Get-VDPortgroup -Server $vc $Portgroup4 | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort @("dvUplink4") -UnusedUplinkPort @("dvUplink1", "dvUplink2", "dvUplink3", "dvUplink5", "dvUplink6") | Out-File -Append -LiteralPath $verboseLogFile

        New-VDPortgroup -Server $vc -Name $Portgroup5 -Vds $vds | Out-File -Append -LiteralPath $verboseLogFile
        Get-VDPortgroup -Server $vc $Portgroup5 | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort @("dvUplink5") -UnusedUplinkPort @("dvUplink1", "dvUplink2", "dvUplink3", "dvUplink4", "dvUplink6") | Out-File -Append -LiteralPath $verboseLogFile

        New-VDPortgroup -Server $vc -Name $Portgroup6 -Vds $vds | Out-File -Append -LiteralPath $verboseLogFile
        Get-VDPortgroup -Server $vc $Portgroup6 | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort @("dvUplink6") -UnusedUplinkPort @("dvUplink1", "dvUplink2", "dvUplink3", "dvUplink4", "dvUplink5") | Out-File -Append -LiteralPath $verboseLogFile

        foreach ($vmhost in Get-Cluster -Server $vc | Get-VMHost) {
            My-Logger "Adding $vmhost to $NewVCVDSName"
            $vds | Add-VDSwitchVMHost -VMHost $vmhost | Out-Null

            $vmhostNetworkAdapter = Get-VMHost $vmhost | Get-VMHostNetworkAdapter -Physical -Name vmnic2,vmnic3,vmnic4,vmnic5,vmnic6,vmnic7
            $vds | Add-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $vmhostNetworkAdapter -Confirm:$false
        }
    }

    if($clearVSANHealthCheckAlarm -eq 1) {
        My-Logger "Clearing default VSAN Health Check Alarms, not applicable in Nested ESXi env ..."
        $alarmMgr = Get-View AlarmManager -Server $vc
        Get-Cluster -Server $vc | Where-Object {$_.ExtensionData.TriggeredAlarmState} | ForEach-Object {
            $cluster = $_
            $Cluster.ExtensionData.TriggeredAlarmState | ForEach-Object {
                $alarmMgr.AcknowledgeAlarm($_.Alarm,$cluster.ExtensionData.MoRef)
            }
        }
        $alarmSpec = New-Object VMware.Vim.AlarmFilterSpec
        $alarmMgr.ClearTriggeredAlarms($alarmSpec)
    }

    # Final configure and then exit maintanence mode in case patching was done earlier
    foreach ($vmhost in Get-Cluster -Server $vc | Get-VMHost) {
        # Disable Core Dump Warning
        Get-AdvancedSetting -Entity $vmhost -Name UserVars.SuppressCoredumpWarning | Set-AdvancedSetting -Value 1 -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        # Enable vMotion traffic
        $vmhost | Get-VMHostNetworkAdapter -VMKernel | Set-VMHostNetworkAdapter -VMotionEnabled $true -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        if($vmhost.ConnectionState -eq "Maintenance") {
            Set-VMHost -VMhost $vmhost -State Connected -RunAsync -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        }
    }

    if($setupTanzuStoragePolicy) {
        $datastoreName = "vsanDatastore"

        My-Logger "Creating Tanzu Storage Policies and attaching to $datastoreName ..."
        New-TagCategory -Server $vc -Name $StoragePolicyTagCategory -Cardinality single -EntityType Datastore | Out-File -Append -LiteralPath $verboseLogFile
        New-Tag -Server $vc -Name $StoragePolicyTagName -Category $StoragePolicyTagCategory | Out-File -Append -LiteralPath $verboseLogFile
        Get-Datastore -Server $vc -Name $datastoreName | New-TagAssignment -Server $vc -Tag $StoragePolicyTagName | Out-File -Append -LiteralPath $verboseLogFile
        New-SpbmStoragePolicy -Server $vc -Name $StoragePolicyName -AnyOfRuleSets (New-SpbmRuleSet -Name "tanzu-ruleset" -AllOfRules (New-SpbmRule -AnyOfTags (Get-Tag $StoragePolicyTagName))) | Out-File -Append -LiteralPath $verboseLogFile
    }

    if($setupAVIContentLibrary) {
        My-Logger "Creating Content Library for AVI"
        New-ContentLibrary -Server $vc -Name "AVI" -Description "AVI Content Library" -Datastore (Get-Datastore -Server $vc "vsanDatastore") | Out-File -Append -LiteralPath $verboseLogFile

        My-Logger "Uploading AVI OVA to the new Content Library ..."
        $AVIFile = Get-Item $NSXAdvLBOVA
        New-ContentLibraryItem -ContentLibrary (Get-ContentLibrary -Server $vc -Name "AVI") -Name $AVIFile.BaseName -Files $AVIFile.FullName | Out-File -Append -LiteralPath $verboseLogFile
    }

    My-Logger "Disconnecting from new VCSA ..."
    Disconnect-VIServer $vc -Confirm:$false
}

$EndTime = Get-Date
$duration = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes,2)

My-Logger "Nested vSphere and ESXi Lab Deployment Complete!"
My-Logger "StartTime: $StartTime"
My-Logger "  EndTime: $EndTime"
My-Logger " Duration: $duration minutes"
