Get-ADGroupMember -Identity "Security Group Name" -Recursive | Get-ADUser -Properties SamAccountName -ErrorAction Ignore | Where-Object {$_.Enabled -eq $True} | Select SamAccountName, Name
