#!/usr/bin/env bash
# shellcheck disable=SC1091

#  ____    ___                    ____
# /\  _`\ /\_ \                  /\  _`\   __           __          __
# \ \ \L\ \//\ \    __  __     __\ \ \/\ \/\_\  __  __ /\_\    ____/\_\    ___     ___
#  \ \  _ <'\ \ \  /\ \/\ \  /'__`\ \ \ \ \/\ \/\ \/\ \\/\ \  /',__\/\ \  / __`\ /' _ `\
#   \ \ \L\ \\_\ \_\ \ \_\ \/\  __/\ \ \_\ \ \ \ \ \_/ |\ \ \/\__, `\ \ \/\ \L\ \/\ \/\ \
#    \ \____//\____\\ \____/\ \____\\ \____/\ \_\ \___/  \ \_\/\____/\ \_\ \____/\ \_\ \_\
#     \/___/ \/____/ \/___/  \/____/ \/___/  \/_/\/__/    \/_/\/___/  \/_/\/___/  \/_/\/_/
#  __                                      __                                        __
# /\ \       __                           /\ \                                      /\ \
# \ \ \     /\_\    ___   __  __  __  _   \ \ \         __     __  __    ___     ___\ \ \___      __   _ __
#  \ \ \  __\/\ \ /' _ `\/\ \/\ \/\ \/'\   \ \ \  __  /'__`\  /\ \/\ \ /' _ `\  /'___\ \  _ `\  /'__`\/\`'__\
#   \ \ \L\ \\ \ \/\ \/\ \ \ \_\ \/>  </    \ \ \L\ \/\ \L\.\_\ \ \_\ \/\ \/\ \/\ \__/\ \ \ \ \/\  __/\ \ \/
#    \ \____/ \ \_\ \_\ \_\ \____//\_/\_\    \ \____/\ \__/.\_\\ \____/\ \_\ \_\ \____\\ \_\ \_\ \____\\ \_\
#     \/___/   \/_/\/_/\/_/\/___/ \//\/_/     \/___/  \/__/\/_/ \/___/  \/_/\/_/\/____/ \/_/\/_/\/____/ \/_/
# Version 2.0.0 | Made By BlueFunny & Spaghet

IFS=$'\n\t'

# Error handling
set -euo pipefail

### Variables ###
# Script
SCRIPT_VERSION="2.0.0"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DATA_PATH="$SCRIPT_PATH/data"
SCRIPT_CURRENT_PATH="$SCRIPT_PATH/$SCRIPT_NAME"

# Proton-GE
PROTON_GE_PATH="$SCRIPT_DATA_PATH/proton-ge"

# Game
GAME_PATH="$SCRIPT_PATH/game"
GAME_BIN_PATH="$GAME_PATH/BDivision S.C.H.A.L.E. Defense.exe"
GAME_COMPAT_DATA_PATH="$SCRIPT_DATA_PATH/compatdata"

# System
VERSION_FILE="$SCRIPT_DATA_PATH/version.json"
SKIP_UPDATE=""
DEBUG=false

# ANSI color codes (used for logging)
declare -A COLORS=(
    [RED]='\033[0;31m'
    [GREEN]='\033[0;32m'
    [YELLOW]='\033[0;33m'
    [BLUE]='\033[0;34m'
    [CYAN]='\033[0;36m'
    [WHITE]='\033[1;37m'
    [BLACK]='\033[0;30m'
    [NC]='\033[0m'
)

### Functions ###
# Function to log messages
log() {
    local level="$1"
    local message="$2"
    local timestamp level_color

    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
    "INFO") level_color="${COLORS[WHITE]}${COLORS[BLUE]}" ;;
    "SUCCESS") level_color="${COLORS[WHITE]}${COLORS[GREEN]}" ;;
    "ERROR") level_color="${COLORS[WHITE]}${COLORS[RED]}" ;;
    "WARN") level_color="${COLORS[BLACK]}${COLORS[YELLOW]}" ;;
    "DEBUG")
        if [ "$DEBUG" != true ]; then return; fi
        level_color="${COLORS[CYAN]}"
        ;;
    *) level_color="${COLORS[NC]}" ;;
    esac

    printf "${COLORS[CYAN]}[%s]${COLORS[NC]} ${level_color}%7s${COLORS[NC]} %s\n" "$timestamp" "$level" "$message"
}

# Function to detect OS and return relevant information
detect_os() {
    local os_type variant_type package_manager install_command

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        os_type=${ID,,}
        variant_type=${VARIANT_ID:-none}
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        os_type=${DISTRIB_ID,,}
        variant_type="none"
    else
        os_type=$(uname -s)
        variant_type="none"
    fi

    case "$os_type" in
    ubuntu | debian | linuxmint)
        package_manager="apt"
        install_command="apt-get install -y"
        ;;
    fedora | centos | rhel | rocky)
        package_manager=$(command -v dnf &>/dev/null && echo "dnf" || echo "yum")
        install_command="$package_manager install -y"
        ;;
    arch | manjaro)
        package_manager="pacman"
        install_command="pacman -Sy --noconfirm"
        ;;
    opensuse*)
        package_manager="zypper"
        install_command="zypper install -y"
        ;;
    *)
        package_manager="unknown"
        install_command="unknown"
        ;;
    esac

    echo "$os_type $variant_type $package_manager $install_command"
}

# Function to install dependencies
install_dependencies() {
    local dependencies=("curl" "wget" "jq" "unzip" "pv" "whiptail")
    local os_info os_type variant_type package_manager install_command old_IFS

    os_info=$(detect_os)
    old_IFS="$IFS"
    IFS=' ' read -r os_type variant_type package_manager install_command <<<"$os_info"
    IFS="$old_IFS"

    log "DEBUG" "OS Type: $os_type"
    log "DEBUG" "OS Variant: $variant_type"
    log "DEBUG" "Package Manager: $package_manager"
    log "DEBUG" "Install Command: $install_command"

    if [ "$package_manager" = "unknown" ]; then
        log "WARN" "Unsupported OS: $os_type"
        log "WARN" "Please install dependencies manually"
        return 1
    elif [[ "$variant_type" =~ ^(kinoite|silverblue)$ ]]; then
        log "WARN" "Unsupported OS variant: $variant_type"
        log "WARN" "Please install dependencies manually"
        return 1
    fi

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            log "INFO" "Installing $dep..."
            if ! eval "sudo $install_command $dep"; then
                log "ERROR" "Failed to install $dep"
                return 1
            fi
            log "DEBUG" "$dep installed successfully"
        else
            log "INFO" "$dep is already installed"
        fi
    done

    log "SUCCESS" "All dependencies are installed"
}

# Function to download and extract files
download_and_extract() {
    local url="$1"
    local output_dir="$2"
    local filename download_path

    filename=$(basename "$url")
    download_path="$SCRIPT_DATA_PATH/$filename"

    log "INFO" "Downloading $filename..."
    if ! wget -q --show-progress -O "$download_path" "$url"; then
        log "ERROR" "Failed to download $url (Error code: $?)"
        return 1
    fi

    log "INFO" "Extracting $filename..."
    mkdir -p "$output_dir" || {
        log "ERROR" "Failed to create directory: $output_dir"
        return 1
    }
    case "$filename" in
    *.tar.gz)
        if ! tar -xzf "$download_path" -C "$output_dir"; then
            log "ERROR" "Failed to extract $filename (Error code: $?)"
            return 1
        fi
        ;;
    *.zip)
        if ! unzip -q "$download_path" -d "$output_dir"; then
            log "ERROR" "Failed to extract $filename (Error code: $?)"
            return 1
        fi
        ;;
    *)
        log "ERROR" "Unsupported file format: $filename"
        return 1
        ;;
    esac

    log "INFO" "Cleaning up..."
    rm "$download_path"

    log "SUCCESS" "Successfully downloaded and extracted $filename"
}

# Function to manage version information in a JSON file
version_parser() {
    local type="$1"
    local version="$2"
    local action="$3"

    [ -f "$VERSION_FILE" ] || echo '{}' >"$VERSION_FILE"

    case "$action" in
    "get")
        jq -r ".$type // \"\"" "$VERSION_FILE"
        ;;
    "set")
        local tmp
        tmp=$(mktemp)
        if ! jq ".$type = \"$version\"" "$VERSION_FILE" >"$tmp"; then
            log "ERROR" "Failed to set version for $type"
            rm "$tmp"
            return 1
        fi
        mv "$tmp" "$VERSION_FILE"
        ;;
    *)
        log "ERROR" "Invalid action for version_parser"
        return 1
        ;;
    esac
}

# Function to prompt user for update
prompt_user() {
    local message="$1"
    local response

    # Try GUI prompts first
    for cmd in kdialog zenity python3 whiptail; do
        if command -v "$cmd" >/dev/null 2>&1; then
            case "$cmd" in
            kdialog) "$cmd" --yesno "$message" --title "Update Available" && response="y" || response="n" ;;
            zenity) "$cmd" --question --text="$message" --title="Update Available" && response="y" || response="n" ;;
            python3) python3 -c "import tkinter as tk, tkinter.messagebox as mb; root=tk.Tk(); root.withdraw(); response=mb.askyesno('Update Available', '$message'); print('y' if response else 'n'); root.destroy()" || response="n" ;;
            whiptail) whiptail --yesno "$message" 10 50 3>&1 1>&2 2>&3 && response="y" || response="n" ;;
            esac
            break
        fi
    done

    # Fallback to CLI prompt
    if [ -z "${response:-}" ]; then
        if [ -t 0 ]; then
            echo -e "\n$message"
            read -r -p "Enter y/n: " response
        fi
    fi

    echo "${response:-n}"
}

# Function to update the script
update_script() {
    local latest_version="$1"
    local latest_asset_url="$2"
    local temp_file="${SCRIPT_CURRENT_PATH}.tmp"

    log "DEBUG" "Downloading script from: $latest_asset_url"

    wget -q -O "$temp_file" "$latest_asset_url"

    chmod +x "$temp_file"
    mv "$temp_file" "$SCRIPT_CURRENT_PATH"

    version_parser "script" "$latest_version" "set"
}

# Function to update the game
update_game() {
    local latest_version="$1"
    local latest_asset_url="$2"
    local temp_dir

    temp_dir=$(mktemp -d)

    log "DEBUG" "Downloading game from: $latest_asset_url"

    download_and_extract "$latest_asset_url" "$temp_dir"

    rm -rf "${GAME_PATH:?}"/*
    mv "$temp_dir/SCHALE Defense"/* "$GAME_PATH/"
    rm -rf "$temp_dir" "BlueDivision.zip"

    log "DEBUG" "Game directory structure after update:"
    log "DEBUG" "$(find "$GAME_PATH" -maxdepth 2 -type d | sed -e "s/[^-][^\/]*\//  |/g" -e "s/|\([^ ]\)/|-\1/")"

    version_parser "game" "$latest_version" "set"
}

# Function to update Proton-GE
update_proton_ge() {
    local latest_version="$1"
    local latest_asset_url="$2"

    log "DEBUG" "Downloading Proton-GE from: $latest_asset_url"

    download_and_extract "$latest_asset_url" "$PROTON_GE_PATH"

    chmod +x "$PROTON_GE_PATH/$latest_version/proton"
    find "$PROTON_GE_PATH" -maxdepth 1 -type d -name "GE-Proton*" ! -name "$latest_version" -exec rm -rf {} +

    log "DEBUG" "Proton-GE directory structure after update:"
    log "DEBUG" "$(find "$PROTON_GE_PATH" -maxdepth 1 -type d | sed -e "s/[^-][^\/]*\//  |/g" -e "s/|\([^ ]\)/|-\1/")"

    version_parser "proton" "$latest_version" "set"
}

# Function to check if a file exists
check_file_exists() {
    local type="$1"
    local file_path="$2"

    if [ ! -f "$file_path" ]; then
        log "ERROR" "$type file not found: $file_path"
        return 1
    fi

    log "SUCCESS" "$type file exists"
}

# Function to check for local update files
check_local_updates() {
    local type="$1"
    local expected_version="$2"
    local file_pattern="$3"
    local extract_dir="$4"
    local local_file temp_dir extracted_version

    if [ "$type" != "script" ]; then
        log "INFO" "Checking for local $type update files..."

        local_file=$(find "$SCRIPT_PATH" -maxdepth 1 -type f -name "$file_pattern" | head -n 1)
        if [ -n "$local_file" ]; then
            log "INFO" "Found local $type update file: $local_file"

            temp_dir=$(mktemp -d)

            if download_and_extract "$local_file" "$temp_dir"; then
                log "SUCCESS" "Successfully extracted local $type update file"

                if [ "$type" = "script" ]; then
                    extracted_version=$(grep -oP 'SCRIPT_VERSION="\K[^"]+' "$temp_dir/$SCRIPT_NAME")
                    if [ "$extracted_version" = "$expected_version" ]; then
                        # Update script from local file
                        log "SUCCESS" "Local $type update file is valid"
                        mv "$temp_dir/$SCRIPT_NAME" "$SCRIPT_CURRENT_PATH"
                        rm -rf "$temp_dir"
                        rm "$local_file"
                        version_parser "$type" "$expected_version" "set"
                        return 0
                    fi
                else
                    # Update game or proton from local file
                    rm -rf "$extract_dir"
                    mv "$temp_dir" "$extract_dir"
                    rm "$local_file"
                    version_parser "$type" "$expected_version" "set"
                    return 0
                fi
            fi

            log "WARN" "Local $type update file is invalid or incompatible"
            rm -rf "$temp_dir"
        else
            log "INFO" "No local $type update file found"
        fi
        return 1
    fi
}

# Function to check for and perform updates
check_and_update() {
    local type="$1"
    local api_url="$2"
    local asset_filter="$3"
    local update_function="$4"
    local output_dir="$5"
    local latest_version latest_release latest_asset_url current_version

    if [ "$type" != "script" ]; then
        current_version=$(version_parser "$type" "" "get")
    else
        current_version=$SCRIPT_VERSION
    fi

    log "INFO" "Checking for $type updates..."

    latest_release=$(curl -s "$api_url") || {
        log "WARN" "Failed to fetch $type updates (Error code: $?)"
        return 1
    }
    latest_version=$(echo "$latest_release" | jq -r .tag_name)
    latest_asset_url=$(echo "$latest_release" | jq -r ".assets[] | select(.name | test(\"$asset_filter\")) | .browser_download_url")

    if [ -z "$latest_version" ] || [ -z "$latest_asset_url" ]; then
        log "WARN" "Failed to parse $type version or asset URL"
        return 1
    fi

    log "DEBUG" "Current $type version: $current_version"
    log "DEBUG" "Latest $type version: $latest_version"
    log "DEBUG" "Latest $type asset URL: $latest_asset_url"

    if [[ "$latest_version" > "$current_version" ]]; then
        # Check for local updates first
        if check_local_updates "$type" "$latest_version" "$asset_filter" "${!output_dir}"; then
            log "SUCCESS" "$type updated to version $latest_version using local file"
        # Prompt user for update if no local update is found
        elif prompt_user "A new $type version ($latest_version) is available. Update?" | grep -q "^y"; then
            if "$update_function" "$latest_version" "$latest_asset_url"; then
                log "SUCCESS" "$type updated to version $latest_version"
            else
                log "ERROR" "Failed to update $type"
            fi
        else
            log "WARN" "Skipping $type update"
        fi
    else
        log "INFO" "No $type update needed"
    fi
}

# Function to display help message
show_help() {
    echo "Usage: $SCRIPT_NAME [OPTIONS]"
    echo "Options:"
    echo "  --skip-update <type>   Skip specific type of update"
    echo "                         Type can be 'all' 'script' 'game' or 'proton'"
    echo "  --game-path <path>     Specify game path"
    echo "  --proton-path <path>   Specify Proton path"
    echo "  --debug                Enable debug mode"
    echo "  -h, --help             Show this help message"
    echo "  -v, --version          Show version information"
}

# Function to display version information
show_version() {
    echo "Version -> $SCRIPT_VERSION"
}

# Function to parse arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
        --skip-update)
            SKIP_UPDATE="$2"
            shift 2
            ;;
        --game-path)
            GAME_PATH="$2"
            GAME_BIN_PATH="$GAME_PATH/BlueDivision/BDivision S.C.H.A.L.E. Defense.exe"
            shift 2
            ;;
        --proton-path)
            PROTON_GE_PATH="$2"
            shift 2
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        --help | -h)
            show_help
            exit 0
            ;;
        --version | -v)
            show_version
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
        esac
    done
}

# Main function
main() {
    local proton_version proton_path update_items old_IFS

    parse_arguments "$@"

    # Root user warning
    if [[ $EUID -eq 0 ]]; then
        log "WARN" "##############################################"
        log "WARN" "##                                          ##"
        log "WARN" "##            ROOT USER WARNING             ##"
        log "WARN" "##                                          ##"
        log "WARN" "##  You are running this script as root     ##"
        log "WARN" "##  This may pose potential risks to your   ##"
        log "WARN" "##  system, THIS IS NOT RECOMMENDED         ##"
        log "WARN" "##                                          ##"
        log "WARN" "##  The script will continue in 10 seconds  ##"
        log "WARN" "##  Press Ctrl+C to cancel if unsure        ##"
        log "WARN" "##                                          ##"
        log "WARN" "##############################################"

        for i in {10..1}; do
            log "INFO" "Waiting for $i seconds..."
            sleep 1
        done

        log "INFO" "Continuing script execution..."
        echo ""
    fi

    install_dependencies || {
        log "ERROR" "Failed to install dependencies. Please install them manually."
        exit 1
    }

    mkdir -p "$PROTON_GE_PATH" "$GAME_COMPAT_DATA_PATH" "$GAME_PATH"

    log "DEBUG" "SCRIPT_NAME: $SCRIPT_NAME"
    log "DEBUG" "SCRIPT_PATH: $SCRIPT_PATH"
    log "DEBUG" "SCRIPT_CURRENT_PATH: $SCRIPT_CURRENT_PATH"
    log "DEBUG" "PROTON_GE_PATH: $PROTON_GE_PATH"
    log "DEBUG" "GAME_PATH: $GAME_PATH"
    log "DEBUG" "GAME_BIN_PATH: $GAME_BIN_PATH"
    log "DEBUG" "GAME_COMPAT_DATA_PATH: $GAME_COMPAT_DATA_PATH"
    log "DEBUG" "SKIP_UPDATE: $SKIP_UPDATE"

    update_items=(
        "script|https://api.github.com/repos/BDivWrapper/BlueDivisionWrapper/releases/latest|$SCRIPT_NAME|update_script|SCRIPT_PATH"
        "game|https://api.github.com/repos/WhatIsThisG/BlueDivision_Release/releases/latest|zip|update_game|GAME_PATH"
        "proton|https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest|tar.gz|update_proton_ge|PROTON_GE_PATH"
    )

    # Iterate through update items and perform updates
    for item in "${update_items[@]}"; do
        old_IFS="$IFS"
        IFS='|' read -r name url file_ext update_func output_dir <<<"$item"
        IFS="$old_IFS"

        case "$name" in
        "proton")
            file_path=$(find "$PROTON_GE_PATH" -maxdepth 1 -type d -name "GE-Proton*" | sort -V | tail -n1)/proton
            ;;
        "game")
            file_path="$GAME_BIN_PATH"
            ;;
        "script")
            file_path="$SCRIPT_CURRENT_PATH"
            ;;
        esac

        if [[ ! -f "$file_path" ]]; then
            log "WARN" "$name file not found, forcing update..."
            if ! "$update_func" "$(curl -s "$url" | jq -r .tag_name)" "$(curl -s "$url" | jq -r ".assets[] | select(.name | test(\"$file_ext\")) | .browser_download_url")"; then
                log "ERROR" "Failed to update $name"
                exit 1
            fi
        else
            if [[ $SKIP_UPDATE != *"all"* && $SKIP_UPDATE != *"$name"* ]]; then
                check_and_update "$name" "$url" "$file_ext" "$update_func" "$output_dir"
            fi
        fi
    done

    # Find latest Proton-GE version
    proton_version=$(find "$PROTON_GE_PATH" -maxdepth 1 -type d -name "GE-Proton*" | sort -V | tail -n1) || {
        log "ERROR" "No valid Proton-GE version found"
        exit 1
    }
    proton_path="$proton_version/proton"

    log "DEBUG" "Proton version: $(basename "$proton_version")"
    log "DEBUG" "Proton path: $proton_path"

    # Set environment variables for Wine/Proton
    export WINEPREFIX="$GAME_COMPAT_DATA_PATH"
    export STEAM_COMPAT_DATA_PATH="$GAME_COMPAT_DATA_PATH"
    export STEAM_COMPAT_CLIENT_INSTALL_PATH="$SCRIPT_PATH"

    log "DEBUG" "WINEPREFIX: $WINEPREFIX"
    log "DEBUG" "STEAM_COMPAT_DATA_PATH: $STEAM_COMPAT_DATA_PATH"
    log "DEBUG" "STEAM_COMPAT_CLIENT_INSTALL_PATH: $STEAM_COMPAT_CLIENT_INSTALL_PATH"

    # Run wineboot if WINEPREFIX doesn't exist
    [ -d "$WINEPREFIX" ] || "$proton_path" run wineboot

    log "INFO" "Launching game with $(basename "$proton_version")..."
    "$proton_path" run "$GAME_BIN_PATH"
}

### Start ###
main "$@"
