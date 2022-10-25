# Name: Get-HostInfo.ps1
# Author: Austin Van Camp
# Postion: Systems Engineer III
# Last Modified: 10/24/22

$vcUsername = Read-Host "`nEnter Username"
$vcPassword = Read-Host "Enter Password" -AsSecureString
$vcCredential = New-Object System.Management.Automation.PSCredential ($vcUsername, $vcPassword)

$lvcUsername = Read-Host "`nEnter Legacy Username"
$lvcPassword = Read-Host "Enter Legacy Password" -AsSecureString
$lvcCredential = New-Object System.Management.Automation.PSCredential ($lvcUsername, $lvcPassword)

$vCenters = @(
    "austx01-vcsv-01.texas.rr.com"
    "bhdcal01-pvcsa01.cloud.charter.com"
    "chdcnc01-pvcsa01.cloud.charter.com"
    "chdcnc01-pvcsa02.cloud.charter.com"
    "chdcnc03-pvcsa03.cloud.charter.com"
    "vcenter01chdcnc.chdc.nc.charter.com"
    "chrcnc01-vcsv-01.chrcnc.twc.net"
    "codcoh01-pvcsa01.cloud.charter.com"
    "clboh01-vcsv-01.ohiordc.rr.com"
    "cdptpa03-vcsv-01.cdptpa.rr.com"
    "cdptpabb04-S-vcsa01.stage.charter.com"
    "cdptpabb04-svcsa01.cloud.stage.charter.com"
    "dldctx01-pvcsa01.cloud.charter.com"
    "pvdcco05-pvcsa01.cloud.charter.com"
    "pvdcco05-pvcsa02.cloud.charter.com"
    "pvdcco06-pvcsa03.cloud.charter.com"
    "vcenter01pvdcco.pvdc.co.charter.com"
    "dnvrco01-vcsv-01.peakview.rr.com"
    "dnvrco02-vcsv-01.cloud.twc.net"
    "dnvrco03-vcsv-01.dnvrco.twc.net"
    "ncw-stg-vcsv-01.cloud.twc.net"
    "edprmn01-pvcsa01.cloud.charter.com"
    "midchi01-pvcsa01.cloud.charter.com"
    "vcenter01midchi.midc.hi.charter.com"
    "milnhi01-vcsv-01.cloud.twc.net"
    "knwdmi01-pvcsa01.cloud.charter.com"
    "ladcca01-pvcsa01.cloud.charter.com"
    "mddcwi01-pvcsa01.cloud.charter.com"
    "nvdctn01-pvcsa01.cloud.charter.com"
    "nydcny01-pvcsa01.cloud.charter.com"
    "nycmny01-vcsv-01.rdc-nyc.rr.com"
    "orldfl71-pvcsa01.cloud.charter.com"
    "orld71pvc1.bhn.net"
    "pldcor01-pvcsa01.cloud.charter.com"
    "rlghnc01-vcsv-01.southeast.rr.com"
    "renonv01-pvcsa01.cloud.charter.com"
    "vmc01renonv.reno.nv.charter.com"
    "sldcla01-pvcsa01.cloud.charter.com"
    "spdcsc01-pvcsa01.cloud.charter.com"
    "sldcmo01-pvcsa01.cloud.charter.com"
    "sydcny01-pvcsa01.cloud.charter.com"
    "syrny01-vcsv-01.nyroc.rr.com"
    "tpdcfl01-pvcsa01.cloud.charter.com"
    "tamp20pvc1.bhn.net"
    )

$vCenterLocation = @{
    "austx01-vcsv-01.texas.rr.com" = "Austin"
    "bhdcal01-pvcsa01.cloud.charter.com" = "Birmingham"
    "chdcnc01-pvcsa01.cloud.charter.com" = "Charlotte, Pod 1"
    "chdcnc01-pvcsa02.cloud.charter.com" = "Charlotte, Pod 2"
    "chdcnc03-pvcsa03.cloud.charter.com" = "Charlotte, Pod 3"
    "vcenter01chdcnc.chdc.nc.charter.com" = "Charlotte, LCHR"
    "chrcnc01-vcsv-01.chrcnc.twc.net" = "Charlotte, LTWC"
    "codcoh01-pvcsa01.cloud.charter.com" = "Columbus"
    "clboh01-vcsv-01.ohiordc.rr.com" = "Columbus, LTWC"
    "cdptpa03-vcsv-01.cdptpa.rr.com" = "Coudersport, Prod"
    "cdptpabb04-S-vcsa01.stage.charter.com" = "Stamp, NDC1"
    "cdptpabb04-svcsa01.cloud.stage.charter.com" = "Stamp, cDVR"
    "dldctx01-pvcsa01.cloud.charter.com" = "Dallas"
    "pvdcco05-pvcsa01.cloud.charter.com" = "Peakview, Pod 1"
    "pvdcco05-pvcsa02.cloud.charter.com" = "Peakview, Pod 2"
    "pvdcco06-pvcsa03.cloud.charter.com" = "Peakview, Pod 3"
    "vcenter01pvdcco.pvdc.co.charter.com" = "Peakview, LCHR"
    "edprmn01-pvcsa01.cloud.charter.com" = "Eden Prairie"
    "midchi01-pvcsa01.cloud.charter.com" = "Hawaii, Honolulu"
    "vcenter01midchi.midc.hi.charter.com" = "Hawaii, Honolulu, LCHR"
    "milnhi01-vcsv-01.cloud.twc.net" = "Hawaii, Mililani"
    "knwdmi01-pvcsa01.cloud.charter.com" = "Kentwood"
    "ladcca01-pvcsa01.cloud.charter.com" = "Los Angeles, Irvine"
    "mddcwi01-pvcsa01.cloud.charter.com" = "Madison"
    "nvdctn01-pvcsa01.cloud.charter.com" = "Nashville"
    "nydcny01-pvcsa01.cloud.charter.com" = "New York"
    "nycmny01-vcsv-01.rdc-nyc.rr.com" = "New York, LTWC"
    "orldfl71-pvcsa01.cloud.charter.com" = "Orlando"
    "orld71pvc1.bhn.net" = "Orlando, LBHN"
    "pldcor01-pvcsa01.cloud.charter.com" = "Portland"
    "rlghnc01-vcsv-01.southeast.rr.com" = "Raleigh"
    "renonv01-pvcsa01.cloud.charter.com" = "Reno"
    "vmc01renonv.reno.nv.charter.com" = "Reno, LCHR"
    "sldcla01-pvcsa01.cloud.charter.com" = "Slidell"
    "spdcsc01-pvcsa01.cloud.charter.com" = "Spartanburg"
    "sldcmo01-pvcsa01.cloud.charter.com" = "St. Louis"
    "sydcny01-pvcsa01.cloud.charter.com" = "Syracuse"
    "syrny01-vcsv-01.nyroc.rr.com" = "Syracuse, LTWC"
    "tpdcfl01-pvcsa01.cloud.charter.com" = "Tampa"
    "tamp20pvc1.bhn.net" = "Tampa, LBHN"
}

$clliList = @{
    "austx01-vcsv-01.texas.rr.com" = "	AUSDTXIR"
    "bhdcal01-pvcsa01.cloud.charter.com" = "HMWDAL23"
    "chdcnc01-pvcsa01.cloud.charter.com" = "CHRCNCTR"
    "chdcnc01-pvcsa02.cloud.charter.com" = "CHRCNCTR"
    "chdcnc03-pvcsa03.cloud.charter.com" = "CHRCNCTR"
    "vcenter01chdcnc.chdc.nc.charter.com" = "CHRCNCTR"
    "chrcnc01-vcsv-01.chrcnc.twc.net" = "CHRCNCTR"
    "codcoh01-pvcsa01.cloud.charter.com" = "CLMKOHPE"
    "clboh01-vcsv-01.ohiordc.rr.com" = "CLMKOHPE"
    "cdptpa03-vcsv-01.cdptpa.rr.com" = "CDPTPABB"
    "cdptpabb04-S-vcsa01.stage.charter.com" = "CDPTPABB"
    "cdptpabb04-svcsa01.cloud.stage.charter.com" = "CDPTPABB"
    "dldctx01-pvcsa01.cloud.charter.com" = "DLLSTX13"
    "pvdcco05-pvcsa01.cloud.charter.com" = "ENWDCOCD"
    "pvdcco05-pvcsa02.cloud.charter.com" = "ENWDCOCD"
    "pvdcco06-pvcsa03.cloud.charter.com" = "ENWDCOCD"
    "vcenter01pvdcco.pvdc.co.charter.com" = "ENWDCOCD"
    "edprmn01-pvcsa01.cloud.charter.com" = "EDPRMNPI"
    "midchi01-pvcsa01.cloud.charter.com" = "HNLLHIQE"
    "vcenter01midchi.midc.hi.charter.com" = "HNLLHIQE"
    "milnhi01-vcsv-01.cloud.twc.net" = "MILNHIXD"
    "knwdmi01-pvcsa01.cloud.charter.com" = "GDRSMIUK"
    "ladcca01-pvcsa01.cloud.charter.com" = "IRVOCAFL"
    "mddcwi01-pvcsa01.cloud.charter.com" = "MDSNWIQI"
    "nvdctn01-pvcsa01.cloud.charter.com" = "NSVLTNUS"
    "nydcny01-pvcsa01.cloud.charter.com" = "NYCMNYWI"
    "nycmny01-vcsv-01.rdc-nyc.rr.com" = "NYCMNYWI"
    "orldfl71-pvcsa01.cloud.charter.com" = "ORLHFLQR"
    "orld71pvc1.bhn.net" = "ORLHFLQR"
    "pldcor01-pvcsa01.cloud.charter.com" = "HLBOORCH"
    "rlghnc01-vcsv-01.southeast.rr.com" = "DRHMNCEV"
    "renonv01-pvcsa01.cloud.charter.com" = "RENPNVMW"
    "vmc01renonv.reno.nv.charter.com" = "RENPNVMW"
    "sldcla01-pvcsa01.cloud.charter.com" = "SLIDLAIA"
    "spdcsc01-pvcsa01.cloud.charter.com" = "SPBGSCFE"
    "sldcmo01-pvcsa01.cloud.charter.com" = "STLSMOGZ"
    "sydcny01-pvcsa01.cloud.charter.com" = "ESYRNYAW"
    "syrny01-vcsv-01.nyroc.rr.com" = "ESYRNYAW"
    "tpdcfl01-pvcsa01.cloud.charter.com" = "TAMQFLPM"
    "tamp20pvc1.bhn.net" = "TAMQFLPM"

}

# Not included:
# Boston: bodcma01-pvcsa01.cloud.charter.com (Can't hit)
# Birmingham Legacy: vcenter01hbdcal.bhdc.al.charter.com (FQDN is weird)
# Peakview Legacy: dnvrco-vcsrv-01.peakview.rr.com (Bad creds)
# Stamp: cdpstamp-svcsa01.stamp.stage.charter.com

$hosts = @()

foreach ($vCenter in $vCenters) {
    $connection = Connect-VIServer -Server $vCenter -Cred $vcCredential 

    if ($connection) {
    } elseif ($null -eq $connection) {
        Connect-VIServer -Server $vCenter -Cred $lvcCredential
    } else { 
        Write-Host "`nCould not connect to $vCenter. Skipping" -ForegroundColor Red
        continue
    }

    if ($connection) {
        Write-Host "Connected to $vCenter" -ForegroundColor Green
    } else {
        Write-Host "'Not connected to a vCenter. Exiting..." -ForegroundColor Red
        Exit
    }

    $vmHosts = Get-VMHost
    $location = $vCenterLocation.GetEnumerator() | Where-Object{$_.Name -eq $vCenter}
    $clli = $clliList.GetEnumerator() | Where-Object{$_.Name -eq $vCenter} 
    foreach ($vmHost in $vmHosts) {
        $hostInfo = Get-VMHost $vmHost | Select-Object Name,@{n="Cluster"; e={$_.Parent}},@{n="ManagementIP"; e={Get-VMHostNetworkAdapter -VMHost $_ -VMKernel | Where-Object{$_.ManagementTrafficEnabled} | ForEach-Object{$_.Ip}}}, Manufacturer, Model | Add-Member -NotePropertyName "Location" -NotePropertyValue $location.Value -PassThru | Add-Member -NotePropertyName "CLLI" $clli.Value -PassThru
        $hosts += $hostInfo
    }
    Write-Host "Disconnecting from $vCenter" -ForegroundColor Yellow
    Disconnect-VIServer -Force -Confirm:$False
}

$hosts | Export-Csv -Path ./hostResults.csv -UseCulture -Confirm:$false -Append