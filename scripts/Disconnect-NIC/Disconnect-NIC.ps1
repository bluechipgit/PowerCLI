# Name: Disconnect-NIC.ps1
# Author: github.com/bluechipgit
# Last Modified: 10/19/2022


Import-Module VMware.PowerCLI | Out-Null
Import-Module VMware.VimAutomation.Core | Out-Null

$ErrorActionPreference = 'SilentlyContinue'

#### Save file dialogue box (not used for UNIX systems) ####
Function Save-FileName($initialDirectory) {   
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

    $SaveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $SaveFileDialog.initialDirectory = $initialDirectory
    $SaveFileDialog.filter = "CSV file (*.csv)|*.csv| All Files (*.*)|*.*";
    $SaveFileDialog.ShowDialog() | Out-Null
    $SaveFileDialog.filename
}

#### Gather VC Server & credentials for connection ####
$Global:vcServer = Read-Host "`nEnter VC Server"
$vcUsername = Read-Host "Enter Username"
$vcPassword = Read-Host "Enter password" -AsSecureString
$vcCredential = New-Object System.Management.Automation.PSCredential ($vcUsername, $vcPassword)
$logFile = Read-Host "`nPlease input the filepath and filename to save logs to"

Write-Host "`nConnecting to $Global:vcServer..." -Foregroundcolor 'Yellow'

#### Verify connectivity to VC server####
$vcs = Connect-VIServer -Server $Global:vcServer -Cred $vcCredential
if($vcs){
    Write-Host "`nConnected to $Global:vcServer" -ForegroundColor "Green"
    } else {
    Write-Host "Unable to connect to $Global:vcServer" -ForegroundColor 'Red' -BackgroundColor 'Yellow'
    Exit
}

#### Retrieve VM List ####
[bool]$validFile = $false
while ([bool]$validFile -eq $false) {
    $vmFile = Read-Host "`nEnter full path to CSV file with list of target VMs"
    if ($vmFile -notmatch '\.csv+$') {
        Write-Host "`nInvalid filetype selected. Filetype must be CSV." -ForegroundColor 'Red'
        } else {
            [bool]$validFile = $true
            Write-Host "`nFile accepted" -ForegroundColor 'Green'
    }
 }


#### Display reading VM file ####
Write-Host "`nReading VM list..." -ForegroundColor 'Yellow'

#### Get list of targetVms ####
$vmList = Import-Csv $vmFile
$vmList | Foreach-Object {
    $_.PSObject.Properties | Foreach-Object { $_.Value = $_.Value.Trim() }
}

if ($Null -ne $vmList) {
    Write-Host "`nVM list valid" -ForegroundColor "Green"
} else {
    Write-Host "`nVM list empty. Exiting..." -ForegroundColor "Red"
    Exit
}

# #### Convert file to VM objects ####

# Target VMs #
$targetVms = @()
foreach ($vm in $vmList.Name) {
    $foundVM = Get-VM $vm
    if ($foundVM) {
        $targetVms += $vm
    } else {
        Write-Host "`nCould not find $vm in $Global:vcServer. Skipping" -ForegroundColor "Red"
    }
}

#### Display submitted list of adapters ####
Get-NetworkAdapter $targetVms | Select-Object -Property @{Name='VM'; Expression='Parent'}, @{Name='Adapter'; Expression='Name'}, ConnectionState | Format-Table -autosize

$poweredOnVms =  Get-VM $targetVms | Where-Object {$_.PowerState -eq "PoweredOn"}

#### Set StartConnected parameter ####
[bool]$validInput = $false
while ([bool]$validInput -eq $false) {
    $confirmation = (Read-Host "`nSelect network adapter ""StartConnected"" preference: [S] StartConnected [N] NoStartConnected").ToUpper()
    if ($confirmation -eq 'S') {
        [bool]$startConnected = $true
        [bool]$validInput = $true
    } elseif ($confirmation -eq 'N') {
        [bool]$startConnected = $false
        [bool]$validInput = $true
    } else {
        Write-Host "Invalid input" -ForegroundColor 'Red'
    }
}

#### Confirm user StartConnected choice ####
if ([bool]$startConnected -eq $true) {
    Write-Host "`nAll adapters will be set to ""StartConnected"". Adapters in a ""Connected"" state will be disconnected.`n" -ForegroundColor 'Cyan'
    $confirmation = (Read-Host "Continue? [Y] Yes [No]").ToUpper()
    if ($confirmation -eq "N") {
        Write-Host "Process canceled. Exiting..." -ForegroundColor 'Red'
        exit
    }
} elseif ([bool]$startConnected -eq $false) {
    Write-Host "`nAll adapters will be set to ""NoStartConnected"". Adapters in a ""Connected"" state will be disconnected.`n" -ForegroundColor 'Cyan'
    $confirmation = (Read-Host "Continue? [Y] Yes [No]").ToUpper()
    if ($confirmation -eq "N") {
        Write-Host "Process canceled. Exiting..." -ForegroundColor 'Red'
        exit
    }
}

#### Initialize adapter disconnect process ####
Write-Host "`nNetwork adapter configuration initialized`n" -ForegroundColor 'Cyan'

### Disconnect adapters for targetVms in PoweredOn state #### 
$conAdapters = Get-NetworkAdapter $targetVms| Where-Object {$_.ConnectionState.Connected -eq $true}
$nonConAdapters = Get-NetworkAdapter $targetVms| Where-Object {$_.ConnectionState.Connected -eq $false}

if ($conAdapters) {
    foreach ($vm in $poweredOnVms) {
        $conState = Get-NetworkAdapter $vm | Where-Object {$_.ConnectionState.Connected -eq $true}
        if ($conState) {
            Write-Host "Disconnecting network adapters on $vm..." -ForegroundColor 'Yellow'
            Get-VM $vm | Get-NetworkAdapter | Set-NetworkAdapter -Connected:$false -Confirm:$false | Out-Null
        }
    } Write-Host "`nDisconnects complete`n"  -ForegroundColor 'Green'
}

### Set StartConnected state ####
foreach ($vm in $targetVms) {
    if ([bool]$startConnected -eq $true) {
        Write-Host "Setting ""StartConnected"" state preference on $vm..." -ForegroundColor 'Yellow'
        Get-VM $vm | Get-NetworkAdapter | Set-NetworkAdapter -StartConnected:$true -Confirm:$false | Out-Null
    } else {
        Write-Host "Setting ""StartConnected"" state preference on $vm..." -ForegroundColor 'Yellow'
        Get-VM $vm | Get-NetworkAdapter | Set-NetworkAdapter -StartConnected:$false -Confirm:$false | Out-Null
     }
}

Write-Host "`n""StartConnected"" states configured"  -ForegroundColor 'Green'

#### Display results ####
Write-Host "`nGathering results..." -ForegroundColor 'Yellow'

$targetVms = Get-VM $targetVms
$Global:failures = @()
$Global:completions = @()
foreach ($vm in $targetVms) {
    $adapter = Get-VM $vm | Get-NetworkAdapter
    if ($adapter.ConnectionState.Connected -eq $true) {
        $Global:failures += $vm
    } else {
        $Global:completions += $vm
    }
}

Write-Host "`nThe following adapters were successfully disconnected:`n" -ForegroundColor 'Green'
Get-NetworkAdapter $targetVms | Select-Object -Property @{Name='VM'; Expression='Parent'}, @{Name='Adapter'; Expression='Name'}, ConnectionState | Where-Object{$_.ConnectionState.Connected -eq $false} | Format-Table -autosize

if ($Global:failures) {
    Write-Host "The following adapters failed to disconnect. Please check the VM in vCenter." -ForegroundColor "Red"
    Get-NetworkAdapter $targetVms | Select-Object -Property @{Name='VM'; Expression='Parent'}, @{Name='Adapter'; Expression='Name'}, ConnectionState | Where-Object{$_.ConnectionState.Connected -eq $true} | Format-Table -autosize
}

$results = Get-VM $targetVms | Get-NetworkAdapter | Select-Object -Property @{Name='VM'; Expression='Parent'}, Name, ConnectionState | Out-Null

#### Export Log ####
$confirmation = (Read-Host "`nDownload results? [Y] Yes [N] No").ToUpper()
    if ($confirmation -eq 'Y') {
        Write-Host "`nSaving results to /mnt/pure_nfs_slush/apo_automation/logs/disconnectNIC.log..." -ForegroundColor 'Yellow'
        $results | Export-Csv -NoTypeInformation -Path $logFile
}

$confirmation = (Read-Host "`nDo you want to power off VMs? [Y] Yes [N] No").ToUpper()
    if ($confirmation -eq 'Y') {
        foreach ($vm in $targetVms) {
            Write-Host "Powering off $vm" -ForegroundColor 'Yellow'
            Get-VM $vm | Stop-VM -Confirm:$false
        } else {
        continue
     }
}

#### Disconnect from VC Server #### 
Write-Host "`nDisconnecting from $Global:vcServer...`n" -Foregroundcolor 'Yellow'

Disconnect-VIServer -server $Global:vcServer -Confirm:$false
