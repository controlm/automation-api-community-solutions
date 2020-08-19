#
# Use a model of two Virtual machines to build an FY21 Demo Environment
#	- Windows machine contains Control-M stack (EM, Server, Agent)
#	- Linux machine contains Control-M agent, MFT and MFT Enterprise
# Depending on command-line arguments, new snapshots are taken of the model environment
# or existing snapshots are used. The process is:
#	- Create a Resource Group
#	- Create a Storage Account
#	- Take snapshots of the two model machines, unless -skipSnapShot is specified, in which case
#	  snapshots are assumed to already exist. 
#	- Create various resources required for the Virtual Machines
#	- Use snapshots to create managed OS Disks
#	- Create Virtual Machines

# Arguments:
#	OID							Mandatory: Intended for Control-M OrderID but can be any string to make a new Resource Group unique
#	t|tenantId 					Mandatory: Azure Tenant-ID
#
#	cf|credsFile				Fully-qualified path to a text file containing service principal and client secret, on seperate lines
#								If this parameter is not provided, a prompt is issued for the credentials.
#
#	rg|rgOriginalName			Source Resource Group containing the VMs used as base template images
#								Default:	FY21DemoSetup
#
#	cn|ctmOriginalName			VM Name of original Control-M machine with EM, Server and agent
#								Default:	FY21CTMServer
#
#   an|agOriginalName 			VM name of the original agent machine used as a template
#								Default:	FY21agent
#
#   newrg						New Resource Group PREFIX (OID appended) in which the new resources will be deployed
#								Default:	FY21DemoSetup
#
#   sSS|skipSnapShot			Skip generating new SnapShots of the OS Disks and use existing ones
#
#	nCtm|ctmNewName				Name of the new VM for Control-M "servers" machine
#								Default:	FY21CTMSCopy
#
#	nctmOSD|ctmNewOSDisk		Name of new OS Disk for Control-M "servers" machine
#								Default:	'FY21CTMSDemoCopy_OS_Disk',
#
#	ctmSname|ctmSnapShotName	Snapshot name of Control-M "servers" machine 
#								Default:	FY21CTMS_Snapshot
#
#	ctmPip|ctmPublicIP 			Public IP Address for Control-M "servers" machine 
#								Default:	FY21CTMSDemoCopy_IP
#
#	agPip|agPublicIP 			Public IP Address for Control-M "agent" machine
#								Default:	FY21AGDemoCopy_IP	
#
#	nAgN|agNewName 				Name of new VM for Control-M agent 
#								Default:	FY21AGCopy
#
#	nAgOSD|agNewOSDisk 			Name of new OS Disk for Control-M agent machine
#								Default:	FY21AGDemoCopy_OS_Disk
#
#	agSname|agSnapShotName		Snapshot name of Control-M "agent" machine 
#								Default:	FY21AG_Snapshot
#
#	ctmNsg 						Server Network Security Group
#								Default:	FY21CTMSDemoCopy_Nsg
#
#	ctmSubnet 					Control-M server machine Subnet
#								Default:	FY21CTMSDemoCopy_SubNet
#
#	ctmNIC 						Network Interface
#								Default:	FY21CTMSDemoCopy_NicName
#
#	agSubnet 					Control-M agent machine subnet
#								Default:	FY21AGDemoCopy_SubNet
#
#	agNsg 						Agent Security group
#								Default:	FY21AGDemoCopy_Nsg
#
#	agNIC 						Agent Network Interface
#								Default:	FY21AGDemoCopy_NicName

param(
    [Parameter(Mandatory=$true)][String]$OID,
	[Parameter(Mandatory=$false)][Alias("tnt")][String]$tenantId = '92b796c5-5839-40a6-8dd9-c1fad320c69b',	
	[Parameter(Mandatory=$false)][Alias("cf")][String]$credsFile = '.\azcreds.txt',
    [Parameter(Mandatory=$false)][Alias("rg")][String]$rgOriginalName = 'FY21DemoSetup',
   	[Parameter(Mandatory=$false)][Alias("cn")][String]$ctmOriginalName = 'FY21CTMServer',
    [Parameter(Mandatory=$false)][Alias("an")][String]$agOriginalName = 'FY21agent',
    [Parameter(Mandatory=$false)][Alias("newrg")][String]$destRgBase = 'FY21DemoSetup',
    [Parameter(Mandatory=$false)][Alias("sSS")][Switch]$skipSnapShot,
	[Parameter(Mandatory=$false)][Alias("nCtm")][String]$ctmNewName = "FY21CTMSCopy",
	[Parameter(Mandatory=$false)][Alias("nctmOSD")][String]$ctmNewOSDisk = 'FY21CTMSDemoCopy_OS_Disk',
	[Parameter(Mandatory=$false)][Alias("ctmSname")][String]$ctmSnapShotName = 'FY21CTMS_Snapshot',
	[Parameter(Mandatory=$false)][Alias("ctmPip")][String]$ctmPublicIP = "FY21CTMSDemoCopy_IP",
	[Parameter(Mandatory=$false)][Alias("agPip")][String]$agPublicIP = "FY21AGDemoCopy_IP",	
	[Parameter(Mandatory=$false)][Alias("nAgN")][String]$agNewName = "FY21AGCopy",
	[Parameter(Mandatory=$false)][Alias("nAgOSD")][String]$agNewOSDisk = 'FY21AGDemoCopy_OS_Disk',
	[Parameter(Mandatory=$false)][Alias("agSname")][String]$agSnapShotName = 'FY21AG_Snapshot',
	[Parameter(Mandatory=$false)][String]$ctmNsg = "FY21CTMSDemoCopy_Nsg",
	[Parameter(Mandatory=$false)][String]$ctmSubnet = 'FY21CTMSDemoCopy_SubNet',
	[Parameter(Mandatory=$false)][String]$ctmNIC = "FY21CTMSDemoCopy_NicName",
	[Parameter(Mandatory=$false)][String]$agSubnet = 'FY21AGDemoCopy_SubNet',
	[Parameter(Mandatory=$false)][String]$agNsg = "FY21AGDemoCopy_Nsg",
	[Parameter(Mandatory=$false)][String]$agNIC = "FY21AGDemoCopy_NicName"
)
function Get-Credentials 
{
	if ($credsFile -eq '') {
		$userName = Read-Host "Enter App Registration (Service Principal)"
		$securepswd = Read-Host "Enter Client Secret" -AsSecureString
		$password = ConvertFrom-SecureString -SecureString $securepswd -AsPlainText
	}
	else {
		try {
			$credsInFile = Get-Content -Path $credsFile -TotalCount 2
		}
		catch {
			"Some error occurred"
			$_.Exception.Message
			exit
		}
		$userName = $credsInFile[0]
		$password = $credsInFile[1]
	}
	
	$creds = @($userName, $password)
	return $creds
}

# Original and Common values
$location = 'westus2'

$stgAcctName = "fy21demostg" + $OID.ToLower()
$vnetName = "FY21DemoCopy_Vnet_" + $OID
$destinationResourceGroup = $destRgBase + "_" + $OID

$ctmCreds = Get-Credentials	
$servicePrincipal = $ctmCreds[0]
$password = ConvertTo-SecureString $ctmCreds[1] -AsPlainText -Force
$pscredential = New-Object System.Management.Automation.PSCredential ($servicePrincipal, $password)
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId

# Suppress change warnings
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

# Set the correct Subscription Context
#Set-AzContext -SubscriptionId fee1b749-2ef4-4205-a1a5-3fdb5b803697

if(-Not $skipSnapShot.IsPresent) #Use existing Snapshot
    {
        Remove-AzSnapshot -Force -ResourceGroupName $rgOriginalName -SnapShotName $ctmSnapShotName
        Remove-AzSnapshot -Force -ResourceGroupName $rgOriginalName -SnapShotName $agSnapShotName

        # Get the Server VM Object
        $ctmvm = Get-AzVM -Name $ctmOriginalName `
            -ResourceGroupName $rgOriginalName

        # Get the OS Disk Name
        $disk = Get-AzDisk -ResourceGroupName $rgOriginalName `
            -DiskName $ctmvm.StorageProfile.OsDisk.Name

        # Create Snapshot Configuration
        $snapshotConfig =  New-AzSnapshotConfig `
            -SourceUri $disk.Id `
            -OsType Windows `
            -CreateOption Copy `
            -Location $location

        # Take the Snapshot
        $ctmSnapShot = New-AzSnapshot `
            -Snapshot $snapshotConfig `
            -SnapshotName $ctmSnapShotName `
            -ResourceGroupName $rgOriginalName
        $ctmSnapShotId = $ctmSnapShot.Id

        # Get the Agent VM Object
        $agvm = Get-AzVM -Name $agOriginalName `
            -ResourceGroupName $rgOriginalName

        # Get the OS Disk Name
        $agdisk = Get-AzDisk -ResourceGroupName $rgOriginalName `
            -DiskName $agvm.StorageProfile.OsDisk.Name

        # Create Snapshot Configuration
        $agsnapshotConfig =  New-AzSnapshotConfig `
            -SourceUri $agdisk.Id `
            -OsType Linux `
            -CreateOption Copy `
            -Location $location

        # Take the Snapshot
        $agSnapShot = New-AzSnapshot `
            -Snapshot $agsnapshotConfig `
            -SnapshotName $agSnapShotName `
            -ResourceGroupName $rgOriginalName
        $agSnapShotId = $agSnapShot.Id
    }
else 
    {
        $ctmSnapShotInfo = Get-AzSnapshot -ResourceGroupName $rgOriginalName `
            -SnapShotName $ctmSnapShotName
        $ctmSnapShotId = $ctmSnapShotInfo.Id
        $agSnapShotInfo = Get-AzSnapshot -ResourceGroupName $rgOriginalName `
            -SnapShotName $agSnapShotName
        $agSnapShotId = $agSnapShotInfo.Id

}

#
# Create a new Resource Group
New-AzResourceGroup -Location $location -Name $destinationResourceGroup

# Create Storage Account  
$stgacct = New-AzStorageAccount -ResourceGroupName $destinationResourceGroup `
  -Name $stgAcctName `
  -Location $location `
  -SkuName Standard_RAGRS `
  -Kind StorageV2

#-----------------------------------------+
# Create Managed Disk  for Server Machine |
#-----------------------------------------+
$osDisk = New-AzDisk -DiskName $ctmNewOSDisk -Disk `
    (New-AzDiskConfig  -Location $location -CreateOption Copy `
	-SourceResourceId $ctmSnapShotId) `
    -ResourceGroupName $destinationResourceGroup

# Create virtual subnet
$singleSubnet = New-AzVirtualNetworkSubnetConfig `
   -Name $ctmSubnet `
   -AddressPrefix 10.0.0.0/24

# Create Virtual Network
$vnet = New-AzVirtualNetwork `
   -Name $vnetName -ResourceGroupName $destinationResourceGroup `
   -Location $location `
   -AddressPrefix 10.0.0.0/16 `
   -Subnet $singleSubnet

# Create Network Security Group and allow RDP
$rdpRule = New-AzNetworkSecurityRuleConfig -Name myRdpRule -Description "Allow RDP" `
    -Access Allow -Protocol Tcp -Direction Inbound -Priority 110 `
    -SourceAddressPrefix Internet -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 3389

$nsg = New-AzNetworkSecurityGroup `
   -ResourceGroupName $destinationResourceGroup `
   -Location $location `
   -Name $ctmNsg -SecurityRules $rdpRule

# Create Public IP
$pip = New-AzPublicIpAddress `
   -Name $ctmPublicIP -ResourceGroupName $destinationResourceGroup `
   -Location $location `
   -AllocationMethod Dynamic

# Create a NIC
$nic = New-AzNetworkInterface -Name $ctmNIC `
   -ResourceGroupName $destinationResourceGroup `
   -Location $location -SubnetId $vnet.Subnets[0].Id `
   -PublicIpAddressId $pip.Id `
   -NetworkSecurityGroupId $nsg.Id

# Set VM Name and size
$vmConfig = New-AzVMConfig -VMName $ctmNewName -VMSize "Standard_D4_v3"
# Add the NIC
$ctmvm = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

# Add the OS Disk
$ctmvm = Set-AzVMOSDisk -VM $ctmvm -ManagedDiskId $osDisk.Id -StorageAccountType Standard_LRS `
    -DiskSizeInGB 256 -CreateOption Attach -Windows

# Complete the VM
$newCTM = New-AzVM -ResourceGroupName $destinationResourceGroup -Location $location -VM $ctmvm
$newCTM

#---------------------------------------+
# Create Managed Disk for Agent Machine |
#---------------------------------------+
$agOsDisk = New-AzDisk -DiskName $agNewOSDisk -Disk `
    (New-AzDiskConfig  -Location $location -CreateOption Copy `
	-SourceResourceId $agSnapShotId) `
    -ResourceGroupName $destinationResourceGroup

# Create virtual subnet
$singleSubnet = New-AzVirtualNetworkSubnetConfig `
   -Name $agSubnet `
   -AddressPrefix 10.0.0.0/24

# Create Network Security Group and allow SSH
$sshRule = New-AzNetworkSecurityRuleConfig -Name myRdpRule -Description "Allow SSH" `
    -Access Allow -Protocol Tcp -Direction Inbound -Priority 110 `
    -SourceAddressPrefix Internet -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 22

$nsg = New-AzNetworkSecurityGroup `
   -ResourceGroupName $destinationResourceGroup `
   -Location $location `
   -Name $agNsg -SecurityRules $sshRule

# Create Public IP
$pip = New-AzPublicIpAddress `
   -Name $agPublicIP -ResourceGroupName $destinationResourceGroup `
   -Location $location `
   -AllocationMethod Dynamic

# Create a NIC
$nic = New-AzNetworkInterface -Name $agNIC `
   -ResourceGroupName $destinationResourceGroup `
   -Location $location -SubnetId $vnet.Subnets[0].Id `
   -PublicIpAddressId $pip.Id `
   -NetworkSecurityGroupId $nsg.Id

# Set VM Name and size
$vmConfig = New-AzVMConfig -VMName $agNewName -VMSize "Standard_D2_v3"
# Add the NIC
$agvm = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

# Add the OS Disk
$agvm = Set-AzVMOSDisk -VM $agvm -ManagedDiskId $agOsDisk.Id -StorageAccountType Standard_LRS `
    -DiskSizeInGB 30 -CreateOption Attach -Linux

# Complete the VM
$newAgent = New-AzVM -ResourceGroupName $destinationResourceGroup -Location $location -VM $agvm
$newAgent