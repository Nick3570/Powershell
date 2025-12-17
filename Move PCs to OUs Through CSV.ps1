# Import the Active Directory module
Import-Module ActiveDirectory

# 1. DEFINE YOUR CSV PATH
$CsvFilePath = $env:filePath

# 2. DEFINE YOUR OU MAPPING
# This "Hashtable" maps the simple text in your Excel file to the complex AD paths.
# Format: "Excel Location Name" = "Distinguished Name of OU"
$OUMap = @{

    "Location 1" = "OU=Sales,OU=Computers,DC=contoso,DC=com"
    "Location 2" = "OU=Warehouse,OU=Computers,DC=contoso,DC=com"
    "Location 3" = "OU=HQ,OU=Computers,DC=contoso,DC=com"
}

# 3. IMPORT AND PROCESS DATA
$computerList = Import-Csv -Path $CsvFilePath

foreach ($row in $computerList) {
    $compName = $row.Device
    $location = $row.Organization
    
# Trim whitespace just in case the CSV has trailing spaces
    $trimmedName = $compName.Trim()

    # Skip if the computer name is empty
    if ([string]::IsNullOrWhiteSpace($trimmedName)) {
        continue 
    }

    # Check if the location exists in our map
    if ($OUMap.ContainsKey($location)) {
        $targetOU = $OUMap[$location]
        
        try {
            Write-Host "Processing '$trimmedName'..." -ForegroundColor White

            # Step A: Get the computer object first (Explicit Style)
            $adComputer = Get-ADComputer -Identity $trimmedName -ErrorAction Stop

            # Step B: Move the object using the variable
            # Remove -WhatIf below when you are ready to run it for real
            Move-ADObject -Identity $adComputer -TargetPath $targetOU -ErrorAction Stop

            Write-Host "SUCCESS: Moved '$trimmedName' to '$location'." -ForegroundColor Green
        }
        catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
            Write-Host "ERROR: Computer '$trimmedName' not found in Active Directory." -ForegroundColor Yellow
        }
        catch {
            Write-Host "ERROR: Failed to move '$trimmedName'." -ForegroundColor Red
            Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
        }
        finally {
            Write-Host "" # Add a blank line for readability
        }
    }
    else {
        Write-Warning "SKIPPING: '$trimmedName'. Location '$location' is not defined in the OU Map."
        Write-Host ""
    }
}
