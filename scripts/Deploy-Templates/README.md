# Deploy-Templates.ps1

Deploy-Templates.ps1 is a script to take a user-chosen .ova and deploy the .ova to several vCenters

## Installation

The following modules are required: 
    VMware.VimAutomation.Core 
    VMware.PowerCLI

## Usage

PWSH (to initialize Powershell if on UNIX)

./Deploy-Templates.ps1

''' Required inputs from user

1. Log file location (e.g. /Users/Username/Documents/log.log)

2. OVA directory (e.g. /Users/Username/Documents/OVA/) -- No filenames here. It will scan through the directory and display each file for selection

3. vCenter username

4. vCenter password

5. Minimum required host hardware version for template (the script will do several checks before attempting an upload. If there is no host with the specified version or above along with a standard switch, a limitation of the PowerCLI module in uploading VMs, the vCenter will be added to an array displayed upon exiting the script)

6. Target .ova from a list of current files in the artifactory-synced directory on the FTP server

7. Desired template name (e.g. al86-v04 for an Alma Linux version 4 template). This name will be appended to the provider name upon upload (e.g. cdptpabb04-s-vcsa01-al86-v04 in the example above). If you do not want the provider name included, adjust the $vmName variable.

8. List of vCenters (a simple flat file with the FWDN of the vCenter on each line will work)

9. Name of standard datastore for the script to look for. In our system, we have a specific datastore in each vCenter where we load templates. These datastores all have the same string in the name and the script will look for that string in the Get-Datastore command. If it cannot find a datastore with a name like the input on this step, it will skip that vCenter. 

The script then begins uploading the ova to each vCenter. Any failure to do so will be logged. 

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate.
