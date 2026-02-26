#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Bootstrap Hyper-V host per Splunk Attack Range locale.
  Crea vSwitch, NetNAT e route necessari. Da eseguire UNA SOLA VOLTA.
.PARAMETER ExternalInterfaceAlias
  Alias della scheda di rete fisica con accesso a Internet (es. 'Wi-Fi', 'Ethernet').
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$ExternalInterfaceAlias,
    [string]$WanSwitchName   = 'CR-WAN',
    [string]$MgmtSwitchName  = 'CR-MGMT',
    [string]$Ips1SwitchName  = 'CR-IPS1',
    [string]$Ips2SwitchName  = 'CR-IPS2',
    [string]$WanHostIP       = '10.10.10.1',
    [string]$MgmtHostIP      = '172.16.100.2',
    [string]$NatName         = 'AR-NAT',
    [string]$NatPrefix       = '10.10.10.0/24'
)
$ErrorActionPreference = 'Stop'
function Write-Step($m) { Write-Host "[+] $m" -ForegroundColor Cyan }
function Write-Skip($m) { Write-Host "[=] $m (already exists)" -ForegroundColor DarkGray }

# Hyper-V feature
$feat = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V
if ($feat.State -ne 'Enabled') {
    Write-Step 'Enabling Hyper-V...'
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart | Out-Null
    Write-Warning 'Reboot required after Hyper-V enable. Run this script again after reboot.'
    exit 0
} else { Write-Skip 'Hyper-V' }

# vSwitches
foreach ($sw in @($WanSwitchName, $MgmtSwitchName, $Ips1SwitchName, $Ips2SwitchName)) {
    if (-not (Get-VMSwitch -Name $sw -EA SilentlyContinue)) {
        Write-Step "Creating internal vSwitch: $sw"
        New-VMSwitch -Name $sw -SwitchType Internal | Out-Null
    } else { Write-Skip "vSwitch $sw" }
}

# Host vNIC IPs
function Set-HostNicIP($sw, $ip, $pfx) {
    $alias = "vEthernet ($sw)"
    $ex = Get-NetIPAddress -InterfaceAlias $alias -AddressFamily IPv4 -EA SilentlyContinue | Where-Object { $_.IPAddress -eq $ip }
    if (-not $ex) {
        Write-Step "Setting $ip/$pfx on $alias"
        Get-NetIPAddress -InterfaceAlias $alias -AddressFamily IPv4 -EA SilentlyContinue |
            Remove-NetIPAddress -Confirm:$false -EA SilentlyContinue
        New-NetIPAddress -InterfaceAlias $alias -IPAddress $ip -PrefixLength $pfx | Out-Null
    } else { Write-Skip "$ip on $alias" }
}
Set-HostNicIP $WanSwitchName  $WanHostIP  24
Set-HostNicIP $MgmtSwitchName $MgmtHostIP 24

# NetNAT
if (-not (Get-NetNat -Name $NatName -EA SilentlyContinue)) {
    Write-Step "Creating NetNat $NatName ($NatPrefix)"
    New-NetNat -Name $NatName -InternalIPInterfaceAddressPrefix $NatPrefix | Out-Null
} else { Write-Skip "NetNat $NatName" }

# Route host -> targets subnet via router
$dest  = '172.16.101.0/24'
$gw    = '172.16.100.1'
$alias = "vEthernet ($MgmtSwitchName)"
$rt = Get-NetRoute -DestinationPrefix $dest -EA SilentlyContinue | Where-Object { $_.NextHop -eq $gw }
if (-not $rt) {
    Write-Step "Adding route $dest via $gw"
    New-NetRoute -DestinationPrefix $dest -InterfaceAlias $alias -NextHop $gw -RouteMetric 10 | Out-Null
} else { Write-Skip "Route $dest" }

# Prerequisiti software
$tools = @{
    'Vagrant'   = { winget install Hashicorp.Vagrant   --accept-source-agreements --accept-package-agreements -e }
    'Terraform' = { winget install Hashicorp.Terraform --accept-source-agreements --accept-package-agreements -e }
    'Packer'    = { winget install Hashicorp.Packer    --accept-source-agreements --accept-package-agreements -e }
}
foreach ($tool in $tools.GetEnumerator()) {
    if (-not (Get-Command $tool.Key.ToLower() -EA SilentlyContinue)) {
        Write-Step "Installing $($tool.Key)..."
        & $tool.Value
    } else { Write-Skip $tool.Key }
}

Write-Host "
[OK] Bootstrap completato.
     Prossimo passo: python attack_range.py build -t splunk_ad_hyperv
" -ForegroundColor Green
