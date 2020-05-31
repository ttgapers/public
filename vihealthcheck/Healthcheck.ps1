###########################################################################################
# Title:	VMware health check 
# Filename:	healtcheck.sp1       	
# Created by:	Ivo Beerens ivo@ivobeerens.nl			
# Date:		28-08-2008					
# Version       1.3						
###########################################################################################
# Description:	Scripts that checks the status of a VMware      
# enviroment on the following point:		
# - VMware ESX server Hardware and version	       	
# - VMware VC version				
# - Active Snapshots				
# - CDROMs connected to VMs			
# - Floppy drives connected to VMs		
# - Datastores and the free space available	
# - VM information such as VMware tools version,  
#   processor and memory limits					
# - Witch VMs have VMware timesync options not 	
#   enabled					
###########################################################################################
# Configuration:
#
#   Edit the powershell.ps1 file and edit the following variables:
#   $vcserver="localhost"
#   Enter the VC server, if you execute the script on the VC server you can use localhost
#   $filelocation="D:\temp\healthcheck.htm"
#   Specify the path where to store the HTML output
#   $enablemail="yes"
#   Enable (yes) or disable (no) to sent the script by e-mail
#   $smtpServer = "mail.ictivity.nl" 
#   Specify the SMTP server in your network
#   $mailfrom = "VMware Healtcheck <powershell@ivobeerens.nl>"
#   Specify the from field
#   $mailto = "ivo.beerens@ictivity.nl"
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
$vcserver="localhost"

##################
# Add VI-toolkit #
##################
Add-PSsnapin VMware.VimAutomation.Core
Initialize-VIToolkitEnvironment.ps1
connect-VIServer $vcserver

#############
# Variables #
#############
$filelocation="D:\temp\healthcheck.htm"
$vcversion = get-view serviceinstance
$snap = get-vm | get-snapshot
$date=get-date

##################
# Mail variables #
##################
$enablemail="yes"
$smtpServer = "mail.ivobeerens.nl" 
$mailfrom = "VMware Healtcheck <powershell@ivobeerens.nl>"
$mailto = "ivo@ivobeerens.nl"

#############################
# Add Text to the HTML file #
#############################
ConvertTo-Html –title "VMware Health Check " –body "<H1>VMware Health script</H1>" -head "<link rel='stylesheet' href='style.css' type='text/css' />" | Out-File $filelocation
ConvertTo-Html –title "VMware Health Check " –body "<H4>Date and time</H4>",$date -head "<link rel='stylesheet' href='style.css' type='text/css' />" | Out-File -Append $filelocation

#######################
# VMware ESX hardware #
#######################
Get-VMHost | Get-View | ForEach-Object { $_.Summary.Hardware } | Select-object Vendor, Model, MemorySize, CpuModel, CpuMhz, NumCpuPkgs, NumCpuCores, NumCpuThreads, NumNics, NumHBAs | ConvertTo-Html –title "VMware ESX server Hardware configuration" –body "<H2>VMware ESX server Hardware configuration.</H2>" -head "<link rel='stylesheet' href='style.css' type='text/css' />" | Out-File -Append $filelocation

#######################
# VMware ESX versions #
#######################
get-vmhost | % { $server = $_ |get-view; $server.Config.Product | select { $server.Name }, Version, Build, FullName }| ConvertTo-Html –title "VMware ESX server versions" –body "<H2>VMware ESX server versions and builds.</H2>" -head "<link rel='stylesheet' href='style.css' type='text/css' />" | Out-File -Append $filelocation

######################
# VMware VC version  #
######################
$vcversion.content.about | select Version, Build, FullName | ConvertTo-Html –title "VMware VirtualCenter version" –body "<H2>VMware VC version.</H2>" -head "<link rel='stylesheet' href='style.css' type='text/css' />" |Out-File -Append $filelocation

#############
# Snapshots # 
#############
$snap | select vm, name,created,description | ConvertTo-Html –title "Snaphots active" –body "<H2>Snapshots active.</H2>" -head "<link rel='stylesheet' href='style.css' type='text/css' />"| Out-File -Append $filelocation

#################################
# VMware CDROM connected to VMs # 
#################################
Get-vm | where { $_ | get-cddrive | where { $_.ConnectionState.Connected -eq "true" } } | Select Name | ConvertTo-Html –title "CDROMs connected" –body "<H2>CDROMs connected.</H2>" -head "<link rel='stylesheet' href='style.css' type='text/css' />"|Out-File -Append $filelocation

#########################################
# VMware floppy drives connected to VMs #
#########################################
Get-vm | where { $_ | get-floppydrive | where { $_.ConnectionState.Connected -eq "true" } } | select Name |ConvertTo-Html –title "Floppy drives connected" –body "<H2>Floppy drives connected.</H2>" -head "<link rel='stylesheet' href='style.css' type='text/css' />" |Out-File -Append $filelocation

#########################
# Datastore information #
#########################

function UsedSpace
{
	param($ds)
	[math]::Round(($ds.CapacityMB - $ds.FreeSpaceMB)/1024,2)
}

function FreeSpace
{
	param($ds)
	[math]::Round($ds.FreeSpaceMB/1024,2)
}

function PercFree
{
	param($ds)
	[math]::Round((100 * $ds.FreeSpaceMB / $ds.CapacityMB),0)
}

$Datastores = Get-Datastore
$myCol = @()
ForEach ($Datastore in $Datastores)
{
	$myObj = "" | Select-Object Datastore, UsedGB, FreeGB, PercFree
	$myObj.Datastore = $Datastore.Name
	$myObj.UsedGB = UsedSpace $Datastore
	$myObj.FreeGB = FreeSpace $Datastore
	$myObj.PercFree = PercFree $Datastore
	$myCol += $myObj
}
$myCol | Sort-Object PercFree | ConvertTo-Html –title "Datastore space " –body "<H2>Datastore space available.</H2>" -head "<link rel='stylesheet' href='style.css' type='text/css' />" | Out-File -Append $filelocation

# Invoke-Item $filelocation

##################
# VM information #
##################
$Report = @()
 
get-vm | % {
  $vm = Get-View $_.ID
    $vms = "" | Select-Object VMName, Hostname, IPAddress, VMState, TotalCPU, TotalMemory, MemoryUsage, TotalNics, ToolsStatus, ToolsVersion, MemoryLimit, MemoryReservation, CPUreservation, CPUlimit
    $vms.VMName = $vm.Name
    $vms.HostName = $vm.guest.hostname
    $vms.IPAddress = $vm.guest.ipAddress
    $vms.VMState = $vm.summary.runtime.powerState
    $vms.TotalCPU = $vm.summary.config.numcpu
    $vms.TotalMemory = $vm.summary.config.memorysizemb
    $vms.MemoryUsage = $vm.summary.quickStats.guestMemoryUsage
    $vms.TotalNics = $vm.summary.config.numEthernetCards
    $vms.ToolsStatus = $vm.guest.toolsstatus
    $vms.ToolsVersion = $vm.config.tools.toolsversion
    $vms.MemoryLimit = $vm.resourceconfig.memoryallocation.limit
    $vms.MemoryReservation = $vm.resourceconfig.memoryallocation.reservation
    $vms.CPUreservation = $vm.resourceconfig.cpuallocation.reservation
    $vms.CPUlimit = $vm.resourceconfig.cpuallocation.limit
    $Report += $vms
}
$Report | ConvertTo-Html –title "Virtual Machine information" –body "<H2>Virtual Machine information.</H2>" -head "<link rel='stylesheet' href='style.css' type='text/css' />" | Out-File -Append $filelocation


###############################
# VMware Timesync not enabled #
###############################

Get-VM | Get-View | ? { $_.Config.Tools.syncTimeWithHost -eq $false } | Select Name | Sort-object Name | ConvertTo-Html –title "VMware timesync not enabled" –body "<H2>VMware timesync not enabled.</H2>" -head "<link rel='stylesheet' href='style.css' type='text/css' />" | Out-File -Append $filelocation

######################
# E-mail HTML output #
######################
if ($enablemail -match "yes") 
{ 
$msg = new-object Net.Mail.MailMessage
$att = new-object Net.Mail.Attachment($filelocation)
$smtp = new-object Net.Mail.SmtpClient($smtpServer) 
$msg.From = $mailfrom
$msg.To.Add($mailto) 
$msg.Subject = “VMware Healthscript”
$msg.Body = “VMware healthscript”
$msg.Attachments.Add($att) 
$smtp.Send($msg)
}

##############################
# Disconnect session from VC #
##############################

disconnect-viserver -confirm:$false

##########################
# End Of Healthcheck.ps1 #
##########################



