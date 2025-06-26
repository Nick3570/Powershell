<#
.SYNOPSIS
    Moves a list of Active Directory computer objects to a specified OU.

.DESCRIPTION
    This script reads a list of computer names and moves each corresponding
    computer object in Active Directory to a designated target Organizational Unit (OU).
    It provides feedback for each successful move and reports errors if a
    computer cannot be found or moved.

.NOTES
    Author:      Your Name
    Date:        June 13, 2025
    Version:     1.2

    Prerequisites:
    1. The Active Directory module for PowerShell must be installed on the machine running this script.
       (This is part of the Remote Server Administration Tools - RSAT).
    2. You must run this script with an account that has permissions to move computer objects
       in both the source and destination OUs.

.EXAMPLE
    .\Move-ADComputers.ps1
    (After configuring the variables within the script)
#>

#requires -module ActiveDirectory

# --- CONFIGURATION ---
# Option 1: Manually list the computer names here.
# $computerList = @(
#     "PC001",
#     "LAPTOP-FINANCE",
#     "SRV-TEMP-03"
# )

# Option 2: Read computer names from a text file (recommended for long lists).
# Ensure the text file has one computer name per line.
$computerListPath = "C:\Path\PCList.txt" # <-- IMPORTANT: Update this path
if (-not (Test-Path $computerListPath)) {
    Write-Host "Error: The specified computer list file does not exist at '$computerListPath'." -ForegroundColor Red
    # Create a dummy file to prevent further errors and show the user what's needed.
    "COMPUTER1`nCOMPUTER2" | Out-File -FilePath $computerListPath
    Write-Host "A sample file has been created. Please edit it and run the script again." -ForegroundColor Yellow
    return
}
$computerList = Get-Content -Path $computerListPath

# Specify the Distinguished Name (DN) of the target OU where you want to move the computers.
# To get the DN:
# 1. Open "Active Directory Users and Computers".
# 2. Enable "Advanced Features" under the "View" menu.
# 3. Right-click the target OU, go to "Properties", and then the "Attribute Editor" tab.
# 4. Find the "distinguishedName" attribute and copy its value.
$targetOU = "OU=Organizational Unit,DC=domain,DC=controller" # <-- IMPORTANT: Update this with your target OU's DN.


# --- SCRIPT LOGIC ---

# Get and display the current domain context to confirm where the script is searching
try {
    $currentDomain = (Get-ADDomain).DNSRoot
    Write-Host "Script is running in domain: $currentDomain" -ForegroundColor Cyan
}
catch {
    Write-Host "ERROR: Could not determine the current Active Directory domain. Please ensure you are on a domain-joined machine and the AD module is working." -ForegroundColor Red
    return # Stop the script if the domain can't be identified
}

Write-Host "Starting the process to move computer objects..." -ForegroundColor Cyan
Write-Host "Target OU: $targetOU" -ForegroundColor Cyan
Write-Host "--------------------------------------------------"

# Loop through each computer name in the list
foreach ($computerName in $computerList) {
    # Trim any whitespace just in case
    $trimmedName = $computerName.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmedName)) {
        continue # Skip empty lines in the file
    }

    try {
        # Check if the computer object exists in Active Directory
        Write-Host "Processing '$trimmedName'..." -ForegroundColor White

        $adComputer = Get-ADComputer -Identity $trimmedName -ErrorAction Stop

        # If the computer is found, move it to the target OU
        Move-ADObject -Identity $adComputer -TargetPath $targetOU
        
        Write-Host "Successfully moved '$trimmedName' to the target OU." -ForegroundColor Green
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        # This error specifically means the computer object was not found
        Write-Host "ERROR: Computer '$trimmedName' not found in Active Directory. Skipping." -ForegroundColor Yellow
    }
    catch {
        # Catch any other errors (e.g., permissions, target OU not found)
        Write-Host "ERROR: An unexpected error occurred while processing '$trimmedName'." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        Write-Host "" # Add a blank line for better readability
    }
}
