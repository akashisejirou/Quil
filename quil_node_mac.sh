#!/bin/bash

# Step 0: Welcome

#Comment out for automatic creation of the node version
#NODE_VERSION=2.0.3

#Comment out for automatic creation of the qclient version
#QCLIENT_VERSION=2.0.2.4

SCRIPT_VERSION="2.0"

cat << EOF

===========================================================================
                 ✨ QNODE / QCLIENT INSTALLER - $SCRIPT_VERSION ✨
===========================================================================

Processing... ⏳

EOF

sleep 7  # Add a 7-second delay

# Function to display section headers
display_header() {
    echo
    echo "=============================================================="
    echo "$1"
    echo "=============================================================="
    echo
}

#==========================
# INSTALL HOMEBREW (MacOS)
#==========================

display_header "INSTALLING REQUIRED APPLICATIONS"

# Function to check and install a package using Homebrew (MacOS)
check_and_install() {
    if ! command -v $1 &> /dev/null; then
        echo "$1 could not be found"
        echo "⏳ Installing $1..."
        if ! command -v brew &> /dev/null; then
            echo "Homebrew not found, installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
        fi
        brew install $1
        echo
    else
        echo "✅ $1 is installed"
        echo
    fi
}

# Install required applications
check_and_install git
check_and_install curl

#==========================
# CREATE PATH VARIABLES
#==========================

display_header "CREATING PATH VARIABLES"

#useful variables
SERVICE_FILE="$HOME/Library/LaunchAgents/com.ceremonyclient.plist"
QUILIBRIUM_RELEASES="https://releases.quilibrium.com"
NODE_RELEASE_URL="https://releases.quilibrium.com/release"
QCLIENT_RELEASE_URL="https://releases.quilibrium.com/qclient-release"

# Determine node latest version
if [ -z "$NODE_VERSION" ]; then
    NODE_VERSION=$(curl -s "$NODE_RELEASE_URL" | grep -E "^node-[0-9]+(\.[0-9]+)*" | grep -v "dgst" | sed 's/^node-//' | cut -d '-' -f 1 | head -n 1)
    if [ -z "$NODE_VERSION" ]; then
        echo "❌ Error: Unable to determine the latest node release automatically."
        exit 1
    else
        echo "✅ Latest Node release: $NODE_VERSION"
    fi
else
    echo "✅ Using specified Node version: $NODE_VERSION"
fi

# Determine qclient latest version
if [ -z "$QCLIENT_VERSION" ]; then
    QCLIENT_VERSION=$(curl -s "$QCLIENT_RELEASE_URL" | grep -E "^qclient-[0-9]+(\.[0-9]+)*" | sed 's/^qclient-//' | cut -d '-' -f 1 |  head -n 1)
    if [ -z "$QCLIENT_VERSION" ]; then
        echo "⚠️ Warning: Unable to determine the latest Qclient release automatically. Continuing without it."
    else
        echo "✅ Latest Qclient release: $QCLIENT_VERSION"
    fi
else
    echo "✅ Using specified Qclient version: $QCLIENT_VERSION"
fi

# Detect OS and architecture for macOS
case "$(uname -m)" in
    "x86_64") release_arch="amd64" ;;
    "arm64") release_arch="arm64" ;;
    *) echo "❌ Error: Unsupported system architecture ($(uname -m))"; exit 1 ;;
esac

release_os="darwin"

# Set binary names based on detected OS and architecture
NODE_BINARY="node-$NODE_VERSION-$release_os-$release_arch"
QCLIENT_BINARY="qclient-$QCLIENT_VERSION-$release_os-$release_arch"

#==========================
# GIT CLONE
#==========================

display_header "UPDATING CEREMONYCLIENT REPO"
cd $HOME
if [ -d "ceremonyclient" ]; then
    echo "⚠️ The directory 'ceremonyclient' already exists. Skipping git clone..."
else
    until git clone --depth 1 --branch release https://github.com/QuilibriumNetwork/ceremonyclient.git || git clone https://source.quilibrium.com/quilibrium/ceremonyclient.git; do
        echo "Git clone failed, retrying..."
        sleep 2
    done
fi

#==========================
# NODE BINARY DOWNLOAD
#==========================

display_header "DOWNLOADING NODE BINARY"

mkdir -p "$HOME/ceremonyclient/node"
mkdir -p "$HOME/ceremonyclient/client"

# Download files for the node
if ! cd "$HOME/ceremonyclient/node"; then
    echo "❌ Error: Unable to change to the node directory"
    exit 1
fi

files=$(curl -s -f "$NODE_RELEASE_URL" | grep "$release_os-$release_arch" || true)

for file in $files; do
    if ! test -f "./$file"; then
        curl -s -f "$QUILIBRIUM_RELEASES/$file" > "$file"
        chmod +x "$file"
    else
        echo "File $file already exists, skipping"
    fi
done

#==========================
# DOWNLOAD QCLIENT
#==========================

display_header "UPDATING QCLIENT"

if ! cd "$HOME/ceremonyclient/client"; then
    echo "❌ Error: Unable to change to the qclient directory"
    exit 1
fi

files=$(curl -s -f "$QCLIENT_RELEASE_URL" | grep "$release_os-$release_arch" || true)

for file in $files; do
    if ! test -f "./$file"; then
        curl -s -f "$QUILIBRIUM_RELEASES/$file" > "$file"
        chmod +x "$file"
    else
        echo "File $file already exists, skipping"
    fi
done

#==========================
# SETUP LAUNCHD SERVICE (MacOS)
#==========================

display_header "CREATING SERVICE FILE"

NODE_PATH="$HOME/ceremonyclient/node"
EXEC_START="$NODE_PATH/$NODE_BINARY"

PLIST_CONTENT="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
    <key>Label</key>
    <string>com.ceremonyclient</string>
    <key>ProgramArguments</key>
    <array>
        <string>$EXEC_START</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/ceremonyclient.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/ceremonyclient.error</string>
</dict>
</plist>"

echo "$PLIST_CONTENT" > "$SERVICE_FILE"
launchctl load "$SERVICE_FILE"
launchctl start com.ceremonyclient

echo "✅ Ceremonyclient service started. Use 'launchctl log show --style syslog | grep com.ceremonyclient' to view logs."
