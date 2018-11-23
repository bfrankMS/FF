#region Variables
   $RG = "AzureFun"
   $Location = "NorthEurope"
   $VNETName = "VNET"
   $NSGName = "myNSG"
   $AVSetName = "myAVSet"
   $VMName = "myVMName"
   $PublicIPAddressName = "myPIP"
   $NICName = "myNICName"
   $OSDiskCaching = "ReadWrite"
   $DataDiskCaching = "ReadOnly"
   $OSDiskName = "myOSDisk"
   $DataDiskName = "myDataDisk"
   $Premium_LRS = @{"P4"=32 ; "P6"=64 ; "P10"=128 ; "P20"=512 ; "P30"=1024 ; "P40"=2048 ; "P50"=4095; "P60"=8192; "P70"=16384; "P80"=32767}    #https://docs.microsoft.com/en-us/azure/virtual-machines/windows/premium-storage#premium-storage-disk-limits
   $Standard_LRS = @{"S4"=32 ; "S6"=64 ; "S10"=128 ; "S20"=512 ; "S30"=1024 ; "S40"=2048 ; "S50"=4095; "S60"=8192; "S70"=16384; "S80"=32767}    #https://docs.microsoft.com/en-us/azure/virtual-machines/windows/premium-storage#premium-storage-disk-limits
   $StandardSSD_LRS = @{"E10"=128 ; "E20"=512 ; "E30"=1024 ; "E40"=2048 ; "E50"=4095; "E60"=8192; "E70"=16384; "E80"=32767}  #https://docs.microsoft.com/en-us/azure/virtual-machines/windows/disks-standard-ssd
#endregion

#login to Azure
Login-AzAccount -Environment AzureCloud

#select the right subscription
#Select-AzSubscription -Subscription 'SubscriptionName'

#Create the Resource Group
New-AzResourceGroup -Name $RG -Location $Location

#Create Subnet
$Subnets = @()
$Subnets += New-AzVirtualNetworkSubnetConfig -Name "SubNet1" -AddressPrefix "192.168.1.0/24"
$Subnets += New-AzVirtualNetworkSubnetConfig -Name "SubNet2" -AddressPrefix "192.168.2.0/24"

#Create VNET
$VNET = New-AzVirtualNetwork -Name $VNETName -ResourceGroupName $RG -Location $Location -Subnet $Subnets -AddressPrefix "192.168.0.0/16"

#Create a Subnet after VNET was created
$Subnet3 = New-AzVirtualNetworkSubnetConfig -Name "SubNet3" -AddressPrefix "192.168.3.0/24"
$VNET = Get-AzVirtualNetwork -Name $VNETName -ResourceGroupName $RG
$VNET.Subnets.Add($Subnet3)
Set-AzVirtualNetwork -VirtualNetwork $VNET

#Create a Network Security Group
$NSGRules = @()
$NSGRules += New-AzNetworkSecurityRuleConfig -Name "RDP" -Priority 101 -Description "inbound RDP access" -Protocol Tcp -SourcePortRange * -SourceAddressPrefix * -DestinationPortRange 3389 -DestinationAddressPrefix * -Access Allow -Direction Inbound 
$NSG = New-AzNetworkSecurityGroup -Name $NSGName -ResourceGroupName $RG -Location $Location -SecurityRules $NSGRules

#Create PublicIP
$PIP = New-AzPublicIpAddress -Name $PublicIPAddressName -ResourceGroupName $RG -Location $Location -AllocationMethod Dynamic

#Create NIC
$NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $RG -Location $Location -SubnetId $VNET.Subnets.Item(0).id -PublicIpAddressId $PIP.Id

#Create VM (Size,additional Data Disk (ReadCache of Data Disk), )

    #Create Availabilityset
    $AVSet = New-AzAvailabilitySet -ResourceGroupName $RG -Name $AVSetName -Location $Location -PlatformUpdateDomainCount 1 -PlatformFaultDomainCount 1 -Sku Aligned
    
    #Get VMSize
    $VMSize = Get-AzVMSize -Location $Location | Out-GridView -PassThru -Title "Select Your Size"
    $VM = New-AzVMConfig -VMName $VMName -VMSize $VMSize.Name -AvailabilitySetId $AVSet.Id
    
    #Attach VNIC to VMConfig
    $VM = Add-AzVMNetworkInterface -VM $VM -Id $NIC.Id

    #Get the image e.g. "MicrosoftSQLServer" Offer: "SQL2017-WS2016"
    $Publisher = "MicrosoftWindowsServer" #  (Get-AzVMImagePublisher -Location $location |  Out-GridView -PassThru).PublisherName 
    $PublisherOffer = Get-AzVMImageOffer -Location $Location -PublisherName $Publisher | where Offer -EQ "WindowsServer" #Get-AzVMImageOffer -Location $Location -PublisherName $Publisher | Out-GridView -PassThru
    
    $VMImageSKU = (Get-AzVMImageSku -Location $Location -PublisherName $PublisherOffer.PublisherName -Offer $PublisherOffer.Offer).Skus | Out-GridView -PassThru
    #select latest version
    $VMImage = Get-AzVMImage -Location $Location -PublisherName $PublisherOffer.PublisherName -Offer $PublisherOffer.Offer -Skus $VMImageSKU | Sort-Object version -Descending | Select-Object -First 1
    $VM= Set-AzVMSourceImage -VM $VM -PublisherName $PublisherOffer.PublisherName -Offer $PublisherOffer.Offer -Skus $VMImageSKU -Verbose -Version $VMImage.Version

    #Disable Boot Diagnostics for VM    (is demo - don't need it AND it would require storage account which I don't want to provision)
    $VM =  Set-AzVMBootDiagnostics -VM $VM -Disable 

    #Create a Credential
    $Credential = Get-Credential -Message 'Your VM Credentials Please!'
    #Don't hardcode!
    #$VMLocalAdminUser = "LocalAdminUser"
    #$VMLocalAdminSecurePassword = ConvertTo-SecureString "V3ryStrongPwd!" -AsPlainText -Force 
    #$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword)
    $VM = Set-AzVMOperatingSystem -VM $VM -Windows -ComputerName $VMName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
    
    #Config OSDisk
    $VM = Set-AzVMOSDisk -VM $VM -Name $OSDiskName -Caching $OSDiskCaching -CreateOption FromImage -DiskSizeInGB 128

    #attach DataDisk
    #$DataDiskConfig = New-AzDiskConfig -SkuName Premium_LRS -DiskSizeGB $Premium_LRS.P20 -Location $location -CreateOption Empty 
    $DataDiskConfig = New-AzDiskConfig -SkuName StandardSSD_LRS -DiskSizeGB $StandardSSD_LRS.E10 -Location $location -CreateOption Empty 
    $DataDisk = New-AzDisk -ResourceGroupName $RG -DiskName $DataDiskName -Disk $DataDiskConfig 
    $VM = Add-AzVMDataDisk -VM $vm -Name $DataDiskName -Caching $DataDiskCaching -ManagedDiskId $DataDisk.Id -Lun 1 -CreateOption Attach

    #new VM
    New-AzVM -ResourceGroupName $RG -Location $location -VM $VM -Verbose # -AsJob   #-AsJob immediately runs the job in the background -> get-job


#Read-Host 'Clean up Resourcegroup ?'
#Remove-AzResourceGroup -Name $RG -AsJob -Force