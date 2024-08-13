#!/bin/bash

# Variables
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROTON_GE_DIR="$SCRIPT_DIR/proton-ge"
GAME_PATH="$SCRIPT_DIR/BDivision S.C.H.A.L.E. Defense.exe"
GAME_NAME="Blue Division"
COMPAT_DATA_PATH="$SCRIPT_DIR/compatdata"

# Create Proton-GE and compatibility data directories if they don't exist
mkdir -p "$PROTON_GE_DIR"
mkdir -p "$COMPAT_DATA_PATH"

# Attempt to fetch the latest Proton-GE release from GitHub
echo "Checking for the latest Proton-GE release online..."
LATEST_RELEASE=$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest | grep browser_download_url | grep tar.gz | cut -d '"' -f 4)

# Get the filename from the URL
if [ -n "$LATEST_RELEASE" ]; then
    FILENAME=$(basename "$LATEST_RELEASE")
    # Download the release if not already downloaded
    if [ ! -f "$PROTON_GE_DIR/$FILENAME" ]; then
        echo "Downloading $FILENAME..."
        wget -O "$PROTON_GE_DIR/$FILENAME" "$LATEST_RELEASE"
        echo "Extracting $FILENAME..."
        tar -xzf "$PROTON_GE_DIR/$FILENAME" -C "$PROTON_GE_DIR"

        # Ensure the Proton executable is marked as executable
        chmod +x "$PROTON_GE_DIR/${FILENAME%.tar.gz}/proton"
    else
        echo "$FILENAME already exists. Skipping download and extraction."
    fi
else
    echo "Unable to reach GitHub. Skipping download and using local versions."
fi

# Find the highest numbered Proton-GE release in the local directory
HIGHEST_LOCAL_RELEASE=""
for dir in "$PROTON_GE_DIR"/GE-Proton*; do
    if [[ -d "$dir" ]]; then
        version="${dir##*/}"
        if [[ "$version" > "$HIGHEST_LOCAL_RELEASE" ]]; then
            HIGHEST_LOCAL_RELEASE="$version"
        fi
    fi
done

# Path to the highest version of Proton-GE found
PROTON_PATH="$PROTON_GE_DIR/$HIGHEST_LOCAL_RELEASE/proton"

# Set the WINEPREFIX to the custom compat data path
export WINEPREFIX="$COMPAT_DATA_PATH/pfx"

# Set the STEAM_COMPAT_DATA_PATH to the custom compat data path
export STEAM_COMPAT_DATA_PATH="$COMPAT_DATA_PATH"

# Set the STEAM_COMPAT_CLIENT_INSTALL_PATH to the current directory
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$SCRIPT_DIR"

# Initialize the Wine prefix (this runs wineboot)
if [ ! -d "$WINEPREFIX" ]; then
    echo "Initializing Wine prefix..."
    "$PROTON_PATH" run wineboot
fi

# Launch the game with the highest numbered Proton-GE
echo "Launching $GAME_NAME with $HIGHEST_LOCAL_RELEASE..."
"$PROTON_PATH" run "$GAME_PATH"
