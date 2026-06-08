#Requires -Version 5.1

<#
.SYNOPSIS
    Adds a shared network printer for all user profiles on this computer as a per-computer connection.
.DESCRIPTION
    Searches a hardcoded print server ("Print_Server_Name") for a partial printer name, then adds the
    found printer for all user profiles on this computer as a per-computer connection.
.EXAMPLE
    # The script is run manually, and it will automatically prompt the user to type in the printer name:
    .\Add-Printer.ps1
    
    # You can also run it and provide the partial name directly to bypass the prompt:
    .\Add-Printer.ps1 -PartialPrinterName 'Brother'

PARAMETER: -PartialPrinterName
    Specify the partial name of the printer you want to find on "Print_Server_Name". 
    If not provided, the script will prompt the user to enter it.

PARAMETER: -Restart
    A restart may be required for this script to take effect immediately.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 1.4
    Release Notes: Removed environmental variable dependency. Added mandatory user prompt for printer name.
#>

<#
.SYNOPSIS
    This script checks and configures the "Point and Print" registry settings
    to allow non-admin users to install printer drivers from a trusted server
    without a UAC prompt.

    MUST BE RUN AS AN ADMINISTRATOR.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [Switch]$Restart = [System.Convert]::ToBoolean($env:forceRestart),

    [Parameter(Mandatory=$true, HelpMessage="Please enter the partial name of the printer you want to find on Print_Server_Name.")]
    [String]$PartialPrinterName
)

begin {

    # --- Configuration ---
    $PrintServerName = "Print_Server_Name"
    # This variable will be populated by the lookup logic below
    [String]$PrinterSharePath = $null 
    
    # --- Find full $PrinterSharePath from partial name ---
    if ([string]::IsNullOrWhiteSpace($PartialPrinterName) -or $PartialPrinterName -like "null") {
        Write-Host "[Error] No partial printer name provided. Cannot search."
        exit 1
    }

    Write-Host "Partial name '$PartialPrinterName' provided. Searching '$PrintServerName' for full printer path."
    $FoundPrinters = $null

    try {
        # 1. Verify connection to the print server
        Write-Host "Verifying that the print server '$PrintServerName' is reachable via ping."
        Test-Connection -ComputerName $PrintServerName -Count 2 -ErrorAction Stop | Out-Null
        Write-Host "Print server '$PrintServerName' is reachable."

        # 2. Search for the printer
        $FoundPrinters = Get-Printer -ComputerName $PrintServerName -Name "*$PartialPrinterName*" -ErrorAction Stop
    }
    catch [Microsoft.Management.Infrastructure.CimException] {
        # Handle "no printers found" gracefully, as Get-Printer throws an error for this.
        if ($_.Exception.Message -like "*No printers found*") {
            $FoundPrinters = $null # Explicitly set to null to trigger the 'if ($null -eq $FoundPrinters)' block
        }
        else {
            # Different CIM error (e.g., RPC server unavailable)
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host "[Error] Could not contact print server '$PrintServerName'. Check name, network connection, and permissions."
            exit 1
        }
    }
    catch [System.Net.NetworkInformation.PingException] {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] The print server '$PrintServerName' is not reachable."
        exit 1
    }
    catch {
        # Catch-all for other errors
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] An unexpected error occurred while searching for printers on '$PrintServerName'."
        exit 1
    }

    # --- Handle Search Results ---
    if ($null -eq $FoundPrinters) {
        # Case 1: No printers found
        Write-Host "[Error] No printers found on $PrintServerName containing '$PartialPrinterName'."
        exit 1
    }
    elseif ($FoundPrinters.Count -gt 1) {
        # Case 2: Too many printers found
        Write-Host "[Error] Ambiguous name. Found $($FoundPrinters.Count) matching printers:"
        $FoundPrinters.Name | ForEach-Object { Write-Host "  - $_" }
        Write-Host "Please be more specific."
        exit 1
    }
    else {
        # Case 3: Exactly one printer found (Success!)
        Write-Host "Success: Found printer '$($FoundPrinters.Name)'."
        
        $PrinterShareName = $FoundPrinters.ShareName
        
        if ([string]::IsNullOrEmpty($PrinterShareName)) {
            Write-Host "[Error] Printer '$($FoundPrinters.Name)' was found, but it is not shared. Cannot connect."
            exit 1
        }
        else {
            # This is the key: We set $PrinterSharePath for the rest of the script to use
            $PrinterSharePath = "\\$PrintServerName\$PrinterShareName"
            Write-Host "Resolved partial name to full path: '$PrinterSharePath'"
        }
    }

    # --- Validation of the Discovered Path ---

    # Extract the server name from $PrinterSharePath.
    $Server = $PrinterSharePath -replace "\\[^\\]*$" -replace "^\\\\"
    if ($Server) {
        $Server = $Server.Trim()
    }
    
    # Check if $Server is empty; if so, display an error and exit.
    if (!$Server) {
        Write-Host -Object "[Error] The server specified in the path '$PrinterSharePath' is invalid."
        exit 1
    }

    # Extract the share name from $PrinterSharePath by removing the server name.
    $ShareName = $PrinterSharePath -replace "^\\\\$Server\\" -replace "\\$"
    if ($ShareName) {
        $ShareName = $ShareName.Trim()
    }

    # Check if $ShareName is empty; if so, display an error and exit.
    if (!$ShareName) {
        Write-Host -Object "[Error] The share name specified in the path '$PrinterSharePath' is invalid."
        exit 1
    }

    # Attempt to verify the printer share's existence;
    try {
        Write-Host -Object "Verifying '$PrinterSharePath' is a valid printer share."
        
        # Get printers currently installed on this local machine from that server
        $CurrentPrinterShares = Get-Printer -ErrorAction Stop | Where-Object { $_.Type -eq "Connection" -and $_.Shared -eq $True -and $_.ComputerName -eq $Server }
        
        # Get all shared printers from the remote server
        $AllPrinterShares = Get-Printer -ComputerName $Server -ErrorAction Stop | Where-Object { $_.Shared -eq $True }
    }
    catch {
        # Catch any errors while retrieving printer shares and display a relevant message.
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to retrieve shared printers from the device $Server."
        exit 1
    }

    # If no printer shares exist on the server, display an error.
    if (!$AllPrinterShares) {
        Write-Host -Object "[Error] The printer share '$ShareName' specified in the path '$PrinterSharePath' is invalid. No printer shares exist on $Server."
        exit 1
    }

    # If $ShareName is not present in $AllPrinterShares, display an error listing the current shares.
    if ($AllPrinterShares.ShareName -notcontains $ShareName) {
        Write-Host -Object "[Error] The printer share '$ShareName' specified in the path '$PrinterSharePath' is invalid. The printer share does not exist."
        Write-Host -Object "### Current Printer Shares on $Server ###"
        $AllPrinterShares | Format-Table ShareName, PortName, DriverName
        exit 1
    }

    # Check if a printer share with the specified $ShareName already exists in the current printer shares on this computer.
    if ($CurrentPrinterShares.ShareName -contains $ShareName) {
        Write-Host -Object "[Error] The printer share '$ShareName' specified in the path '$PrinterSharePath' is invalid. The printer share already exists on this computer."
        exit 1
    }

    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    if ($ExitCode) {
        $ExitCode = 0
    }
}
process {
    if (!(Test-IsElevated)) {
        Write-Host -Object "[Error] Access Denied. Please run with Administrator privileges."
        exit 1
    }
    
    # Log the operation being performed
    Write-Host -Object "Adding the printer '$PrinterSharePath' to the system account."

    # Try to add the printer connection
    try {
        # Add the printer connection using the specified share path.
        Add-Printer -ConnectionName $PrinterSharePath -ErrorAction Stop
    }
    catch {
        # Handle any errors that occur during add operation.
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to add the printer to the system account."
        exit 1
    }

    # Log the operation of adding the printer for all users.
    Write-Host -Object "Attempting to add the printer for all users."

    # Try to execute the global add command for the printer using rundll32.
    try {
        # Capture the start time of the script to track operation duration.
        $StartTime = Get-Date
        $ProcessTimeOut = 10
        
        # Set operation type to "/ga" (global add)
        $AddOrRemove = "/ga"

        # Start the process to add the printer for all users.
        $Process = Start-Process -FilePath "$env:SystemRoot\system32\rundll32.exe" -ArgumentList @(
            "printui.dll,", "PrintUIEntry", $AddOrRemove, "/n`"$PrinterSharePath`""
        ) -PassThru -NoNewWindow

        # Wait for the process to complete or timeout.
        while (!$Process.HasExited) {
            if ($StartTime.AddMinutes($ProcessTimeOut) -lt $(Get-Date)) {
                # Timeout reached; log an error and exit.
                Write-Host -Object "[Error] $ProcessTimeOut minute timeout reached. Failed to add the printer."
                exit 1
            }
            Start-Sleep -Milliseconds 100
        }
    }
    catch {
        # Handle any errors that occur during the rundll32 operation.
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to add the printer with the path '$PrinterSharePath'."
        exit 1
    }

    # Retrieve the printer driver for the specified printer.
    Write-Host -Object "Retrieving the printer driver."
    try {
        $ErrorActionPreference = "Stop"

        # Get the driver name for the specified printer.
        $PrinterDriverName = Get-Printer -ComputerName $Server | Where-Object { $_.ShareName -eq $ShareName } | Select-Object -ExpandProperty "DriverName"

        # Retrieve the full printer driver object by name.
        $PrinterDriver = Get-PrinterDriver -ComputerName $Server -Name $PrinterDriverName | Select-Object -First 1 | Select-Object -ExpandProperty "Name"
        $ErrorActionPreference = "Continue"
    }
    catch {
        # Handle errors that occur during printer driver retrieval.
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to retrieve the printer driver."
        exit 1
    }

    # Install the retrieved printer driver on the local system.
    Write-Host -Object "Installing the printer driver."
    try {
        Add-PrinterDriver -Name $PrinterDriver -ErrorAction Stop
    }
    catch {
        # Handle errors that occur during printer driver installation.
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to install the printer driver."
        exit 1
    }

    # Log successful installation of the printer driver.
    Write-Host -Object "Printer driver installed."

    # Restart the print spooler to apply the driver installation.
    Write-Host -Object "Restarting the print spooler."
    try {
        Restart-Service -Name Spooler -ErrorAction Stop
    }
    catch {
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to restart the print spooler."
        exit 1
    }

    # Schedule a system restart if the $Restart flag is set.
    if ($Restart) {
        # Set the restart time to one minute from now.
        $RestartDate = (Get-Date).AddMinutes(1)
        Write-Host -Object "Scheduling a restart for $($RestartDate.ToShortDateString()) at $($RestartDate.ToShortTimeString())."
        try {
            Start-Process shutdown.exe -ArgumentList "/r /t 60" -Wait -NoNewWindow
        }
        catch {
            # Handle errors that occur while scheduling the restart.
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to schedule restart."
            exit 1
        }
    }

    # Retrieve the current printer shares
    $CurrentPrinterShares = Get-Printer -ErrorAction Stop | Where-Object { $_.Type -eq "Connection" -and $_.Shared -eq $True -and $_.ComputerName -eq $Server -and $_.ShareName -eq $ShareName }

    # If the printer exists in the current printer shares (meaning it was successfully added), log a success message.
    if ($CurrentPrinterShares) {
        Write-Host -Object "The printer has been successfully added."
    }
    else {
        Write-Host -Object "[Error] The printer was not found. Failed to add the printer."
        exit 1
    }

    exit $ExitCode
}
end {
    
}
