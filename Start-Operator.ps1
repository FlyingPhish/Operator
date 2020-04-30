<#
Description:
A simple script that grabs the current configuration for RemoteReg and WMI services, firewall profiles + rules and UAC (specifically the LocalAccountTokenFilterPolicy reg key). 
then uses that info to change the settings to how Nessus requires them for problem free authenticated scans. Use Revert-Operator to change everything to it's orignal state.

Change History:
Version 1.0 - 15th April 2020
Version 1.5 - 30th April 2020 (CURRENT VERSION) - Comes with code improvements, especially with the output of file and printer sharing firewall rules

Author:
By FlyingPhish
#>

#ASCI ART
$t = @"

   ____                             __              
  / __ \ ____   ___   _____ ____ _ / /_ ____   _____
 / / / // __ \ / _ \ / ___// __ `// __// __ \ / ___/
/ /_/ // /_/ //  __// /   / /_/ // /_ / /_/ // /    
\____// .___/ \___//_/    \__,_/ \__/ \____//_/     
     /_/                                            


"@
 
for ($i=0;$i -lt $t.length;$i++) {
    if ($i%2) {
    $c = "green"
    }
   elseif ($i%5) {
   $c = "green"
   }
   elseif ($i%7) {
   $c = "green"
   }
   else {
   $c = "green"
   }
   write-host $t[$i] -NoNewline -ForegroundColor $c 
}

#CHECK IF ADMIN
Write-Host "`nChecking user permissions:"
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
   [Security.Principal.WindowsBuiltInRole] "Administrator")) {
   Write-Warning "Not running with administrator permissions. Please run this script as admin."
   Break
   } else {
   Write-Host "Script exectued with correct permissions`n" -ForegroundColor Green
}


#VARIABLES
$UserPath = "$($env:USERPROFILE)\Desktop"
$ErrorActionPreference = "Stop"

#CREATING SCAFFOLDING
Write-Output "Creating new folder $UserPath\FF_Operator that will contain all results of queries before we modify settings!"

If (-NOT(Test-Path $UserPath\FF_Operator)) {
   New-Item -Path $UserPath -Name FF_Operator -ItemType "directory" | Out-Null
   Write-Host "Folder successfully created" -ForegroundColor Green
   } else {
   Remove-Item $UserPath\FF_Operator -Recurse -Force | Out-Null
   New-Item -Path $UserPath -Name FF_Operator -ItemType "directory" | Out-Null
   Write-Host "Old folder has successfully being overwritten" -ForegroundColor Green
}


#GET CURRENT STATE OF FACTORS
Write-Output "`nChecking services:"
Get-Service RemoteRegistry | Select-Object Name, Status, StartType -OutVariable RemoteRegSrv | Out-Null 
Get-Service Winmgmt | Select-Object Name, Status, StartType -OutVariable WMISrv | Out-Null 
$RemoteRegSrv
$WMISrv

#ADDING TO FILE
$RemoteRegSrv | Out-File $UserPath\FF_Operator\RemoteRegistry.txt
$WMISrv | Out-File $UserPath\FF_Operator\WMI.txt


Write-Output "`nChecking for registry key:"
If ((Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System).LocalAccountTokenFilterPolicy -ne 1) {
   New-Item -Path $UserPath\FF_Operator\ -Name "UAC.txt" -ItemType "file" | Out-Null
   Add-Content -Path $UserPath\FF_Operator\UAC.txt -Value 0 -Force
   Write-Output "LATFP key does not exist"
} else {
   New-Item -Path $UserPath\FF_Operator\ -Name "UAC.txt" -ItemType "file" | Out-Null
   Add-Content -Path $UserPath\FF_Operator\UAC.txt -Value 1 -Force
   Write-Output "LATFP key exists"
}


Write-Output "`nChecking firewall profiles:"
$FirewallStatus = netsh advfirewall show allprofiles | findstr /i "Settings State"
$FirewallStatus
$FirewallStatus | Out-File $UserPath\FF_Operator\FirewallStatus.txt


Write-Output "`nChecking firewall rules:"
$FirewallRules = netsh advfirewall firewall show rule name=all

Write-Output "Writing all firewall rules to $UserPath\FF_Operator\FirewallRules.txt"
$FirewallRules | Out-File $UserPath\FF_Operator\FirewallRules.txt

Write-Output "Writing rules specfic to File and Printer sharing to $UserPath\FF_Operator\FilePrinterRules.txt"
$FirewallFilePrinter = Get-NetFirewallRule -Group "@FirewallAPI.dll,-28502" | Select-Object -Property Name,Enabled,Direction | Out-File $UserPath\FF_Operator\FilePrinterRules.txt


#STARTING SERVICES, MODIFYING FIREWALL AND REGISTRY
Write-Output "`nMAKING CHANGES!"

Write-Output "`nAdding TokenFilterPolicy if needed"

If ((Get-Content -Path $UserPath\FF_Operator\UAC.txt) -eq 0) {
   Write-Output "Implementing key..."
   REG add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f | Out-Null
   Write-Output "Successfully added!"
   } elseif ((Get-Content -Path $UserPath\FF_Operator\UAC.txt) -eq 1) {
   Write-Output "Key exists - carrying on"
}


Write-Output "`nAllowing File and Printer Sharing"
Write-Output "Will implement change even if the firewall is disabled"
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes

Write-Output "`nStarting WMI service:"
If (Select-String -Path $UserPath\FF_Operator\WMI.txt -Pattern "Disabled") {
   Write-Output "Enabling and starting service as it's disabled"
   Set-Service -Name Winmgmt -StartupType Automatic
   Start-Sleep -seconds 20
   Start-Service -Name Winmgmt
   Start-Sleep -seconds 20
   } elseif ((Select-String -Pattern "running" -Path $UserPath\FF_Operator\WMI.txt) -Like "*Running*")  {
   Write-Output "Service already running"
   } elseif ((Select-String -Pattern "stopped" -Path $UserPath\FF_Operator\WMI.txt) -Like "*Stopped*"){
   Write-Output "Starting service as not running"
   Start-Service -Name Winmgmt
   Start-Sleep -seconds 20
}

Write-Output "Starting Remote Registry service:"
If (Select-String -Path $UserPath\FF_Operator\RemoteRegistry.txt -Pattern "Disabled") {
   Write-Output "Enabling and starting service as it's disabled`n"
   Set-Service -Name RemoteRegistry -StartupType Automatic
   Start-Sleep -seconds 20
   Start-Service -Name RemoteRegistry
   Start-Sleep -seconds 5
   } elseif ((Select-String -Pattern "running" -Path $UserPath\FF_Operator\RemoteRegistry.txt) -Like "*Running*") {
   Write-Output "Service already running"
   } elseif ((Select-String -Pattern "stopped" -Path $UserPath\FF_Operator\RemoteRegistry.txt) -Like "*Stopped*") {
   Write-Output "Starting service as not running"
   Start-Service -Name RemoteRegistry
   Start-Sleep -Seconds 20
}


#END OF SCRIPT
Write-Output "`nScript completed!"