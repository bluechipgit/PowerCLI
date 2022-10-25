# Name: Deploy-Templates.ps1
# Author: github.com/bluechipgit
# Last Modified: 10/19/2022

$ErrorActionPreference = "Continue"
Set-PowerCLIConfiguration -InvalidCertificateAction:Ignore -Confirm:$false | Out-Null
Import-Module -Name VMware.VimAutomation.Core 
Import-Module -Name VMware.PowerCLI

Write-Host "`n####          Deploy Templates          ####" -ForegroundColor Cyan
Write-Host "####   Author: github.com/bluechipgit   ####" -ForegroundColor Cyan
Write-Host "####      Last Updated: 10/19/2022      ####" -ForegroundColor Cyan
Write-Host "`nWelcome to the interactive template deployment script. Please see the README for detailed documentation and usage instructions"

#### Function Block ####

Function Write-Log {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$False)]
    [ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")]
    [String]
    $Level = "INFO",

    [Parameter(Mandatory=$True)]
    [string]
    $Message,

    [Parameter(Mandatory=$False)]
    [string]
    $Log
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Level $Message"
    If($Log) {
        Add-Content $Log -Value $Line
    }
    Else {
        Write-Output $Line
    }
}

function Add-Note {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$True)]
    [String]
    $vm
    )
    $TimeNow = Get-Date
    $Date = $TimeNow.ToUniversalTime().ToString("MM/dd/yy HH:mm:ss")
    $Note = "Template added on $Date UTC"
    $ExistingNotes = (Get-VM $vm | Select-Object -ExpandProperty Notes); 
    If ($ExistingNotes -ne "") { 
        (Set-VM $vm -Notes "$($ExistingNotes)$Note" -Confirm:$False -RunAsync | Out-Null) 
        } else { Set-VM $vm -Notes "$Note" -Confirm:$False -RunAsync | Out-Null}
}


#### Variable Block ####

$logFile = Read-Host "`nPlease input the filepath and filename to save logs to"
$ovaDirectory = Read-Host "`nPlease enter the directory location where OVA files are stored"
$vcUsername = Read-Host "`nEnter Username"
$vcPassword = Read-Host "Enter Password" -AsSecureString
$vcCredential = New-Object System.Management.Automation.PSCredential ($vcUsername, $vcPassword)

#### Script Block ####

$date = Get-Date
Write-Log -Level "INFO" -Message "Module started by $vcUsername at $date" -Log $logFile


$ovaFiles = Get-ChildItem $ovaDirectory -Recurse -Include *.ova

$minVersion = Read-Host "`nEnter minimum required ESXi host hardware version for deployment"
Write-Log -Level "INFO" -Message "Min hardware version set to $minVersion" -Log $logFile

Write-Host ""

[bool]$running = $true
DO {
    $j=1
    foreach ($ova in $ovaFiles) {
        Write-Host [$j] $ova.Name
        $j++
    }

    $userInput = Read-Host "`nPlease select file to upload"
    $adjInput = [int]$userInput - 1
    $ova = $ovaFiles[$adjInput]
    $ovaName = $ova.Name
    $incompatibleVCenters = @()

    Write-Host "`n$ovaName confirmed" -ForegroundColor Green
    Write-Log -Level "INFO" -Message "$vcUsername selected $ovaName to upload" -Log $logFile

    $templateName = Read-Host "`nInput template name (e.g. al86-v04)"
    Write-Log -Level "INFO" -Message "Template name set: $templateName" -Log $logFile

    Do {
        $vCenterList = Read-Host "`nPlease enter location of file containing list of target vCenters"
    } While ($null -eq $vCenterList)

    $vCenters = Get-Content $vCenterList

    $datastore = Read-Host "`nPlease enter standard name of datastore that the ova will be uploaded to in each vCenter. See README for details"

    Write-Host "`nThe template will be added to the following vCenters to a datastore containing the name $datastore`n"

    foreach ($vCenter in $vCenters) {
        Write-Host $vCenter -ForegroundColor Cyan
    }

    $confirmation = (Read-Host "`nWould you like to continue? Yes [Y] No [N]").ToUpper()
    
    if ($confirmation -eq "Y") {
    } else {
        Write-Host "`nExiting..." -ForegroundColor Yellow
        Write-Log -Level "INFO" -Message "User canceled deployment. Exiting..." -Log $logFile
    }

    Write-Host "`nBeginning template deployment. Logs can be found at $logFile`n" -ForegroundColor Yellow
    
    foreach ($vCenter in $vCenters) {
        $Error.clear()

        $connection = Connect-VIServer -Server $vCenter -Cred $vcCredential 

        if ($connection) {
            Write-Log -Level "INFO" -Message "Connected to $vCenter" -Log $logFile
        } else {
            Write-Log -Level "ERROR" -Message "Could not connect to $vCenter. Skipping" -Log $logFile
            continue
        }

            # Pull provider name from vCenter URL #
            $parsedVCenterName = $vCenter.IndexOf(".")
            $vCenterProvider = $vCenter.Substring(0,$parsedVCenterName)

        # Check for ContentLib datastore
        Write-Log -Level "INFO" -Message "Checking for datastore" -Log $logFile
        $targetDatastore = Get-Datastore | Where-Object{$_.name -like "*$datastore*"} | Get-Random
    
        # Log result of ContentLib datastore search
        if ($targetDatastore) {
            Write-Log -Level "INFO" -Message "Datastore found: $targetDatastore" -Log $logFile
        } else {
            Write-Log -Level "ERROR" -Message "Could not find a datastore that contains the string similar to "'$datastore'". Cannot upload template" -Log $logFile
            Disconnect-VIServer -Server * -Confirm:$false
            Continue
        }

        # Check that datastore is in an available state
        Write-Log -Level "INFO" -Message "Validating that $targetDatastore is in an available state" -Log $logFile
        $availableDatastore = $targetDatastore| Where-Object{$_.state -eq "Available"}

        if ($availableDatastore) {
            Write-Log -Level "INFO" -Message "$targetDatastore is available" -Log $logFile
        } else {
            Write-Log -Level "ERROR" -Message "$targetDatastore is not in an available state. Cannot upload template" -Log $logFile
            Disconnect-VIServer -Server * -Confirm:$false
            Continue
        }

        # Check for compatible host
        Write-Log -Level "INFO" -Message "Checking for compatible host" -Log $logFile
        $vmSwitch = $targetDatastore | Get-VMHost | Where-Object{$_.version -ge $minVersion} | Get-VirtualSwitch -Standard | Get-Random 
        $vmHost = $vmSwitch.VMHost

        if ($vmHost) {
            Write-Log -Level "INFO" -Message "Compatible host found: $vmHost" -Log $logFile
        } else {
            Write-Log -Level "ERROR" -Message "No host found that is version $minVersion or greater and has a standard virtual switch. Cannot upload template" -Log $logFile
            $incompatibleVCenters += $vCenter
            Disconnect-VIServer -Server * -Confirm:$false
            Continue
        }
    
        # Get full path of ova directory #
        $vmSource = Get-ChildItem -Path $ova

        # Concatenate provider name and image name to get standard naming convention for template #
        $vmName = "$vCenterProvider-$templateName"
        Write-Log -Level "INFO" -Message "Template name set: $vmName" -Log $logFile

        # Check if VM already exists #
        $existingTemplates = Get-Template
        $templateArray = @($existingTemplates).name

        # If template does not exist in vCenter, upload VM, convert VM to template, move template to "Template" folder 
    
        if ($templateArray.Contains($vmName) -eq $true) {
            Write-Log -Level "INFO" -Message "$vmName exists. Skipping template" -Log $logFile
            continue
        } else {
            Write-Log -Level "INFO" "Uploading $vmName to $vCenterProvider" -Log $logFile 
            $vmHost | Import-vApp -Source $vmSource -Datastore $targetDatastore -Name $vmName -DiskStorageFormat Thin -Force
            Write-Log -Level "INFO" -Message "Converting $vmName to template" -Log $logFile
            Add-Note -vm $vmName
            Get-VM -Name $vmName | Set-VM -ToTemplate -Confirm:$false | Out-Null
            Write-Log -Level "INFO" -Message "Moving template $vmName to 'Template' folder" -Log $logFile
            Get-Template -name $vmName | Move-Template -Destination (Get-Folder -Name "Templates") | Out-Null  
        }          
        $existingTemplates = Get-Template
        $templateArray = @($existingTemplates).name
        if ($templateArray.Contains($vmName) -eq $true) {
            Write-Log -Level "INFO" -Message "Template $vmName successfully uploaded" -Log $logFile 
        } else {
            Write-Log -Level "ERROR" -Message "Template $vmName failed to upload" -Log $logFile
            continue
        }

        Write-Log -Level "INFO" -Message "Disconnecting from $vCenter" -Log $logFile
        Disconnect-VIServer -Server * -Confirm:$false
    }

    Write-Host "`n$vmName deployed" -ForegroundColor Green
    $confirmation = (Read-Host "`nWould you like to deploy another template? Yes [Y] No [N]").ToUpper()

    if ($confirmation -eq "Y") {
        [bool]$running = $true
    } elseif ($confirmation -eq "N") {
        [bool]$running = $false
    } else {
        Write-Host "`nInvalid input. Exiting" -ForegroundColor Red
        Exit
    }
} While ([bool]$running -eq $true)

if ($null -ne $incompatibleVCenters) {
    Write-Host "`nThe following vCenter(s) did not contain compatible hosts for '$templateName'. Please check the log for details:" -ForegroundColor Red
    Write-Host "`n$incompatibleVCenters"
}

Write-Host "`nExiting..." -ForegroundColor Yellow
     


