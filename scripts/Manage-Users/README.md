# Manage-VCenterAccount.ps1

Manage-VCenterAccount.ps1 is a script containing the following modules:

    Create vCenter User Account (on several vCenters)
    Delete vCenter User Account (on several vCenters)
    Enable vCenter User Account (on several vCenters)
    Disable vCenter User Account (on several vCenters)
    Change ESXi Host Credentials
    Rotate vCenter Administrator Credential
    View List of Target VCenters

## Installation

The following modules are required:
    VMware.VimAutomation.Core 
    VMware.PowerCLI


## Usage

PWSH (to initialize Powershell if on UNIX)

./Manage-VCenterAccount.ps1

''' Required inputs from user

1. Location and filename of log file (e.g. /Users/Username/Documents/log.log)

2. vCenter username

3. vCenter password

4. File containing list of vCenters (a flat file with the FQDN of each vCenter per line works)

5. Choice of module

The script then begins running the chosen module and will gather more information from the user if required. Script will log to the location and file presented to the user.

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate.