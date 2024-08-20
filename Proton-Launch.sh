#!/bin/bash

# Variables
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROTON_GE_DIR="$SCRIPT_DIR/proton-ge"
GAME_DIR="$SCRIPT_DIR/game"
GAME_FOLDER="BlueDivision"
GAME_PATH="$GAME_DIR/$GAME_FOLDER/BDivision S.C.H.A.L.E. Defense.exe"
GAME_NAME="Blue Division"
COMPAT_DATA_PATH="$SCRIPT_DIR/compatdata"
SCRIPT_NAME="$(basename "$0")"
CURRENT_SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_NAME"

# Version: 1.1.2
# Game Version: None

# Functions for user prompts using kdialog, zenity, or tkinter
prompt_user() {
    local message="$1"
    if [ -t 1 ]; then
        # Terminal prompt
        read -p "$message (y/n): " response
    else
        # GUI prompt using kdialog, zenity, or tkinter
        if command -v kdialog > /dev/null 2>&1; then
            # Use kdialog for KDE
            if kdialog --yesno "$message" --title "Update Available"; then
                response="y"
            else
                response="n"
            fi
        elif command -v zenity > /dev/null 2>&1; then
            # Use zenity for GTK environments
            if zenity --question --text="$message" --title="Update Available"; then
                response="y"
            else
                response="n"
            fi
        else
            # Fallback to tkinter if kdialog and zenity are not available
            python3 - <<END
import tkinter as tk
from tkinter import messagebox
import sys

root = tk.Tk()
root.withdraw()
response = messagebox.askyesno("Update Available", "$message")
sys.exit(0 if response else 1)
END
            response=$?
            if [ $response -eq 0 ]; then
                response="y"
            else
                response="n"
            fi
        fi
    fi
    echo "$response"
}


# Function to flatten the game directory structure
flatten_directory() {
    local dir="$1"
    while [ "$(find "$dir" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1 ] && [ "$(find "$dir" -mindepth 1 -maxdepth 1 -type f | wc -l)" -eq 0 ]; do
        subdir="$(find "$dir" -mindepth 1 -maxdepth 1 -type d)"
        echo "Flattening directory: Moving contents of $subdir to $dir"
        mv "$subdir"/* "$dir"
        rmdir "$subdir"
    done
}

# Check for script updates
echo "Checking for script updates..."
LATEST_RELEASE=$(curl -s https://api.github.com/repos/BDivWrapper/BlueDivisionWrapper/releases/latest)
LATEST_VERSION=$(echo "$LATEST_RELEASE" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
LATEST_ASSET_URL=$(echo "$LATEST_RELEASE" | grep browser_download_url | grep "$SCRIPT_NAME" | cut -d '"' -f 4)

if [ -n "$LATEST_VERSION" ] && [ "$LATEST_VERSION" != "$(grep '^# Version:' "$CURRENT_SCRIPT_PATH" | cut -d ' ' -f 3)" ]; then
    response=$(prompt_user "A new script version ($LATEST_VERSION) is available. Would you like to update?")
    if [[ "$response" == "y" ]]; then
        echo "Updating script..."
        wget -O "$CURRENT_SCRIPT_PATH.tmp" "$LATEST_ASSET_URL"
        chmod +x "$CURRENT_SCRIPT_PATH.tmp"
        mv "$CURRENT_SCRIPT_PATH.tmp" "$CURRENT_SCRIPT_PATH"
        echo "Updated to version $LATEST_VERSION."
        exec "$CURRENT_SCRIPT_PATH" "$@"
        exit 0
    else
        echo "Skipping script update."
    fi
else
    echo "No script update needed."
fi

# Create directories if they don't exist
mkdir -p "$PROTON_GE_DIR"
mkdir -p "$COMPAT_DATA_PATH"
mkdir -p "$GAME_DIR"

# Check for Proton-GE updates
echo "Checking for the latest Proton-GE release online..."
LATEST_RELEASE=$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest | grep browser_download_url | grep tar.gz | cut -d '"' -f 4)

if [ -n "$LATEST_RELEASE" ]; then
    FILENAME=$(basename "$LATEST_RELEASE")
    FOLDERNAME="${FILENAME%.tar.gz}"

    if [ ! -d "$PROTON_GE_DIR/$FOLDERNAME" ]; then
        response=$(prompt_user "A new Proton-GE version ($FOLDERNAME) is available. Would you like to update?")
        if [[ "$response" == "y" ]]; then
            echo "Updating Proton-GE..."
            wget -O "$PROTON_GE_DIR/$FILENAME" "$LATEST_RELEASE"
            echo "Extracting $FILENAME..."
            tar -xzf "$PROTON_GE_DIR/$FILENAME" -C "$PROTON_GE_DIR"
            chmod +x "$PROTON_GE_DIR/$FOLDERNAME/proton"
            rm "$PROTON_GE_DIR/$FILENAME"

            echo "Removing old versions of Proton-GE..."
            for dir in "$PROTON_GE_DIR"/GE-Proton*; do
                if [[ -d "$dir" && "$dir" != "$PROTON_GE_DIR/$FOLDERNAME" ]]; then
                    echo "Deleting $dir..."
                    rm -rf "$dir"
                fi
            done
        else
            echo "Skipping Proton-GE update."
        fi
    else
        echo "$FOLDERNAME already exists. Skipping download and extraction."
    fi
else
    echo "Unable to reach GitHub. Skipping Proton-GE update and using local versions."
fi

# Check for game updates
echo "Checking for the latest game release online..."
LATEST_GAME_RELEASE=$(curl -s https://api.github.com/repos/WhatIsThisG/BlueDivision_Release/releases/latest)
LATEST_GAME_VERSION=$(echo "$LATEST_GAME_RELEASE" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
LATEST_GAME_ASSET_URL=$(echo "$LATEST_GAME_RELEASE" | grep browser_download_url | grep zip | cut -d '"' -f 4)

if [ -n "$LATEST_GAME_VERSION" ] && [ "$LATEST_GAME_VERSION" != "$(grep '^# Game Version:' "$CURRENT_SCRIPT_PATH" | cut -d ' ' -f 4)" ]; then
    response=$(prompt_user "A new game version ($LATEST_GAME_VERSION) is available. Would you like to update?")
    if [[ "$response" == "y" ]]; then
        echo "Updating game..."
        wget -O "BlueDivision.zip" "$LATEST_GAME_ASSET_URL"
        echo "Deleting old game files..."
        rm -rf "$GAME_DIR"/*
        echo "Extracting BlueDivision.zip..."
        unzip -o "BlueDivision.zip" -d "$GAME_DIR"
        rm "BlueDivision.zip"

        # Flatten the directory structure
        flatten_directory "$GAME_DIR"

        # Update the Game Version in the script
        sed -i "s/^# Game Version:.*/# Game Version: $LATEST_GAME_VERSION/" "$CURRENT_SCRIPT_PATH"

        GAME_PATH="$GAME_DIR/BDivision S.C.H.A.L.E. Defense.exe"
    else
        echo "Skipping game update."
    fi
else
    echo "No game update needed."
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

# If no valid Proton-GE version could be found, exit the script
if [ -z "$HIGHEST_LOCAL_RELEASE" ]; then
    echo "No valid Proton-GE version found. Exiting."
    exit 1
fi

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
