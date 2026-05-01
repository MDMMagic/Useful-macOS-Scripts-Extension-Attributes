#!/bin/bash
#
# EA: Latest Supported macOS (SOFA)
# Reports the latest macOS this device supports, the latest available
# version of that release, and whether the device is currently running it.
# Feed maintained by macadmins/sofa - no manual updates required.
#
# Author - Dan@MDMmagic.au
# Date - 1st May 2026
# Version 1.0
#

online_json_url="https://sofafeed.macadmins.io/v1/macos_data_feed.json"
user_agent="SOFA-Jamf-EA-LatestSupportedOS/1.0"

# Local cache paths
json_cache_dir="/private/var/tmp/sofa"
json_cache="$json_cache_dir/macos_data_feed.json"
etag_cache="$json_cache_dir/macos_data_feed_etag.txt"
etag_cache_temp="$json_cache_dir/macos_data_feed_etag_temp.txt"

/bin/mkdir -p "$json_cache_dir"

# Fetch feed, using etag to avoid unnecessary downloads
if [[ -f "$etag_cache" && -f "$json_cache" ]]; then
    etag_old=$(/bin/cat "$etag_cache")
    /usr/bin/curl --compressed --silent \
        --etag-compare "$etag_cache" \
        --etag-save "$etag_cache_temp" \
        --header "User-Agent: $user_agent" \
        "$online_json_url" \
        --output "$json_cache"
    etag_temp=$(/bin/cat "$etag_cache_temp" 2>/dev/null)
    if [[ "$etag_old" == "$etag_temp" || -z "$etag_temp" ]]; then
        : # cache still valid, use existing file
    else
        /bin/mv "$etag_cache_temp" "$etag_cache"
    fi
else
    /usr/bin/curl --compressed --location --max-time 10 --silent \
        --header "User-Agent: $user_agent" \
        "$online_json_url" \
        --etag-save "$etag_cache" \
        --output "$json_cache"
fi

# Bail if we have no feed
if [[ ! -f "$json_cache" ]]; then
    echo "<result>Error: Could not fetch SOFA feed</result>"
    exit 1
fi

# Get this device's model identifier
# Handle VMs by falling back to a known-compatible model (M1 Mac mini)
model=$(/usr/sbin/sysctl -n hw.model 2>/dev/null)
if [[ "$model" == *"VirtualMac"* || "$model" == *"VMware"* || "$model" == *"Parallels"* ]]; then
    model="Macmini9,1"
fi

# Look up the latest supported macOS name for this model (e.g. "macOS Tahoe")
latest_supported_name=$(/usr/bin/plutil \
    -extract "Models.$model.SupportedOS.0" raw -expect string \
    "$json_cache" 2>/dev/null | /usr/bin/head -n 1)

if [[ -z "$latest_supported_name" || "$latest_supported_name" == *"error"* ]]; then
    echo "<result>Error: Model $model not found in SOFA feed</result>"
    exit 1
fi

# Extract just the major version number from the name (e.g. "macOS Tahoe" -> "26")
# Find which OSVersions entry matches this supported OS name
os_count=$(/usr/bin/plutil -extract "OSVersions" raw "$json_cache" 2>/dev/null | /usr/bin/head -n 1)
latest_version=""
os_name_clean=""
i=0
while true; do
    os_ver_name=$(/usr/bin/plutil -extract "OSVersions.$i.OSVersion" raw "$json_cache" 2>/dev/null | \
        /usr/bin/head -n 1 | /usr/bin/grep -v "<stdin>")
    [[ -z "$os_ver_name" ]] && break

    if [[ "$latest_supported_name" == *"$os_ver_name"* || "$os_ver_name" == *"$latest_supported_name"* ]]; then
        latest_version=$(/usr/bin/plutil \
            -extract "OSVersions.$i.Latest.ProductVersion" raw \
            "$json_cache" 2>/dev/null | /usr/bin/head -n 1)
        os_name_clean="$os_ver_name"
        break
    fi
    (( i++ ))
done

# Get the device's current macOS version
current_version=$(/usr/bin/sw_vers -productVersion)

# Build result string
if [[ -z "$latest_version" ]]; then
    echo "<result>Latest Supported: $latest_supported_name | Latest Available: Unknown | Installed: $current_version</result>"
    exit 0
fi

if [[ "$current_version" == "$latest_version" ]]; then
    status="Up to date"
else
    status="Behind"
fi

exit 0