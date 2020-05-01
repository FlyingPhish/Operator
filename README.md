## Start-Operator.ps1

A PowerShell script that checks certain settings and makes relevant changes to ensure authenticated Nessus scans run smoothly. This tool was created to combat issues mainly with conducting Cyber Essentials assessments.

Version 1.5 is the current version.

## Revert-Operator.ps1

A PowerShell script that checks the configuration of the machine before Start-Operator was run (using output created by that script) and reverts all configurations back to the original state, except for File and Printer Sharing as I haven't found an efficent and accurate way to automate it. The output created by Start-Operator makes it trivial to manually revert the firewall change due to the nicely 'grepped' FilePrinterRules.txt document.

Version 1.0 is the current version.

## Script Checks and Changes:

LocalAccountTokenFilterPolicy - Registry, RemoteRegistry - Service, WMI - Service and File and Printer Sharing - Firewall

## Upcoming Updates

Another script that will be used to quickly revert changed settings, and other general improvements. -DONE!

Not sure yet... Probably an accurate way to automate to revert the firewall change (file and printer sharing) as it's done manually at the moment.

## Advisory

All the scripts listed in this repository should only be used for authorized penetration testing and/or educational purposes. Any misuse of this software will not be the responsibility of the author or of any other collaborator. Use it on your own networks and/or systems with the network owner's permission. Furthermore, please use at your own risk as the author or any other collaborator are not responsible for any issues or trouble caused!
