$computerlist = Get-Content -Path "C:\Path\computer list.txt"
$computerlist | ForEach-Object {Get-ADComputer -Identity $_ -Properties OperatingSystem | Select-Object Name, OperatingSystem }
