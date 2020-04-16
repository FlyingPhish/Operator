<#
A simple script that will check for certain services, firewall rules and reg edits that are needed for a smooth authenticated Nessus Scan. Will save all results into a folder to easily revert settings.

Version 1.0 - 15th April 2020..
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


#CREATING SCAFFOLDING
Write-Output "Creating new folder $UserPath\FF_Operator that will contain all results"

If (-NOT(Test-Path $UserPath\FF_Operator)) {
   New-Item -Path $UserPath -Name FF_Operator -ItemType "directory" | Out-Null
   } else {
   Remove-Item $UserPath\FF_Operator -Recurse -Force | Out-Null
   New-Item -Path $UserPath -Name FF_Operator -ItemType "directory" | Out-Null
}


#GET CURRENT STATE OF FACTORS
Write-Host "`nChecking services:"
Get-Service RemoteRegistry | Select-Object Name, Status, StartType -OutVariable RemoteRegSrv | Out-Null 
Get-Service Winmgmt | Select-Object Name, Status, StartType -OutVariable WMISrv | Out-Null 
$RemoteRegSrv
$WMISrv
#ADDING TO FILE
$RemoteRegSrv | Out-File $UserPath\FF_Operator\RemoteRegistry.txt
$WMISrv | Out-File $UserPath\FF_Operator\WMI.txt


Write-Output "`nChecking for registry key:"
If ((Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System).LocalAccountTokenFilterPolicy -ne 1) {
   Write-Output "LATFP key does not exist"
   New-Item -Path $UserPath\FF_Operator\ -Name "UAC.txt" -ItemType "file" | Out-Null
   Add-Content -Path $UserPath\FF_Operator\UAC.txt -Value 0 -Force
} else {
   Write-Output "LATFP key exists"
   New-Item -Path $UserPath\FF_Operator\ -Name "UAC.txt" -ItemType "file" | Out-Null
   Add-Content -Path $UserPath\FF_Operator\UAC.txt -Value 1 -Force
}


Write-Output "`nChecking firewall profiles:"
$FirewallStatus = netsh advfirewall show allprofiles | findstr /i "Settings State"
$FirewallStatus
$FirewallStatus | Out-File $UserPath\FF_Operator\FirewallStatus.txt


Write-Output "`nChecking for File and Printer Sharing:"
$FirewallRules = netsh advfirewall firewall show rule name=all
Write-Output "Writing firewall rules to $UserPath\FF_Operator\FirewallRules.txt"
$FirewallRules | Out-File $UserPath\FF_Operator\FirewallRules.txt


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
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes


Write-Output "`nStarting Remote Registry service:"
If (Select-String -Path $UserPath\FF_Operator\RemoteRegistry.txt -Pattern "Disabled") {
   Write-Output "Enabling service as it's disabled`n"
   Set-Service -Name RemoteRegistry -StartupType Automatic
   Start-Sleep -seconds 20
   Start-Service -Name RemoteRegistry
   Start-Sleep -seconds 20
   } else {
   Write-Output "Starting service (if not started)"
   Start-Service -Name RemoteRegistry
   Start-Sleep -seconds 20
} 

Write-Output "`nStarting WMI service:"
If (Select-String -Path $UserPath\FF_Operator\WMI.txt -Pattern "Disabled") {
   Write-Output "Enabling service as it's disabled"
   Set-Service -Name Winmgmt -StartupType Automatic
   Start-Sleep -seconds 20
   Start-Service -Name Winmgmt
   Start-Sleep -seconds 20
   } else {
   Write-Output "Starting service (if not started)"
   Start-Service -Name Winmgmt
   Start-Sleep -seconds 20
} 


Write-Output "`nChecking services"
Get-Service RemoteRegistry
Get-Service Winmgmt

Write-Output "`nScript completed!"

