$users = Get-Content -Path "C:\Path\users.txt"
$users | ForEach-Object {
>>     $fullNameFromList = $_
>>     $nameParts = $fullNameFromList.Split(' ', 2) # Split into FirstName and LastName (max 2 parts on first space)
>>
>>     if ($nameParts.Length -eq 2) {
>>         $firstName = $nameParts[0]
>>         $lastName = $nameParts[1]
>>
>>         # Escape single quotes in names for the AD filter (e.g., O'Malley -> O''Malley)
>>         $escFirstName = $firstName.Replace("'", "''")
>>         $escLastName = $lastName.Replace("'", "''")
>>
>>         # Filter to find DisplayNames that contain *both* the first name part AND the last name part.
>>         # This is flexible for middle initials and "LastName, FirstName" formats.
>>         $filterQuery = "((DisplayName -like '*$escFirstName*') -and (DisplayName -like '*$escLastName*'))"
>>
>>         $foundUsers = Get-ADUser -Filter $filterQuery -Properties DisplayName, Mail -ErrorAction SilentlyContinue
>>
>>         if ($foundUsers) {
>>             foreach ($userObj in $foundUsers) {
>>                 [PSCustomObject]@{
>>                     SearchedName   = $fullNameFromList
>>                     AD_DisplayName = $userObj.DisplayName
>>                     AD_Mail        = $userObj.Mail
>>                 }
>>             }
>>         } else {
>>             [PSCustomObject]@{
>>                 SearchedName   = $fullNameFromList
>>                 AD_DisplayName = "Not Found (using First and Last name parts)"
>>                 AD_Mail        = "N/A"
>>             }
>>         }
>>     } else {
>>         # Handle cases where the input name couldn't be split into two parts
>>         [PSCustomObject]@{
>>             SearchedName   = $fullNameFromList
>>             AD_DisplayName = "Skipped (input format not 'FirstName LastName')"
>>             AD_Mail        = "N/A"
>>         }
>>     }
>> } | Export-Csv -Path "C:\Path\users_and_emails_first_last_match.csv" -NoTypeInformation -Append
