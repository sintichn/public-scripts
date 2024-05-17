#!/bin/bash

##setComputerNameFromIiq.bash#################################################
#
# Author: Nick Sintich, 2024
# Description: Script pulls mac serial and looks up record in iiq, pulls name custom field and asset tag.
# Uses jamf binary to set computer name, report name to jamf along with asset tag.
# Sets host name and local host name on the mac itself.
# 
### Variables ################################################################

# iiq URL
iiqurl="$4"
# iiq API Token (Admin>Developer Tools>Create API Token)
token="$5"
# Custom field for comptuer name in iiq
comptuerNameCustomFieldId="$6"
# Pulls Serial number from mac (no need to edit this)
serial=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')

###############################################################################

### No need to Edit below this line ###

### Functions #################################################################

# Get custom new computer name field from IIQ and store it in $comptuerName variable
function get_iiq_comptuer_name() {
	iiqComputerName=$(curl --request GET \
	--url $iiqurl/api/v1.0/assets/serial/$serial \
	--header 'Accept: application/json' \
	--header 'Authorization: Bearer '$token'' \
	--silent \
	--header 'Content-Type: application/json' | grep -A 4 "$comptuerNameCustomFieldId" | sed -n '3p' | sed 's/.*"\(.*\)",/\1/' | tr -dc '[:print:]')
	
}

# Get asset tag field from IIQ and store it in $iiqAssetTag variable
	function get_iiq_asset_tag() {
	iiqAssetTag=$(curl --request GET \
	--url $iiqurl/api/v1.0/assets/serial/$serial \
	--header 'Accept: application/json' \
	--header 'Authorization: Bearer '$token'' \
	--silent \
	--header 'Content-Type: application/json' | grep '"AssetTag":' | sed 's/[^0-9]*\([0-9]*\).*/\1/')
		
}

# Renames a computer using the Jamf binary and variable set in get_iiq_comptuer_name function
function rename_computer() {
	JAMF_MESSAGE=$(sudo /usr/local/bin/jamf setComputerName -name "$iiqComputerName")
	JAMF_STATUS=$?
	echo $JAMF_STATUS
	echo $JAMF_MESSAGE
	if [[ JAMF_STATUS -eq 0 ]]; then
		RENAME=$(echo $JAMF_MESSAGE | awk 'END{print $NF}')
		echo $RENAME
		if [[ -n RENAME ]]; then
			# on success the jamf binary reports 'Set Computer Name to XXX'
			# so we split the phrase and return the last element
			echo "SUCCESS: Set computer name to $RENAME"
		else
			echo "ERROR: Unable to set computer name, is the New Computer Name field filled in iiq?"
			exit 1
		fi
	else
		echo "ERROR: Unable to set computer name, check iiq."
		exit 1
	fi
	
}

# Set Asset Tag in Jamf
function set_asset_tag() {
	# Get Asset Tag from named comptuer
	sudo /usr/local/bin/jamf recon -assetTag "$iiqAssetTag"
}

# Set Hostname and LocalHost
function set_host_local() {
	# Get computerName
	localComputerName=$( /usr/sbin/scutil --get ComputerName | tr -dc '[:print:]')
	echo $localComputerName
	scutil --set HostName $localComputerName
	sudo scutil --set LocalHostName "$localComputerName"
}


### Function Triggers ###########################################################

# Call function get_iiq_comptuer_name
get_iiq_comptuer_name

# Call function get_iiq_asset_tag
get_iiq_asset_tag 

# Call function rename_comptuer
rename_computer 

# Call set_asset_tag
set_asset_tag 

# Call set_host_local
set_host_local

exit 0
