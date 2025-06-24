# Assuming $users is already defined as a list (array) of email addresses
$Users = Get-Content -Path C:\Path\Users.txt
$output = @() # Initialize an empty array to store the results

foreach ($email in $users) {
    try {
        # Get the AD user object based on the email address
        $user = Get-ADUser -Filter "mail -eq '$email'" -Properties GivenName, Surname, mail

        if ($user) {
            # Create a custom object to store the user information
            $output += [PSCustomObject]@{
                FirstName = $user.GivenName
                LastName  = $user.Surname
				Email	  = $user.mail
            }
        } else {
            Write-Warning "No AD user found with email address: $email"
            # Optionally add a record for not found users
            $output += [PSCustomObject]@{
                Email     = $email
                FirstName = ""
                LastName  = "User Not Found"
            }
        }
    } catch {
        Write-Error "An error occurred while searching for user with email: $email - $($_.Exception.Message)"
        # Optionally add an error record
        $output += [PSCustomObject]@{
            Email     = $email
            FirstName = ""
            LastName  = "Error Retrieving Info"
        }
    }
}

# Specify the path and filename for the CSV file
$csvFilePath = "C:\Path\User List.csv"

# Export the results to a CSV file
$output | Export-Csv -Path $csvFilePath -NoTypeInformation
