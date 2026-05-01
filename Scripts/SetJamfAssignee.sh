#!/bin/bash
#
# Author - Dan@MDMmagic.au
# Date - 1st May 2026
# Version 1.0
#

# Define your domain
domain="domain"

# Get the currently logged in user
loggedInUser=$(stat -f%Su /dev/console)

echo "Logged in user: $loggedInUser"

# Validate user
if [[ "$loggedInUser" == "root" || "$loggedInUser" == "_mbsetupuser" || -z "$loggedInUser" ]]; then
    echo "No valid logged in user. Exiting."
    exit 1
fi

# Build email address
email="${loggedInUser}@${domain}"

echo "Email will be: $email"

# Update Jamf inventory
/usr/local/bin/jamf recon -endUsername "$loggedInUser" -email "$email"

echo "Jamf updated:"
echo "Username: $loggedInUser"
echo "Email: $email"

exit 0