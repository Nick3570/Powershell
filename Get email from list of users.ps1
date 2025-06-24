Get-Content "C:\Path\users.txt" | ForEach-Object {
>>     $currentDisplayName = $_
>>     $filterQuery = "DisplayName -eq '$currentDisplayName'"
>>     $propertiesToGet = @("DisplayName", "Mail")
>>
>>     Get-ADUser -Filter $filterQuery -Properties $propertiesToGet -ErrorAction SilentlyContinue
>> } | Select-Object DisplayName, Mail | Export-Csv -Path "C:\Path\users and emails.csv" -NoTypeInformation
