# Name: Manage-VCenterAccount.ps1
# Author: Austin Van Camp
# Postion: Contracted Automation Engineer III
# Last Modified: 07/18/2022

Import-Module -Name VMware.PowerCLI -ErrorAction SilentlyContinue
Import-Module -Name VMware.VimAutomation.Core 
Import-Module -Name VMware.PowerCLI

Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false | Out-Null
Set-PowerCLIConfiguration -InvalidCertificateAction:Ignore -Confirm:$false | Out-Null
$ErrorActionPreference = "Silently Continue"


#### Function Block ####

# Adds value into the $vCenter array in command 8
Function Add-VCenter {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True)]
        [string]
        $vCenterToAdd
    )
    if ($vCenterToAdd) {
    $global:vCenters += $vCenterToAdd
    }
}

# Writes to log file
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

# Generates random password for changing ESXI hosts passwords
function Get-RandomPassword {
    param (
        [Parameter(Mandatory)]
        [ValidateRange(4,[int]::MaxValue)]
        [int] $length,
        [int] $upper = 1,
        [int] $lower = 1,
        [int] $numeric = 1,
        [int] $special = 1
    )
    if($upper + $lower + $numeric + $special -gt $length) {
        throw "number of upper/lower/numeric/special char must be lower or equal to length"
    }
    $uCharSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $lCharSet = "abcdefghijklmnopqrstuvwxyz"
    $nCharSet = "0123456789"
    $sCharSet = "/*-+,!?=()@;:._"
    $charSet = ""
    if($upper -gt 0) { $charSet += $uCharSet }
    if($lower -gt 0) { $charSet += $lCharSet }
    if($numeric -gt 0) { $charSet += $nCharSet }
    if($special -gt 0) { $charSet += $sCharSet }
    
    $charSet = $charSet.ToCharArray()
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[]($length)
    $rng.GetBytes($bytes)
 
    $result = New-Object char[]($length)
    for ($i = 0 ; $i -lt $length ; $i++) {
        $result[$i] = $charSet[$bytes[$i] % $charSet.Length]
    }
    $password = (-join $result)
    $valid = $true
    if($upper   -gt ($password.ToCharArray() | Where-Object {$_ -cin $uCharSet.ToCharArray() }).Count) { $valid = $false }
    if($lower   -gt ($password.ToCharArray() | Where-Object {$_ -cin $lCharSet.ToCharArray() }).Count) { $valid = $false }
    if($numeric -gt ($password.ToCharArray() | Where-Object {$_ -cin $nCharSet.ToCharArray() }).Count) { $valid = $false }
    if($special -gt ($password.ToCharArray() | Where-Object {$_ -cin $sCharSet.ToCharArray() }).Count) { $valid = $false }
 
    if(!$valid) {
         $password = Get-RandomPassword $length $upper $lower $numeric $special
    }
    return $password
}

# Tests the .IsDisabled value for a user account
Function Test-DisabledAccount {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$True)]
    [String]
    $Username
    )

    $User = Get-SsoPersonUser -Name $Username -Domain 'vsphere.local'
    [bool]$disabledStatus = $user.Disabled

    return [bool]$disabledStatus
}

# Finds user in vCenter given a username
Function Find-User {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$True)]
    [String]
    $Username
    )

    $User = Get-SsoPersonUser -Name $Username -Domain 'vsphere.local'
    if ($null -eq $User) {
        return $false
    } else {
        return $true
    }
}

# Checks if the user is in the administrators group
Function Find-UserInAdmin {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$True)]
    [String]
    $Username
    )

    $userPresent = Get-SsoGroup -Name "Administrators" -Domain "vsphere.local" | Get-SsoPersonUser | Where-Object{$_.Name -eq $userName}

    if ($userPresent) {
        return $true
    } else {
        return $false
    }
}

# Set log location #
$logFile = Read-Host "`nPlease input the filepath and filename to save logs to"

# List of module options #
$options = @(
            "Create vCenter User Account"
            "Delete vCenter User Account"
            "Enable vCenter User Account"
            "Disable vCenter User Account"
            "Change ESXi Host Credentials"
            "Rotate vCenter Administrator Credential"
            "View List of Target VCenters"
            "Exit"
             )

# Intro to module #
Write-Host "`nWelcome to the vCenter account mangement module. Logs can be found at $logfile" -ForegroundColor Yellow

Write-Host "Please enter your vCenter account credentials"

# Gather vCenter connection details #
$vcUsername = Read-Host "`nEnter Username"
$vcPassword = Read-Host "Enter Password" -AsSecureString
$vcCred = New-Object System.Management.Automation.PSCredential ($vcUsername, $vcPassword)

Do {
    $vCenterList = Read-Host "`nPlease enter location of file containing list of target vCenters"
} While ($null -eq $vCenterList)

$vCenters = Get-Content $vCenterList

# Log who is running the script #
Write-Log -Level "INFO" -Message "Account management script started by $vcUsername" -Log $logfile

# Loop through main menu intil user exits #
DO
{
Write-Host "`n########## MAIN MENU ##########"
Write-Host "`n[1]" $options[0]"`n[2]" $options[1]"`n[3]" $options[2] "`n[4]" $options[3] "`n[5]" $options[4] "`n[6]" $options[5] "`n[7]" $options[6] "`n[8]" $options[7]
$choice = Read-Host "`nPlease make your selection"

# User inputs "1" #
if ($choice -eq "1") {
    $Error.clear()
    Write-Host "`n########## CREATE VCENTER USER ACCOUNT ##########`n"
    Write-Log -Level "INFO" -Message "Create user account module selected" -Log $logfile

    #### Retrieve user Details ####
    [bool]$credsPopulated = $false
    DO {
        $userName = Read-Host "Enter account username"
        $userEmail = Read-Host "Enter account email address"
        $userFirstName = Read-Host "Enter account first name"
        $userLastName = Read-Host "Enter account last name"

        if (($userName) -and ($userEmail) -and ($userFirstName) -and ($userLastName)) {
            [bool]$credsPopulated = $true
        } else {
            Write-Host "`nMissing required fields. Please try again`n" -ForegroundColor Red
        } # if (($userName) -and ($userEmail) -and ($userFirstName) -and ($userLastName))
    } UNTIL ([bool]$credsPopulated -eq $true) # DO $userName = Read-Host "Enter account username"

    # Gather password for new account #
    [bool]$validPass = $false
    DO {
        Write-Host "`nPassword must meet complexity requirements:`n`nAt least one upper case English letter [A-Z]`nAt least one lower case English letter [a-z]`nAt least one digit [0-9]`nAt least one special character (!,@,#,%,^,&,$)`nMinimum 12 in length."
        $newPass = Read-Host "`nPlease enter temporary password for $username@vsphere.local" -AsSecureString
        $unEncPass = ConvertFrom-SecureString -SecureString $newPass -AsPlainText

        if (($unEncPass -cmatch '[a-z]') -and ($unEncPass -cmatch '[A-Z]') -and ($unEncPass -match '\d') -and ($unEncPass.length -ge 12) -and ($unEncPass -match '!|@|#|%|^|&|$')) {
            [bool]$validPass = $true
        } else {
            Write-Host "`nInvalid password. Please check complexity requirements and try again" -ForegroundColor Red
            [bool]$validPass = $false
        } # if (($unEncPass -cmatch '[a-z]') -and ($unEncPass -cmatch '[A-Z]')...
    }
    UNTIL ([bool]$validPass -eq $true) # DO  Write-Host "`nPassword must meet complexity...

    Write-Log -Level "INFO" -Message "Account parameters accepted" -Log $logfile
    Write-Host "`nCreating account '$userName@vsphere.local'`n" -ForegroundColor Yellow
    foreach ($vCenter in $global:vCenters) {
        Write-Log -Level "INFO" -Message "Connecting to $vCenter..." -Log $logfile

        # Connect to vCenter #
    $connection = Connect-SsoAdminServer -Server $vCenter -User $vcUsername -Password $vcPassword -SkipCertificateCheck 
        if ($connection) {
            Write-Log -Level "INFO" -Message "Connected to $vCenter" -Log $logfile

            # Test if account is already present on vCenter #
            if (Find-User($userName)) {
                Write-Host "Account with username '$userName' already exists on $vCenter" -ForegroundColor Red
                Write-Log -Level "ERROR" -Message "Account with username '$userName' already exists on $vCenter" -Log $logfile
            } else {
                Write-Log -Level "INFO" -Message "Creating account $userName@vsphere.local on $vCenter..." -Log $logfile

                # Create user on vCenter #
                Try {
                    $user = New-SsoPersonUser -User $userName -Password $unEncPass -EmailAddress $userEmail -FirstName $userFirstName -LastName $userLastName -ErrorAction STOP

                    # Verify account has been created #
                    if (Find-User($userName)) {
                        Write-Log -Level "INFO" -Message "Account $user successfully created on $vCenter" -Log $logfile

                        # Add user to administrators group #
                        $adminGroup = Get-SsoGroup -Name "Administrators" -Domain "vsphere.local"
                        Write-Log -Level "INFO" -Message "Adding $user to Administrators group..." -Log $logfile
                        $user | Add-UserToSsoGroup -TargetGroup $adminGroup | Out-Null

                        # Verify user is in administrators group #
                        if (Find-UserInAdmin($userName)) {
                            Write-Log -Level "INFO" -Message "Account $user added to Administrator group" -Log $logfile
                        } else {
                            Write-Log -Level "ERROR" -Message "Failed to add $user to Administrators group" -Log $logfile
                        } # if (Find-UserInAdmin($userName))

                        # Final verification of account creation and proper group additon #
                        Write-Log -Level "INFO" -Message "Validating account creation..." -Log $logfile
                        if ((Find-UserInAdmin($userName)) -and ($user)) {
                        Write-Host "Account $user successfully created and added to Administrators group on $vCenter" -ForegroundColor Green
                        Write-Log -Level "INFO" -Message "Account $user successfully created and added to Administrators group on $vCenter" -Log $logfile
                        Write-Log -Level "INFO" -Message "Disconnecting from $vCenter..." -Log $logfile
                        Disconnect-SsoAdminServer -Server "*"
                        }
                    } else {
                    Write-Log -Level "ERROR" -Message "Account creation failed for '$userName'. User could not be found" -Log $logfile
                    Write-Log -Level "ERROR" -Message $Error -log $logfile
                    }
                } Catch {
                    Write-Host "Account creation failed. Check log for details" -ForegroundColor Red
                    Write-Log -Level "ERROR" -Message -$Error -log $logfile
                }
            } # if (Find-User($userName))
        } else {
            Write-Host "Could not connect to $vCenter"
            Write-Log -Level "ERROR" -Message $Error -log $logfile
        } # if ($connection) 
    } # foreach ($vCenter in $stagevCenters)
    Write-Host "`nAccount configuration complete" -ForegroundColor Green
    if ($global:defaultviserver) {
        Disconnect-SsoAdminServer -Server "*"
    }
    # if ($choice -eq "1")
}

# User inputs "2" #
if ($choice -eq "2") {
    $Error.clear()
    Write-Host "`n########## DELETE VCENTER USER ACCOUNT ##########`n"
    Write-Log -Level "INFO" -Message "Delete user account module selected" -Log $logfile

    # Gather username of account to delete #
    $userName = Read-Host "Enter username of target account"

    Write-Log -Level "INFO" -Message "Account parameters accepted" -Log $logfile
    Write-Host "`nDeleting account '$userName@vsphere.local'`n" -ForegroundColor Yellow

    foreach ($vCenter in $global:vCenters) {
        Write-Log -Level "INFO" -Message "Connecting to $vCenter..." -Log $logfile

        # Connect to vCenter #
    $connection = Connect-SsoAdminServer -Server $vCenter -User $vcUsername -Password $vcPassword -SkipCertificateCheck
        if ($connection) {
            Write-Log -Level "INFO" -Message "Connected to $vCenter" -Log $logfile

            # Try account deletion #
            Try {
                $user = Get-SsoPersonUser -Name $userName -Domain 'vsphere.local'
                if (Find-User($userName)) {
                    Write-Log -Level "INFO" -Message "Deleting account $user on $vCenter..." -Log $logfile
                    Get-SsoPersonUser -Name $userName -Domain 'vsphere.local' | Remove-SsoPersonUser
                    Write-Log -Level "INFO" -Message "Verifying account deletion..." -Log $logfile
                    if (Find-User($user)) {
                        Write-Host "Failed to delete $user from $vCenter. Please check $logfile for details" -ForegroundColor Red
                        Write-Log -Level "ERROR" -Message "Account $user was found. Account deletion failed" -log $logfile
                    } else {
                        Write-Host "Account $user successfully deleted from $vCenter" -ForegroundColor Green
                        Write-Log -Level "INFO" -Message "Account $user successfuly deleted from $vCenter" -Log $logfile
                    } # if (Find-User($userName))
                } else {
                Write-Host "Unable to find account with username '$user' on $vCenter" -ForegroundColor Red
                Write-Log -Level "ERROR" -Message "Unable to find account with username '$userName' on $vCenter" -Log $logfile
                } # if (Find-User($userName))
            } Catch {
                Write-Host "Account deletion failed. Check log for details" -ForegroundColor Red
                Write-Log -Level "ERROR" -Message -$Error -log $logfile
            }
        } else {
            Write-Host "Could not connect to '$vCenter" -ForegroundColor Red
            Write-Log -Level "ERROR" -Message $Error -Log $logfile
        } # if ([bool]$isConnected -eq $true)
        Write-Log -Level "INFO" -Message "Disconnecting from $vCenter..." -Log $logfile
        Disconnect-SsoAdminServer -Server "*"
    }  # foreach ($vCenter in $global:vCenters)
    Write-Host "`nAccount deletion complete" -ForegroundColor Green
    Write-Log -Level "ERROR" -Message "$Error" -Log $logfile
}

if ($choice -eq "3") {
    $Error.clear()
    Write-Host "`n########## ENABLE VCENTER USER ACCOUNT ##########`n"
    Write-Log -Level "INFO" -Message "Enable user account module selected" -Log $logfile

    $userName = Read-Host "Enter username of target account"

    Write-Host "`nEnabling account $userName@vsphere.local...`n" -ForegroundColor Yellow

    foreach ($vCenter in $stagevCenters) {
        Write-Log -Level "INFO" -Message "Connecting to $vCenter..." -Log $logfile

        # Connect to vCenter #
        $connection = Connect-SsoAdminServer -Server $vCenter -User $vcUsername -Password $vcPassword -SkipCertificateCheck -ErrorAction Continue
        if ($connection) {
            Write-Log -Level "INFO" -Message "Connected to $vCenter" -Log $logfile

            # Get user account #
            $user = Get-SsoPersonUser -Name $userName -Domain 'vsphere.local'
            if ($user) {
                Write-Log -Level "INFO" -Message "Account $user found on $vCenter" -Log $logfile
                # Test if account is disabled and, if disabled, enable account. Else, log that the account is already enabled #
                if (Test-DisabledAccount($userName)) {
                    Write-Log -Level "INFO" -Message "Account $user is disabled. Enabling..." -Log $logfile
                    Set-SsoPersonUser -User $user -Enable $true | Out-Null
                    # Verify that account has been enabled #
                    if (Test-DisabledAccount($userName)) {
                        Write-Log -Level "ERROR" -Message "Failed to enable account $user on $vCenter. IsDisabled property returned 'True'" -log $logfile
                        Write-Host "Failed to enable account $user on $vCenter. Check log for details" -ForegroundColor Red
                    } else {
                        Write-Host "Account $user successfully enabled on $vCenter" -ForegroundColor Green
                        Write-Log -Level "INFO" -Message "Account $user successfully enabled on $vCenter" -log $logfile
                    } # if (Test-DisabledAccount($userName))
                } else {
                    Write-Host "Account $user already enabled on $vCenter"
                    Write-Log -Level "INFO" -Message "Account $user already enabled on $vCenter" -Log $logfile
                }  # (Test-DisabledAccount($userName))
            } else {
            Write-Host "Unable to find account with username '$userName' on $vCenter" -ForegroundColor Red
            Write-Log -Level "ERROR" -Message "Unable to find account with username '$userName' on $vCenter" -Log $logfile
            }
        } else {
            Write-Host "Could not connect to '$vCenter" -ForegroundColor Red
            Write-Log -Level "ERROR" -Message $Error -Log $logfile
        } 
        Write-Log -Level "INFO" -Message "Disconnecting from $vCenter..." -Log $logfile
        Disconnect-SsoAdminServer -Server "*"
    } 
    Write-Host "`nAccount configuration complete" -ForegroundColor Green
}

# User inputs "4" #
if ($choice -eq "4") {
    $Error.clear()
    Write-Host "`n########## DISABLE VCENTER USER ACCOUNT ##########`n"
    Write-Log -Level "INFO" -Message "Disable user account module selected" -Log $logfile

    $userName = Read-Host "Enter username of target account"

    Write-Host "`nDisabling account $userName@vsphere.local...`n" -ForegroundColor Yellow

    foreach ($vCenter in $global:vCenters) {
        Write-Log -Level "INFO" -Message "Connecting to $vCenter..." -Log $logfile
        $connection = Connect-SsoAdminServer -Server $vCenter -User $vcUsername -Password $vcPassword -SkipCertificateCheck -ErrorAction Continue
        if ($connection.IsConnected) {
            Write-Log -Level "INFO" -Message "Connected to $vCenter" -Log $logfile
            $user = Get-SsoPersonUser -Name $userName -Domain 'vsphere.local'
            if ($user) {
                Write-Log -Level "INFO" -Message "Account $user found on $vCenter" -Log $logfile
                if (Test-DisabledAccount($userName)) {
                    Write-Host "Account $user is already disabled on $vCenter"
                    Write-Log -Level "INFO" -Message "Account $user is already disabled" -Log $logfile
                } else {
                    Write-Log -Level "INFO" -Message "Disabling account $user on $vCenter" -Log $logfile
                    Set-SsoPersonUser -User $user -Enable $false | Out-Null
                    if (Test-DisabledAccount($userName)) {
                        Write-Log -Level "INFO" -Message "Account $user successfully disabled on $vCenter" -log $logfile
                        Write-Host "Account $user successfully disabled on $vCenter" -ForegroundColor Green
                    } else {
                        Write-Log -Level "ERROR" -Message "Failed to disable account $user on $vCenter. 'Disabled' property returned 'false'"
                    } # if (Test-DisabledAccount($userName))
                }  # (Test-DisabledAccount($userName))
            } # if ($user)
        } else {
            Write-Host "Could not connect to '$vCenter" -ForegroundColor Red
            Write-Log -Level "ERROR" -Message $Error -Log $logfile
        } # if ([bool]$isConnected -eq $true)
        Write-Log -Level "INFO" -Message "Disconnecting from $vCenter..." -Log $logfile
        Disconnect-SsoAdminServer -Server "*"
    }  # foreach ($vCenter in $global:vCenters)
    Write-Host "`nAccount configuration complete" -ForegroundColor Green
}

# User inputs "5" #
if ($choice -eq "5") {
    $Error.clear()
    $newPass = Get-RandomPassword 12
    Write-Host "`n########## CHANGE ESXI HOST CREDENTIALS ##########`n"
    Write-Host "This module updates the password for the 'root' account on each host in a target cluster. Please record the following password for your records:"

    #### Display new password ####
    Write-Host "`n------------"
    Write-Host "$newPass" -ForegroundColor Cyan
    Write-Host "------------"

    Write-Log -Level "INFO" -Message "ESXI root credential change module selected" -Log $logfile

    #### List vCenters ####

    Write-Host "`nTarget vCenters:"
    $j=1
    foreach ($vCenter in $global:vCenters) {
        Write-Host [$j] $vCenter
        $j++
    }

    $vCenterChoice = Read-Host "`nPlease select a target vCenter"

    #### Adjust user input to select correct vCenter in array ####
    $vCenterNumber = [int]$vCenterChoice - 1
    $targetvCenter = $global:vCenters[$vCenterNumber]

    Write-Host "`nConnecting to $targetvCenter..." -ForegroundColor Yellow
    Write-Log -Level "INFO" -message "Target vCenter $targetvCenter selected. Connecting..." -Log $logfile

    $connection = Connect-VIServer -Server $targetvCenter -Cred $vcCred
    if ($connection.IsConnected) {
        Write-Host "`nConnected to $targetvCenter" -ForegroundColor Green
        Write-Log -Level "INFO" -Message "Connected to $targetvCenter" -Log $logfile

        #### Dynamically populate cluster array ####
        $clusterList = @()
        foreach ($cluster in Get-Cluster) {
            $clusterList += $cluster
        }

        #### List clusters ####
        Write-Host "`nTarget Clusters:"
        $i=1
        foreach ($cluster in $clusterList) {
            Write-Host [$i] $cluster.Name
            $i++
        }

        $clusterChoice = Read-Host "`nPlease select target cluster"

        #### Adjust user input to select correct cluster in array ####
        $clusterNumber = [int]$clusterChoice - 1
        $targetCluster = $clusterList[$clusterNumber]

        Write-Host "`nCluster $targetCluster confirmed. Updating root user credentials...`n" -ForegroundColor Yellow
        Write-Log -Level "INFO" -Message "Cluster $targetCluster selected" -Log $logfile

        #### Asssign credential variables ####
        $user = "root"
        #### Setting password in plaintext to present to user after execution #### NOTE: Need to revisit re security implications -AVC 070122
        $encPass = ConvertTo-SecureString $newPass -AsPlainText -Force
        $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $encPass

        Write-Log -Level "INFO" -Message "Root credential variables assigned" -Log $logfile

        ### Gather hosts in cluster ####
        $vmHosts = $targetCluster | Get-VMHost
        $vmCount = $vmHosts.Count
        if ($vmHosts) {
            Write-Log -Level "INFO" -Message "$vmCount VM hosts found in $targetCluster" -Log $logfile
        } else {
            Write-Log -Level "ERROR" -Message "Get-VMHost returned null" -Log $logfile
            Write-Host "No VMs found in $targetCluster. Exiting..." -ForegroundColor Red
            Disconnect-VIServer -Server "*"
            Break
        } # if ($vmHosts)

        #### Change root credential for hosts in $vmHosts ####
        foreach ($vmHost in $vmHosts) {
            $esxcli = get-esxcli -vmhost $vmHost -v2
            $esxcli.system.account.set.Invoke(@{id=$cred.UserName;password=$cred.GetNetworkCredential().Password;passwordconfirmation=$cred.GetNetworkCredential().Password}) | Out-Null
        }

        #### Verify that root credential has been updated by connecting to the host with new creds ####
        foreach ($vmHost in $vmHosts) {
            $testConnection = Connect-VIServer -Server $vmHost.Name -Cred $cred
            if (($testConnection) -and ($vmHost.ConnectionState -eq "Connected")) {
                Write-Host "Root credential successfully updated for $vmHost" -ForegroundColor Green
                Write-Log -Level "INFO" -Message "Root credential successfully updated for $vmHost" -log $logfile
                Write-Log -Level "INFO" -Message "Disconnecting from $vCenter..." -log $logfile
                Disconnect-VIServer -Server $vmHost.Name -Confirm:$False
            } else {
                Write-Host "Failed to update root credential for $vmHost. Check log for details" -ForegroundColor Red
                if ($vmHost.ConnectionState -ne "Connected") {
                    Write-Log -Level "ERROR" -Message "Host $vmHost is not connected to $vCenter"
                }
                Write-Log -Level "ERROR" -Message $Error -Log $logfile
                Break
            }
        } # foreach ($vmHost in $vmHosts)
        Write-Host "`nCredential update complete" -ForegroundColor Green
    } else {
    Write-Host "Could not connect to $targetvCenter" -ForegroundColor Red
    Write-Log -Level "ERROR" -Message $Error -Log $logfile
    $Error.clear()
    } # if ($connection.IsConnected)
    Disconnect-VIServer -Server "*" -Confirm:$false
}

# User inputs "6" #
if ($choice -eq "6") {
    $Error.clear()
    Write-Host "`n########## ROTATE VCENTER ADMINISTRATOR PASSWORD ##########`n"
    Write-Log -Level "INFO" -Message "Rotate vCenter Administartor account module selected" -Log $logfile

    Write-Host "This module updates the password for the administrator@vsphere.local account. Please record the following password for your records:"

    #### Display new password ####
    $newPass = Get-RandomPassword 12
    Write-Host "`n------------"
    Write-Host "$newPass" -ForegroundColor Cyan
    Write-Host "------------"

    #### Retrieve user Details ####
    $userName = "Administrator"

    Write-Log -Level "INFO" -Message "Account parameters accepted" -Log $logfile
    Write-Host "`nUpdating password for $userName@vsphere.local`n" -ForegroundColor Yellow

    foreach ($vCenter in $global:vCenters) {
        Write-Log -Level "INFO" -Message "Connecting to $vCenter..." -Log $logfile
        $connection = Connect-SsoAdminServer -Server $vCenter -User $vcUsername -Password $vcPassword -SkipCertificateCheck
        if ($connection.IsConnected) {
            Write-Log -Level "INFO" -Message "Connected to $vCenter" -Log $logfile

            #### Delete administrator@vsphere.local ####
            Write-Log -Level "INFO" -Message "Deleting account $userName on $vCenter..." -Log $logfile
            Get-SsoPersonUser -Name $userName -Domain 'vsphere.local' | Remove-SsoPersonUser

            #### Create administrator@vsphere.local ####
            Write-Log -Level "INFO" -Message "Creating account $userName@vsphere.local on $vCenter..." -Log $logfile
            $user = New-SsoPersonUser -User $userName -Password $newPass
            if (Find-User($userName)) {
                Write-Log -Level "INFO" -Message "Account $user successfully created on $vCenter" -Log $logfile
                #### Add user to administrators group ####
                $adminGroup = Get-SsoGroup -Name "Administrators" -Domain "vsphere.local"
                Write-Log -Level "INFO" -Message "Adding $user to Administrators group..." -Log $logfile
                $user | Add-UserToSsoGroup -TargetGroup $adminGroup | Out-Null
                #### Verify user is in administrators group ####
                if (Find-UserInAdmin($userName)) {
                    Write-Log -Level "INFO" -Message "Account $user added to Administrator group" -Log $logfile
                } else {
                    Write-Log -Level "ERROR" -Message "Failed to add $user to Administrators group" -Log $logfile
                }
                #### Final verification of account creation and proper group additon ####
                Write-Log -Level "INFO" -Message "Validating account creation..." -Log $logfile
                $newConnection = Connect-SsoAdminServer -Server $vCenter -User $user -Password $newPass -SkipCertificateCheck
                if ($newConnection) {
                    Write-Log -Level "INFO" -Message "Authentication to $vCenter successful with new account credentials" -Log $logfile
                    Disconnect-SSoAdminServer -Server "*"
                } else {
                    Write-Log -Level "ERROR" -Message "Authenticaton to $vCenter failed with new account credentials" -Log $logfile
                    Write-Host "Failed to update credentials. Check logs for details" -ForegroundColor Red
                    Exit
                }
            } else {
            Write-Log -Level "ERROR" -Message "Account creation failed for '$userName'. User could not be found" -Log $logfile
            }  # if (Find-User($userName))
         } else {
            Write-Host "Could not connect to '$vCenter" -ForegroundColor Red
            Write-Log -Level "ERROR" -Message $Error -Log $logfile
        } # if ($connection.IsConnected)
    }  # foreach vCenter
    Write-Host "Credential update complete" -ForegroundColor Green
 } 

 # User inputs "7" #
if ($choice -eq "7") {
    Write-Host "`n---------------------"
    Write-Host "Current vCenters"
    Write-Host "---------------------`n"
    foreach ($vCenter in $global:vCenters) {
        Write-Host $vCenter
    }
}

} UNTIL ($choice -eq "8")
if ($global:DefaultVIServers) {
    Disconnect-VIServer -Server "*"
    Write-Log -Level "INFO" -Message "User $vcUsername exited module"
}  
Exit






