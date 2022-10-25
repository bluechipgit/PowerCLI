# Name: Check-MultiWriter.ps1
# Author: github.com/bluechipgit
# Last Modified: 10/17/2022


#### Module Block ####

Import-Module -Name VMware.PowerCLI -ErrorAction SilentlyContinue
Import-Module -Name VMware.VimAutomation.Core 
Import-Module -Name VMware.PowerCLI

Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false | Out-Null
Set-PowerCLIConfiguration -InvalidCertificateAction:Ignore -Confirm:$false | Out-Null
$ErrorActionPreference = "Silently Continue"

#### Function Block ####
Function Find-MultiWriter {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True)]
        [string]
        $Cluster
    )
    if ($Cluster) {
        Write-Host "`nChecking VMs for MultiWriter...`n" -ForegroundColor Yellow
        $tarCluster = Get-Cluster $Cluster
        $tarCluster | Get-VM | Get-HardDisk | %{
            $ctrl = Get-ScsiController -HardDisk $_
            $_ | Select-Object @{N='VM';E={$_.Parent.Name}},
                @{N='VMHost';E={$_.Parent.VMHost.Name}},
                @{N='Cluster';E={Get-Cluster -VM $_.Parent | Select-Object -ExpandProperty Name}},
                Name,
                StorageFormat,
                FileName,
                @{N='Multi-Writer';E={
                   Get-AdvancedSetting -Entity $_.Parent -Name "scsi$($ctrl.ExtensionData.BusNumber):$($_.ExtensionData.UnitNumber).sharing" |
                   Select-Object -ExpandProperty Value
                }
            }
        }
        Write-Host "Completed scan in $tarCluster" -ForegroundColor Green
    }
}

#### Welcome Block ####

Write-Host "####         Find-MultiWriter          ####" -ForegroundColor Cyan
Write-Host "####   Author: github.com/bluechipgit   ####" -ForegroundColor Cyan
Write-Host "####      Last Updated: 10/17/2022      ####" -ForegroundColor Cyan

#### Script Block ####

$vCenter = Read-Host "Enter target vCenter" 
$vcUsername = Read-Host "`nEnter Username"
$vcPassword = Read-Host "Enter Password" -AsSecureString 
$vcCred = New-Object System.Management.Automation.PSCredential ($vcUsername, $vcPassword)

$vCenterConnection = Connect-VIServer -Server $vCenter -Cred $vcCred

if ($vCenterConnection) {
    Write-Host "`nConnected to $vCenter" -ForegroundColor "Green"

    # Display list of clusters until user declines to scan additonal clusters #

    [bool]$running = $true

    DO {
        $clusters = Get-Cluster
        $j=1
        Write-Host ""

        # Display numbered list of clusters #

        foreach ($cluster in $clusters) {
            Write-Host [$j] $cluster
            $j++
        }

        $userInput = Read-Host "`nPlease select a target cluster" 

        # Adjust selection to choose correct array object #

        $adjInput = [int]$userInput - 1
        $targetCluster = $clusters[$adjInput]

        $report = Find-MultiWriter -Cluster $targetCluster
        $report | Export-Csv -Path $PWD/multiwriter_results.csv -NoTypeInformation -UseCulture -Append

        $confirmation = (Read-Host "`nWould you like to target an additonal cluster? [Y] Yes [N] No").ToUpper()

        if ($confirmation -eq "Y") {
            [bool]$running = $true
        } elseif ($confirmation -eq "N") {
            [bool]$running = $false
        } else {
            Write-Host "`nInvalid input. Exiting" -ForegroundColor Red
            Disconnect-VIServer -Server * -Confirm:$false
            Exit
        }
    } Until ([bool]$running -eq $false)

    Write-Host "`nResults exported to $PWD/multiwriter_results.csv" -ForegroundColor Cyan
    Write-Host "`nExiting...`n" -ForegroundColor Yellow
    Disconnect-VIServer -Server * -Confirm:$false

} else {
    Write-Host "Unable to connect to $vCenter. Exiting" -ForegroundColor 'Red'
    Exit
}


