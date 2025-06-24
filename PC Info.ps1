Get-ADComputer -Filter “Name -like ‘PCName*’” -Properties * | Select-Object Name, SamAccountName, LastLogonDate, Created, IPv4Address, OperatingSystem
