<#
.SYNOPSIS
    Creates Exchange Online shared mailboxes, service account permissions,
    and validates the setup for the CQC Email Processor Logic App connectors.

.DESCRIPTION
    This script automates the Exchange Online prerequisites for the EMAIL-TRIGGER
    solution. It:
      1. Connects to Exchange Online
      2. Creates shared mailboxes (inbound + sender) if they don't exist
      3. Grants FullAccess and SendAs permissions to the service account
      4. Optionally enables sent-message copy on the sender mailbox
      5. Validates all permissions

    After running this script, you still need to manually authorize the Logic App
    Office 365 Outlook connectors in the Azure Portal (one-time OAuth sign-in).

.PARAMETER ConfigPath
    Path to deploy.config.toml

.PARAMETER AdminUpn
    UPN of the Exchange admin performing the setup (used for Connect-ExchangeOnline)

.PARAMETER SkipConnect
    Skip Connect-ExchangeOnline if you are already connected in this session

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File "deploy/deploy-exchange.ps1" `
        -ConfigPath "deploy/deploy.config.toml" `
        -AdminUpn "admin@yourdomain.com"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $false)]
    [string]$AdminUpn,

    [switch]$SkipConnect
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Config parser (minimal TOML reader — same pattern as other deploy scripts)
# ---------------------------------------------------------------------------
function Read-TomlConfig {
    param([string]$Path)
    $config = @{}
    $section = ""
    foreach ($line in (Get-Content $Path)) {
        $line = $line.Trim()
        if ($line -match '^\[(.+)\]$') {
            $section = $Matches[1]
            if (-not $config.ContainsKey($section)) { $config[$section] = @{} }
        }
        elseif ($line -match '^(\w+)\s*=\s*"(.*)"$') {
            $config[$section][$Matches[1]] = $Matches[2]
        }
        elseif ($line -match '^(\w+)\s*=\s*(.+)$') {
            $val = $Matches[2].Trim()
            if ($val -eq "true") { $val = $true }
            elseif ($val -eq "false") { $val = $false }
            $config[$section][$Matches[1]] = $val
        }
    }
    return $config
}

# ---------------------------------------------------------------------------
# Load config
# ---------------------------------------------------------------------------
Write-Host "`n=== CQC Email Processor — Exchange Online Setup ===" -ForegroundColor Cyan

$cfg = Read-TomlConfig -Path $ConfigPath
$mailbox = $cfg["mailbox"]

$inboundMailbox     = $mailbox["target_shared_mailbox"]
$senderMailbox      = $mailbox["missing_info_sender_mailbox"]
$rejectionMailbox   = $mailbox["rejection_sender_mailbox"]
$connectorUpn       = $mailbox["logic_app_connector_identity_upn"]

if (-not $inboundMailbox)   { throw "mailbox.target_shared_mailbox is required in config" }
if (-not $senderMailbox)    { throw "mailbox.missing_info_sender_mailbox is required in config" }
if (-not $connectorUpn)     { throw "mailbox.logic_app_connector_identity_upn is required in config" }

# Default rejection mailbox to sender mailbox if not set separately
if (-not $rejectionMailbox) { $rejectionMailbox = $senderMailbox }

Write-Host "  Inbound mailbox    : $inboundMailbox"
Write-Host "  Sender mailbox     : $senderMailbox"
if ($rejectionMailbox -ne $senderMailbox) {
    Write-Host "  Rejection mailbox  : $rejectionMailbox"
}
Write-Host "  Connector identity : $connectorUpn"

# ---------------------------------------------------------------------------
# Step 1 — Ensure ExchangeOnlineManagement module is installed
# ---------------------------------------------------------------------------
Write-Host "`n[1/5] Checking ExchangeOnlineManagement module..." -ForegroundColor Yellow

if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Host "  Installing ExchangeOnlineManagement module..."
    Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber
}
Import-Module ExchangeOnlineManagement -ErrorAction Stop
Write-Host "  Module loaded." -ForegroundColor Green

# ---------------------------------------------------------------------------
# Step 2 — Connect to Exchange Online
# ---------------------------------------------------------------------------
Write-Host "`n[2/5] Connecting to Exchange Online..." -ForegroundColor Yellow

if (-not $SkipConnect) {
    if ($AdminUpn) {
        Connect-ExchangeOnline -UserPrincipalName $AdminUpn -ShowBanner:$false
    } else {
        Connect-ExchangeOnline -ShowBanner:$false
    }
    Write-Host "  Connected." -ForegroundColor Green
} else {
    Write-Host "  Skipped (using existing session)." -ForegroundColor DarkYellow
}

# ---------------------------------------------------------------------------
# Step 3 — Create shared mailboxes if they don't exist
# ---------------------------------------------------------------------------
Write-Host "`n[3/5] Creating shared mailboxes..." -ForegroundColor Yellow

function Ensure-SharedMailbox {
    param([string]$Address, [string]$DisplayName)
    $existing = Get-Mailbox -Identity $Address -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "  ✓ Already exists: $Address" -ForegroundColor Green
    } else {
        $namePart = $Address.Split("@")[0]
        Write-Host "  Creating shared mailbox: $Address ..."
        New-Mailbox -Shared `
            -Name $namePart `
            -DisplayName $DisplayName `
            -PrimarySmtpAddress $Address
        Write-Host "  ✓ Created: $Address" -ForegroundColor Green
    }
}

$inboundName = ($inboundMailbox.Split("@")[0]).Replace("-", " ").Replace(".", " ")
Ensure-SharedMailbox -Address $inboundMailbox -DisplayName "CQC Email ($inboundName)"

$senderName = ($senderMailbox.Split("@")[0]).Replace("-", " ").Replace(".", " ")
Ensure-SharedMailbox -Address $senderMailbox -DisplayName "CQC NoReply ($senderName)"

if ($rejectionMailbox -ne $senderMailbox) {
    $rejName = ($rejectionMailbox.Split("@")[0]).Replace("-", " ").Replace(".", " ")
    Ensure-SharedMailbox -Address $rejectionMailbox -DisplayName "CQC Rejection ($rejName)"
}

# Enable sent-message copy on sender mailbox
Write-Host "  Enabling sent-message copy on $senderMailbox ..."
Set-Mailbox -Identity $senderMailbox `
    -MessageCopyForSentAsEnabled $true `
    -MessageCopyForSendOnBehalfEnabled $true

# ---------------------------------------------------------------------------
# Step 4 — Grant permissions to the connector service account
# ---------------------------------------------------------------------------
Write-Host "`n[4/5] Granting mailbox permissions to $connectorUpn ..." -ForegroundColor Yellow

# FullAccess on inbound mailbox
$existingFull = Get-MailboxPermission -Identity $inboundMailbox |
    Where-Object { $_.User -like "*$connectorUpn*" -and $_.AccessRights -contains "FullAccess" }
if ($existingFull) {
    Write-Host "  ✓ FullAccess already granted on $inboundMailbox" -ForegroundColor Green
} else {
    Write-Host "  Granting FullAccess on $inboundMailbox ..."
    Add-MailboxPermission `
        -Identity $inboundMailbox `
        -User $connectorUpn `
        -AccessRights FullAccess `
        -AutoMapping $false
    Write-Host "  ✓ FullAccess granted." -ForegroundColor Green
}

# SendAs on sender mailbox
$existingSendAs = Get-RecipientPermission -Identity $senderMailbox |
    Where-Object { $_.Trustee -like "*$connectorUpn*" -and $_.AccessRights -contains "SendAs" }
if ($existingSendAs) {
    Write-Host "  ✓ SendAs already granted on $senderMailbox" -ForegroundColor Green
} else {
    Write-Host "  Granting SendAs on $senderMailbox ..."
    Add-RecipientPermission `
        -Identity $senderMailbox `
        -Trustee $connectorUpn `
        -AccessRights SendAs `
        -Confirm:$false
    Write-Host "  ✓ SendAs granted." -ForegroundColor Green
}

# SendAs on rejection mailbox (if different from sender)
if ($rejectionMailbox -ne $senderMailbox) {
    $existingRejSendAs = Get-RecipientPermission -Identity $rejectionMailbox |
        Where-Object { $_.Trustee -like "*$connectorUpn*" -and $_.AccessRights -contains "SendAs" }
    if ($existingRejSendAs) {
        Write-Host "  ✓ SendAs already granted on $rejectionMailbox" -ForegroundColor Green
    } else {
        Write-Host "  Granting SendAs on $rejectionMailbox ..."
        Add-RecipientPermission `
            -Identity $rejectionMailbox `
            -Trustee $connectorUpn `
            -AccessRights SendAs `
            -Confirm:$false
        Write-Host "  ✓ SendAs granted." -ForegroundColor Green
    }
}

# ---------------------------------------------------------------------------
# Step 5 — Validate permissions
# ---------------------------------------------------------------------------
Write-Host "`n[5/5] Validating permissions..." -ForegroundColor Yellow

Write-Host "`n  --- FullAccess on $inboundMailbox ---"
Get-MailboxPermission -Identity $inboundMailbox |
    Where-Object { $_.User -like "*$connectorUpn*" } |
    Format-Table User, AccessRights -AutoSize

Write-Host "  --- SendAs on $senderMailbox ---"
Get-RecipientPermission -Identity $senderMailbox |
    Where-Object { $_.Trustee -like "*$connectorUpn*" } |
    Format-Table Trustee, AccessRights -AutoSize

if ($rejectionMailbox -ne $senderMailbox) {
    Write-Host "  --- SendAs on $rejectionMailbox ---"
    Get-RecipientPermission -Identity $rejectionMailbox |
        Where-Object { $_.Trustee -like "*$connectorUpn*" } |
        Format-Table Trustee, AccessRights -AutoSize
}

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
Write-Host "`n=== Exchange Online setup complete ===" -ForegroundColor Cyan
Write-Host @"

IMPORTANT — MANUAL STEP REQUIRED:
  Delegated mailbox permissions can take up to 2 hours to replicate.
  After propagation, open each Logic App in the Azure Portal and authorize
  the Office 365 Outlook connector by signing in with:

      $connectorUpn

  This is a one-time OAuth consent. After that, the pipeline runs
  fully programmatically with no human interaction.

  Logic Apps that need connector authorization:
    - Prefilter       (trigger: When a new email arrives in shared mailbox)
    - Missing Info    (action:  Send an email from shared mailbox)
    - Rejection       (action:  Send an email from shared mailbox)
    - Reply Monitor   (trigger: When a new email arrives in shared mailbox)

"@ -ForegroundColor Yellow

Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "Disconnected from Exchange Online.`n"
