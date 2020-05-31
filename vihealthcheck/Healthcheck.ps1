###########################################################################################
# Title:	VMware health check 
# Filename:	healthcheck.ps1      	
# Created by:	Ivo Beerens 			
# Date:		Januari 2008				
# Version:   	2.2			
# Website:	www.ivobeerens.nl
# E-mail:	ivo@ivobeerens.nl
# Modified by: Jason Singh
# Date: August 12, 2009
# Website: www.ttgapers.com
# Added:
# - Stylesheet settings to body so email can be sent HTML formatted
# - Removed style references in every table addition
# - Avge Daily and Memory Usage to VM Statistics (Thanks Ade Orimalade)
# - NTP Servers (Thanks esarakaitis at www.vmwarescripting.com)
# - Verify NTP Client running (Thanks esarakaitis at www.vmwarescripting.com)
# - Service Console IPs (Thanks esarakaitis at www.vmwarescripting.com)
# - List Virtual Switches (Thanks esarakaitis at www.vmwarescripting.com)
# - List Virtual Switches Port Groups and Security (Thanks esarakaitis at www.vmwarescripting.com)
# - Change Time Sync to see ENABLED guests since we sync with AD
# - Added html file to body of email (Thanks Bill Scott)
###########################################################################################
# Description:	Scripts that checks the status of a VMware      
# enviroment on the following point:		
# - VMware ESX server Hardware and version	       	
# - VMware vCenter version				
# - Cluster information
# - VMware statistics
# - Active Snapshots				
# - CDROMs connected to VMs			
# - Floppy drives connected to VMs		
# - Datastores Information such as free space 
# - RDM information	
# - VM information such as VMware tools version,  
#   processor and memory limits					
# - VM's and their datastore
# - VMware timesync enabled 	
#   enabled
# - Percentage disk space used inside the VM
# - VC error logs last 5 days					
###########################################################################################
# Configuration:
#
#   Edit the powershell.ps1 file and edit the following variables:
#   $vcserver="localhost"
#   Enter the VC server, if you execute the script on the VC server you can use localhost
#   $portvc="443"
#   Edit the port if the default port is changed
#   $filelocation="c:\healthcheck.htm"
#   Specify the path where to store the HTML output
#   $enablemail="yes"
#   Enable (yes) or disable (no) to sent the script by e-mail
#   $smtpServer = "mail.ictivity.nl" 
#   Specify the SMTP server in your network
#   $mailfrom = "VMware Healtcheck <powershell@ivobeerens.nl>"
#   Specify the from field
#   $mailto = "ivo@ivobeerens.nl"
#   Specify the e-mail address
###########################################################################################
# Usage:
#
#   Manually run the healthcheck.ps1 script":
#   1. Open Powershell
#   2. Browse to the directory where the healthcheck.ps1 script resides
#   3. enter the command:
#   ./healthcheck.ps1
#
#   To create a schedule task in for example Windows 2003 use the following 
#   syntax in the run property:
#   powershell -command "& 'path\healthcheck.ps1'
#   edit the path 
###########################################################################################

####################################
# VMware VirtualCenter server name #
####################################
$vcserver="vcFQDN" 
$portvc="443"

##################
# Add VI-toolkit #
##################
Add-PSsnapin VMware.VimAutomation.Core
Initialize-VIToolkitEnvironment.ps1
connect-VIServer $vcserver -port $portvc

#############
# Variables #
#############
$date=get-date
$filelocation="C:\Temp\healthcheck.htm" 
$vcversion = get-view serviceinstance
$snap = get-vm | get-snapshot
$ErrorActionPreference = "SilentlyContinue"

##################
# Mail variables #
##################
$enablemail="yes"
$smtpServer = "mail.domain.com" 
$mailfrom = "VMware Healtcheck <vi@domain.com>"
$mailto = "jsingh@domain.com"

#############################
# Add Text to the HTML file #
#############################
ConvertTo-Html -title "VMware Health Check " -body "<H1>VMware Health script</H1>" -head "<style>body { background-color:#EEEEEE; }
body,table,td,th { font-family:Tahoma; color:Black; Font-Size:10pt }
th { font-weight:bold; background-color:#CCCCCC; }
td { background-color:white; }</style>" | Out-File $filelocation
ConvertTo-Html -title "VMware Health Check " -body "<H4>By Jason Singh</H4>" | Out-File -Append $filelocation
ConvertTo-Html -title "VMware Health Check " -body "<H4>Date and time</H4>",$date | Out-File -Append $filelocation

#######################
# VMware ESX hardware #
#######################
Get-VMHost | Get-View | ForEach-Object { $_.Summary.Hardware } | Select-object Vendor, Model, MemorySize, CpuModel, CpuMhz, NumCpuPkgs, NumCpuCores, NumCpuThreads, NumNics, NumHBAs | ConvertTo-Html -title "VMware ESX server Hardware configuration" -body "<H2>VMware ESX server Hardware configuration.</H2>" | Out-File -Append $filelocation

#######################
# VMware ESX NTP      #
#######################
Get-VMHost | Sort Name | Select Name, @{N=?NTP?;E={Get-VMHostNtpServer $_}} | ConvertTo-Html -title "VMware ESX NTP Servers" -body "<H2>VMware ESX NTP Servers.</H2>" | Out-File -Append $filelocation

#######################
# Verify NTP Client   #
#######################
$ntprun = @()
foreach ($vmhost in get-vmhost) {
$fw = $vmhost | get-VMHostFirewallException | where {$_.name -eq "NTP Client" -and $_.Enabled -eq "true" -and $_.ServiceRunning -eq "true"}
$row = "" | select  @{Name = "Host"; Expression = {$vmhost.name}}, @{Name = "NTP Running ports"; Expression = {$fw.name}}
$ntprun +=$row
}
$ntprun | ConvertTo-Html -title "Verify NTP Client Running" -body "<H2>Verify NTP Client Running.</H2>" | Out-File -Append $filelocation

#######################
# VMware ESX SC IPs   #
#######################
Get-VMHost | Select Name, @{N=?ConsoleIP?;E={(Get-VMHostNetwork $_).ConsoleNic | ForEach{$_.IP}}} | ConvertTo-Html -title "VMware ESX Service Console IPs" -body "<H2>VMware ESX Service Console IPs.</H2>" | Out-File -Append $filelocation

#######################
# Virtual Switches    #
#######################
get-vmhost | foreach-object `
{$vmhost=$_
(get-view $_.id).config.network.vswitch | `
	select  @{name="Hostname"; expression={$vmhost.name}}, 
            @{name="VSwitch"; expression={$_.name}},
            @{name="VMnic"; expression={$_.pnic}},
            @{name="Total Ports"; expression={$_.numPorts}},
            @{name="Ports Available"; expression={$_.numPortsAvailable}},
            @{name="MTU"; expression={$_.mtu}}} | ConvertTo-Html -title "Hosts Virtual Switches" -body "<H2>Hosts Virtual Switches</H2>" | Out-File -Append $filelocation

########################
# Port Groups Security #
########################
$pgsec = @()
foreach ($vmhost in get-vmhost){
    $hostview = Get-View $vmhost.ID
	$portgroups = $hostview.Config.network.portgroup
    foreach ($portgroup in $portgroups)
    {
		$row =  "" | select @{Name="Host"; Expression={$vmhost.Name}}, 
                              @{Name="PortGroup Name"; Expression={$portgroup.spec.Name}},
                              @{Name="VSwitch Name"; Expression={$portgroup.spec.vswitchname}},
                              @{Name="Accept Promiscuous Mode"; Expression={$portgroup.computedpolicy.security.allowpromiscuous}},
                              @{Name="Accept Mac Changes"; Expression={$portgroup.computedpolicy.security.MacChanges}},
                              @{Name="Accept Forged Transmits"; Expression={$portgroup.computedpolicy.security.ForgedTransmits}}
$pgsec += $row
    }
} 
$pgsec | ConvertTo-Html -title "Virtual Switches Port Group Security" -body "<H2>Virtual Switches Port Group Security</H2>" | Out-File -Append $filelocation

######################
# VMware VC version  #
######################
$vcversion.content.about | select Version, Build, FullName | ConvertTo-Html -title "VMware vCenter version" -body "<H2>VMware vCenter version.</H2>" |Out-File -Append $filelocation

##############################
# VMware Cluster information #
##############################
$clusters = Get-Cluster | Sort Name

ForEach ($cluster in $clusters)
{
	$vmhosts = Get-VMHost -Location $cluster
	
	ForEach ($VMhostView in ($vmhosts | Get-View))
	{
		$TotalHostMemory += $vmhostView.Hardware.MemorySize
	}

	$vmhosts | Sort Name -Descending | % { $server = $_ |get-view; $server.Config.Product | select { $server.Name }, Version, Build, FullName }| ConvertTo-Html -body "<H2>$cluster Cluster Information.</H2>" | Out-File -Append $filelocation
	
	$NumHosts = ($vmhosts | Measure-Object).Count 
	
	$vms = Get-VM -Location $cluster | Where {$_.PowerState -eq "PoweredOn"}
	$NumVMs = $vms.Length
	$TotalRAM_GB = [math]::Round($TotalHostMemory/1GB,$digits)
	
	$TotalVMMemoryMB = $vms | Measure-Object -Property MemoryMB -Sum
	$AssignedRAM_GB = [math]::Round($TotalVMMemoryMB.Sum/1024,$digits)
	$PercentageUsed = [math]::Round((($TotalVMMemoryMB.Sum/1024)/($TotalHostMemory/1GB))*100)		
	
	ConvertTo-Html -body " $NumHosts host(s) running $NumVMs virtual machines" | Out-File -Append $filelocation
	ConvertTo-Html -body "Total memory resource = $TotalRAM_GB GB"  | Out-File -Append $filelocation
	ConvertTo-Html -body "Total Amount of assigned memory = $AssignedRAM_GB GB"  | Out-File -Append $filelocation
	ConvertTo-Html -body "Memory resource percenatge allocated = $PercentageUsed %"  | Out-File -Append $filelocation
	
	Clear-Variable vmhosts -ErrorAction SilentlyContinue
	Clear-Variable vms -ErrorAction SilentlyContinue
	Clear-Variable NumVMs -ErrorAction SilentlyContinue
	Clear-Variable TotalHostMemory -ErrorAction SilentlyContinue
	Clear-Variable TotalVMMemoryMB -ErrorAction SilentlyContinue
}


#######################
# Statistics          #
#######################
ConvertTo-Html -title "VMware statistics" -body "<H2>VMware statistics</H2>" | Out-File -append $filelocation
Get-VMHost | Measure-Object | Select Count | ConvertTo-Html -title "Number of VMware Hosts" -body "<H4>Number of VMware Hosts.</H4>" | Out-File -Append $filelocation
Get-VM | Measure-Object | Select Count | ConvertTo-Html -title "Number of VMs" -body "<H4>Number of VMs.</H4>" | Out-File -Append $filelocation
Get-Cluster | Measure-Object | Select Count | ConvertTo-Html -title "Number of VMware Clusters" -body "<H4>Number of VMware Clusters.</H4>" | Out-File -Append $filelocation
Get-Datastore | Measure-Object | Select Count | ConvertTo-Html -title "Number of Datastores" -body "<H4>Number of Datastores.</H4>" | Out-File -Append $filelocation

#############
# Snapshots # 
#############
$snap | select vm, name,created,description | ConvertTo-Html -title "Snaphots active" -body "<H2>Snapshots active.</H2>" | Out-File -Append $filelocation

#################################
# VMware CDROM connected to VMs # 
#################################
Get-vm | where { $_ | get-cddrive | where { $_.ConnectionState.Connected -eq "true" } } | Select Name | ConvertTo-Html -title "CDROMs connected" -body "<H2>CDROMs connected.</H2>" | Out-File -Append $filelocation

#########################################
# VMware floppy drives connected to VMs #
#########################################
Get-vm | where { $_ | get-floppydrive | where { $_.ConnectionState.Connected -eq "true" } } | select Name |ConvertTo-Html -title "Floppy drives connected" -body "<H2>Floppy drives connected.</H2>" |Out-File -Append $filelocation

########################################################
# Get all datastores and put them in alphabetical order#
########################################################
function Get-DSDevice($dsImpl)
{
		$ds = Get-View -Id $dsImpl.Id
		$esx = Get-View $ds.Host[0].Key
		$hss = Get-View $esx.ConfigManager.StorageSystem

		foreach($mount in $hss.FileSystemVolumeInfo.MountInfo){
		    if($mount.volume.name -eq $ds.Info.Name){
			switch($mount.Volume.Type){
			"VMFS" {
				foreach($ext in $mount.Volume.Extent){
					if($mount.volume.name -eq $ds.Info.Name){
						$device =$ext.DiskName
					}
				}
			  }
			"NFS" {
			    $device = $mount.Volume.RemoteHost + ":" + $mount.Volume.RemotePath
			  }
			}
		  }
		}
	$device
}

$datastores = get-vmhost  | Get-Datastore | Sort-Object Name
$myColCurrent = @()

foreach ($store in $datastores){
	$myObj = "" | Select-Object Name, CapacityGB, UsedGB, PercFree, Type, ID, Accessible
	$myObj.Name = $store.Name
	$myObj.CapacityGB = "{0:n2}" -f ($store.capacityMB/1kb)
	$myObj.UsedGB = "{0:N2}" -f (($store.CapacityMB - $store.FreeSpaceMB)/1kb)
	$myObj.PercFree = "{0:N}" -f (100 * $store.FreeSpaceMB/$store.CapacityMB)
	$myObj.Type = $store.Type
	$temp = Get-View -Id $store.Id
	$myObj.ID = Get-DSDevice $store
	$myObj.Accessible = $store.Accessible
	$myColCurrent += $myObj
}


# Export the output
$myColCurrent | ConvertTo-Html -title "Datastore Information" -body "<H2>Datastore Information.</H2>" | Out-File -Append $filelocation

############################
#RDM informattion          #
############################
$report = @()
$vms = Get-VM  | Get-View
foreach($vm in $vms){
  foreach($dev in $vm.Config.Hardware.Device){
    if(($dev.gettype()).Name -eq "VirtualDisk"){
	  if(($dev.Backing.CompatibilityMode -eq "physicalMode") -or 
	     ($dev.Backing.CompatibilityMode -eq "virtualMode")){
	    $row = "" | select VMName, HDDeviceName, HDFileName, HDMode, HDsize
          $row.VMName = $vm.Name
	    $row.HDDeviceName = $dev.Backing.DeviceName
	    $row.HDFileName = $dev.Backing.FileName
	    $row.HDMode = $dev.Backing.CompatibilityMode
           $row.HDSize = $dev.CapacityInKB
	    $report += $row
	  }
	}
  }
}

$report | ConvertTo-Html -title "RDM information" -body "<H2>RDM information.</H2>" | Out-File -Append $filelocation


#####################################
# VMware Virtual Machine statistics #
#####################################

function VM-statavg ($vmImpl, $StatStart, $StatFinish, $statId) {
	$stats = $vmImpl | get-stat -Stat $statId -intervalmin 120 -Maxsamples 360 `
							    -Start $StatStart -Finish $StatFinish
	$statAvg = "{0,9:#.00}" -f ($stats | Measure-Object value -average).average
	$statAvg
}
# Report for previous day
$DaysBack = 1 	# Number of days to go back
$DaysPeriod = 1 # Number of days in the interval
$DayStart = (Get-Date).Date.adddays(- $DaysBack)
$DayFinish = (Get-Date).Date.adddays(- $DaysBack + $DaysPeriod).addminutes(-1)
# Report for previous week
$DaysBack = 7 # Number of days to go back
$DaysPeriod = 7 # Number of days in the interval
$WeekStart = (Get-Date).Date.adddays(- $DaysBack)
$WeekFinish = (Get-Date).Date.adddays(- $DaysBack + $DaysPeriod).addminutes(-1)
$report = @()
get-vm | Sort Name | % {
  $vm = Get-View $_.ID
    $vms = "" | Select-Object VMName, Hostname, DayAvgCpuUsage, WeekAvgCpuUsage, VMState, TotalCPU, TotalMemory, DayAvgMemUsage, WeekAvgMemUsage, TotalNics, ToolsStatus, ToolsVersion
    $vms.VMName = $vm.Name
    $vms.HostName = $vm.guest.hostname
    $vms.DayAvgCpuUsage = VM-statavg $_ $DayStart $DayFinish "cpu.usage.average"
    $vms.WeekAvgCpuUsage = VM-statavg $_ $WeekStart $WeekFinish "cpu.usage.average"
    $vms.VMState = $vm.summary.runtime.powerState
    $vms.TotalCPU = $vm.summary.config.numcpu
    $vms.TotalMemory = $vm.summary.config.memorysizemb
    $vms.DayAvgMemUsage = VM-statavg $_ $DayStart $DayFinish "mem.usage.average"
    $vms.WeekAvgMemUsage = VM-statavg $_ $WeekStart $WeekFinish "mem.usage.average"
    $vms.TotalNics = $vm.summary.config.numEthernetCards
    $vms.ToolsStatus = $vm.guest.toolsstatus
    $vms.ToolsVersion = $vm.config.tools.toolsversion
    $Report += $vms
}

$Report | ConvertTo-Html -title "VMware Virtual Machine statistics" -body "<H2>VMware Virtual Machine statistics.</H2>" | Out-File -Append $filelocation


###############################
# VMware VMs, datastore view  #
###############################

$report = @()
$virtualmachines = Get-VM
foreach ($vm in $virtualmachines) {
	$dstores = $vm | Get-Datastore
	foreach($ds in $dstores){
		$row = "" | select VMname, datastore
		$row.VMname = $vm.name
		$row.datastore = $ds.Name
		$report += $row
	}
}$report | ConvertTo-Html -title "VMware VMs and there datastore" -body "<H2>VMware VMs and their datastore.</H2>" | Out-File -Append $filelocation



###############################
# VMware Timesync IS enabled #
###############################

Get-VM | Get-View | ? { $_.Config.Tools.syncTimeWithHost -eq $true } | Select Name | Sort-object Name | ConvertTo-Html -title "VMware timesync not enabled" -body "<H2>VMware timesync is enabled.</H2>" | Out-File -Append $filelocation

##################################################
# Percentage freespace on partitions in the VM   #
##################################################
Get-VM | Where { $_.PowerState -eq "PoweredOn" } | Get-VMGuest | Select VmName -ExpandProperty Disks | Select VmName, Path, @{ N="PercFree"; E={ [math]::Round( ( 100 * ( $_.FreeSpace / $_.Capacity ) ),0 ) } } | Sort PercFree | ConvertTo-Html -title " Percentage freespace partitions inside the VM" -body "<H2> Percentage freespace on partitions inside the VM.</H2>" | Out-File -Append $filelocation


###############################
# Errors the last 24 hours   #
###############################
# Get-VIEvent -Start (Get-Date).AddHours(-120) -Type Error | Format-Table CreatedTime, FullFormattedMessage -AutoSize | ConvertTo-Html -title "Errors the last five days" -body "<H2>Errors the last 5 days.</H2>" | Out-File -Append $filelocation
Get-VIEvent -Start (Get-Date).AddHours(-120) -Type Error | Select-object CreatedTime, FullFormattedMessage | ConvertTo-Html -title "Errors the last five days" -body "<H2>Errors the last 5 days.</H2>" | Out-File -Append $filelocation
 

######################
# E-mail HTML output #
######################
if ($enablemail -match "yes") 
{ 
$msg = new-object Net.Mail.MailMessage
$filelocationContent = Get-Content $filelocation
$att = new-object Net.Mail.Attachment($filelocation)
$smtp = new-object Net.Mail.SmtpClient($smtpServer) 
$msg.From = $mailfrom
$msg.To.Add($mailto) 
$msg.Subject = "VMware Healthscript"
$msg.Body = $filelocationContent #VMware healthscript: See Attachment
$msg.Attachments.Add($att)
$msg.IsBodyHTML = $true 
$smtp.Send($msg)
}

##############################
# Disconnect session from VC #
##############################

disconnect-viserver -confirm:$false

##########################
# End Of Healthcheck.ps1 #
##########################