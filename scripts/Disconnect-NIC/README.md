# Disconnect-NIC.ps1

Disconnect-NIC.ps1 is a script that 

## Installation

The following modules are required:
    Import-Module VMware.PowerCLI
    Import-Module VMware.VimAutomation.Core

## Usage

PWSH (to initialize Powershell if on UNIX)

./Disconnect-NIC.ps1

''' Required inputs from user

1. Target vCenter

2. vCenter password

3. vCenter password

4. Location and filename of log file (e.g. /Users/Username/Documents/log.log)

5. List of target VMs in .csv format

6. User choice of StartConnected property value

7. User choice to export results to a .csv

8. User choice to power off VMs 

The script will go through the VMs listed in the .csv (skipping a VM if it cannot locate it in the target vCenter), disconnect the NIC, and set the other properties (StartConnected and PowerState) as directed. 

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate.