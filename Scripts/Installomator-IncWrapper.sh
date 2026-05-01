#!/bin/zsh --no-rcs
#
# Installomator with Wrapper
# Fetches latest Installomator PKG at runtime — no maintenance required
# $4 = LABEL, $5 = DEBUG (0/1), $6 = NOTIFY (silent/all/success)
#
# Author - Dan@MDMmagic.au
# Date - 1st May 2026
# Version 1.0
#

LABEL="$4"
DEBUG_PARAM="$5"
NOTIFY_PARAM="$6"

# Expected signing identity for Installomator PKG releases
EXPECTED_TEAM_ID="JME5BW3F3R"
EXPECTED_CERT="Developer ID Installer: Armin Briegel (${EXPECTED_TEAM_ID})"

if [[ -z "$LABEL" ]]; then
    echo "ERROR: No label provided in parameter 4"
    exit 1
fi

# Resolve latest release tag from GitHub API
LATEST_URL="https://api.github.com/repos/Installomator/Installomator/releases/latest"
LATEST_TAG=$(curl -sf "$LATEST_URL" | grep '"tag_name"' | sed 's/.*"tag_name": *"\(.*\)".*/\1/' | tr -d '\r')

if [[ -z "$LATEST_TAG" ]]; then
    echo "ERROR: Could not resolve latest Installomator release tag"
    exit 1
fi

echo "Latest Installomator release: $LATEST_TAG"
LATEST_TAG_NO_V=$(echo "$LATEST_TAG" | awk '{sub(/^v/,""); print}')

DOWNLOAD_URL="https://github.com/Installomator/Installomator/releases/download/${LATEST_TAG}/Installomator-${LATEST_TAG_NO_V}.pkg"
INSTALL_PKG="/tmp/Installomator.pkg"

echo "Downloading: $DOWNLOAD_URL"
curl -fL "$DOWNLOAD_URL" -o "$INSTALL_PKG" 2>&1
CURL_EXIT=$?

if [[ $CURL_EXIT -ne 0 ]] || [[ ! -f "$INSTALL_PKG" ]]; then
    echo "ERROR: Failed to download Installomator PKG (curl exit: $CURL_EXIT)"
    echo "URL attempted: $DOWNLOAD_URL"
    rm -f "$INSTALL_PKG"
    exit 1
fi

# Verify PKG signing certificate before doing anything with it
echo "Verifying PKG signature..."
SIG_CHECK=$(pkgutil --check-signature "$INSTALL_PKG" 2>&1)

if ! echo "$SIG_CHECK" | grep -q "$EXPECTED_CERT"; then
    echo "ERROR: PKG signature verification failed. Expected: $EXPECTED_CERT"
    echo "pkgutil output: $SIG_CHECK"
    rm -f "$INSTALL_PKG"
    exit 1
fi

echo "Signature OK — installing Installomator ${LATEST_TAG}..."
installer -pkg "$INSTALL_PKG" -target /
rm -f "$INSTALL_PKG"

# Build Installomator args
ARGS=("$LABEL")
[[ -n "$DEBUG_PARAM" ]] && ARGS+=("DEBUG=$DEBUG_PARAM")
[[ -n "$NOTIFY_PARAM" ]] && ARGS+=("NOTIFY=$NOTIFY_PARAM")

echo "Running: /usr/local/Installomator/Installomator.sh ${ARGS[*]}"
/usr/local/Installomator/Installomator.sh "${ARGS[@]}"
EXIT_CODE=$?

exit $EXIT_CODE