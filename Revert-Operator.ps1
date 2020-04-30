<#
Description:
A simple script to revert changes made by Start-Operator to the original state before the script was ran.

Change History:
Version 1.0 - 30th April 2020 (CURRENT VERSION) - Reverts everything back to normal, except for firewall rules as there isn't an accurate way I've discovered (yet).
Please use the FilePrinterRules.txt document to easily revert firewall changes. 

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
$NewRevertFolder = "$($env:USERPROFILE)\Desktop\FF_Operator"
$RevertUserPath = "$($env:USERPROFILE)\Desktop\FF_Operator\Revert"

#CREATING SCAFFOLDING
Write-Output "Creating new folder $RevertUserPath that will contain a list of results from after running Start-Operator."

If (-NOT(Test-Path $RevertUserPath)) {
   New-Item -Path $NewRevertFolder -Name Revert -ItemType "directory" | Out-Null
   Write-Host "Folder successfully created" -ForegroundColor Green
   } else {
   Remove-Item $RevertUserPath -Recurse -Force | Out-Null
   New-Item -Path $NewRevertFolder -Name Revert -ItemType "directory" | Out-Null
   Write-Host "Old folder has successfully being overwritten" -ForegroundColor Green
}

#GET CURRENT STATE OF FACTORS
Write-Output "`nChecking services:"
Get-Service RemoteRegistry | Select-Object Name, Status, StartType -OutVariable RemoteRegSrv | Out-Null 
Get-Service Winmgmt | Select-Object Name, Status, StartType -OutVariable WMISrv | Out-Null 
$RemoteRegSrv
$WMISrv

#ADDING TO FILE
$RemoteRegSrv | Out-File $RevertUserPath\Afer-StartOperator-RemoteRegistry.txt
$WMISrv | Out-File $RevertUserPath\Afer-StartOperator-WMI.txt


Write-Output "`nChecking for registry key:"
If ((Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System).LocalAccountTokenFilterPolicy -ne 1) {
   New-Item -Path $RevertUserPath -Name "Afer-StartOperator-UAC.txt" -ItemType "file" | Out-Null
   Add-Content -Path $RevertUserPath\Afer-StartOperator-UAC.txt -Value 0 -Force
   Write-Output "LATFP key does not exist - strange"
} else {
   New-Item -Path $RevertUserPath -Name "Afer-StartOperator-UAC.txt" -ItemType "file"  | Out-Null
   Add-Content -Path $RevertUserPath\Afer-StartOperator-UAC.txt -Value 1 -Force
   Write-Output "LATFP key exists - expected"
}


Write-Output "`nChecking firewall profiles:"
$FirewallStatus = netsh advfirewall show allprofiles | findstr /i "Settings State"
$FirewallStatus
$FirewallStatus | Out-File $RevertUserPath\After-StartOperator-FirewallStatus.txt


Write-Output "`nChecking for File and Printer Sharing:"
Write-Output "Writing all firewall rules to $RevertUserPath\After-StartOperator-FirewallRules.txt"
$FirewallRules = netsh advfirewall firewall show rule name=all
$FirewallRules | Out-File $RevertUserPath\After-StartOperator-FirewallRules.txt

Write-Output "`nWriting rules specfic to File and Printer sharing to $RevertUserPath\After-StartOperator-FilePrinterRules.txt"
$FirewallFilePrinter = Get-NetFirewallRule -Group "@FirewallAPI.dll,-28502" | Select-Object -Property Name,Enabled,Direction | Out-File $RevertUserPath\After-StartOperator-FilePrinterRules.txt 


#STARTING SERVICES, MODIFYING FIREWALL AND REGISTRY
Write-Output "`nREVERTING CHANGES!"

Write-Output "`nReverting TokenFilterPolicy if needed"

If ((Get-Content -Path $UserPath\FF_Operator\UAC.txt) -eq 0) {
   Write-Output "Removing key..."
   REG add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 0 /f | Out-Null
   Write-Output "Successfully removed!"
   } elseif ((Get-Content -Path $UserPath\FF_Operator\UAC.txt) -eq 1) {
   Write-Output "Key already existed. Will not revert"
}


Write-Output "`nManual intervention is required for firewall rules. Please see the $NewRevertFolder\FilePrinterRules.txt document for FPS rules before Operator made changes."


Write-Output "`nReverting Remote Registry service:"
If (Select-String -Path $UserPath\FF_Operator\RemoteRegistry.txt -Pattern "Disabled") {
   Write-Output "Disabling service as it was disabled`n"
   Set-Service -Name RemoteRegistry -StartupType Disabled
   Start-Sleep -seconds 20
   Stop-Service -Name RemoteRegistry
   Start-Sleep -seconds 20
   } elseif (Select-String -Path $UserPath\FF_Operator\RemoteRegistry.txt -Pattern "Automatic") {
    Write-Output "Setting service to automatic as it was before`n"
    Set-Service -Name RemoteRegistry -StartupType Automatic
   } elseif (Select-String -Path $UserPath\FF_Operator\RemoteRegistry.txt -Pattern "AutomaticDelayedStart") {
    Write-Output "Setting service to delayed automatic as it was before`n"
    Set-Service -Name RemoteRegistry -StartupType AutomaticDelayedStart
}

Write-Output "Reverting WMI service:"
If (Select-String -Path $UserPath\FF_Operator\WMI.txt -Pattern "Disabled") {
   Write-Output "Disabling service as it was disabled`n"
   Set-Service -Name Winmgmt -StartupType Disabled
   Start-Sleep -seconds 20
   Stop-Service -Name Winmgmt
   Start-Sleep -seconds 20
   } elseif (Select-String -Path $UserPath\FF_Operator\WMI.txt -Pattern "Automatic") {
    Write-Output "Setting service to automatic as it was before`n"
    Set-Service -Name Winmgmt -StartupType Automatic
   } elseif (Select-String -Path $UserPath\FF_Operator\WMI.txt -Pattern "AutomaticDelayedStart") {
    Write-Output "Setting service to delayed automatic as it was before`n"
    Set-Service -Name Winmgmt -StartupType AutomaticDelayedStart
}

#END OF SCRIPT
Write-Output "`nScript completed!"
