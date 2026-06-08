  # --- CONFIGURATION ---
# Set your trusted print server name here
$TrustedServer = "Print_Server_Name"
# ---------------------

# Define the registry path
$RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint"

# Define the 5 required registry values and their desired state
$RequiredValues = @{
    "RestrictDriverInstallationToAdministrators" = @{ Value = 0; Type = "DWORD" }
    "NoWarningNoElevationOnInstall" = @{ Value = 1; Type = "DWORD" }
    "UpdatePromptSettings" = @{ Value = 2; Type = "DWORD" }
    "Restricted" = @{ Value = 1; Type = "DWORD" }
    "ServerList" = @{ Value = $TrustedServer; Type = "String" }
}

# --- SCRIPT ---

# 1. Check for Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script must be run as Administrator."
    Write-Warning "Please re-run this script in an elevated PowerShell session."
    Start-Sleep -Seconds 10
    return
}

Write-Host "Running with Administrator privileges."

# 2. Check if the registry path exists. If not, create it.
if (-not (Test-Path $RegistryPath)) {
    Write-Warning "Registry path $RegistryPath not found. Creating it..."
    try {
        New-Item -Path $RegistryPath -Force -ErrorAction Stop | Out-Null
        Write-Host "Successfully created registry path."
    } catch {
        Write-Error "Failed to create registry path: $($_.Exception.Message)"
        return
    }
}

# 3. Loop through each required value, check it, and set it if incorrect.
Write-Host "Checking Point and Print registry settings..."

foreach ($Name in $RequiredValues.Keys) {
    $DesiredValue = $RequiredValues[$Name].Value
    $DesiredType  = $RequiredValues[$Name].Type
    $CurrentValue = $null

    try {
        # Try to get the current value
        $CurrentValue = (Get-ItemProperty -Path $RegistryPath -Name $Name -ErrorAction Stop).$Name
    } catch {
        # This means the value does not exist
        $CurrentValue = $null
    }

    # Compare current value to desired value
    if ($CurrentValue -eq $DesiredValue) {
        Write-Host "  [OK] '$Name' is already set to '$DesiredValue'."
    } else {
        # If it's not correct, or if it was $null (doesn't exist)
        Write-Host "  [FIXING] '$Name' is set to '$CurrentValue'. Setting to '$DesiredValue'..."
        try {
            Set-ItemProperty -Path $RegistryPath -Name $Name -Value $DesiredValue -Type $DesiredType -Force -ErrorAction Stop
        } catch {
            Write-Error "Failed to set '$Name': $($_.Exception.Message)"
        }
    }
}

Write-Host ""
Write-Host "Registry settings have been applied." -ForegroundColor Green
Write-Host ""

# 4. Restart the Print Spooler service to apply the changes
Write-Host "Restarting the Print Spooler service..."
try {
    Restart-Service -Name "Spooler" -Force -ErrorAction Stop
    Write-Host "Print Spooler service restarted successfully. Changes are now active." -ForegroundColor Green
} catch {
    Write-Warning "Failed to restart the Print Spooler service."
    Write-Warning "You must restart the computer for changes to take effect."
}
