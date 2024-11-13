#!/bin/bash

GO_VERSION=1.23.2

echo "===========================================================================" 
echo " ✨ QNODE MACOS SETUP ✨" 
echo "==========================================================================="
echo "" 
echo "⏳ Processing... " 
sleep 3

# Determine the Go binary name for macOS
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    GO_BINARY="go$GO_VERSION.darwin-amd64.tar.gz"
elif [ "$ARCH" = "arm64" ]; then
    GO_BINARY="go$GO_VERSION.darwin-arm64.tar.gz"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

# Install Homebrew if not already installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "Homebrew is already installed."
fi

# Install required packages
echo "Installing required packages..."
brew install git wget curl jq tmux

# Install Go
echo "Installing Go $GO_VERSION..."
wget https://go.dev/dl/$GO_BINARY
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf $GO_BINARY
rm $GO_BINARY

# Set Go environment variables
echo "Setting Go environment variables..."
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.zshrc
echo "export GOPATH=$HOME/go" >> ~/.zshrc
echo "export GO111MODULE=on" >> ~/.zshrc
echo "export GOPROXY=https://goproxy.cn,direct" >> ~/.zshrc

# Source .zshrc to apply changes
source ~/.zshrc

# Install gRPCurl
echo "Installing gRPCurl..."
go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest

# Create useful folders
echo "Creating backup and scripts folders..."
mkdir -p ~/backup/
mkdir -p ~/scripts/
mkdir -p ~/scripts/log/

echo "✅ macOS setup for Quilibrium node is complete!"
echo "Please restart your terminal or run 'source ~/.zshrc' to apply the changes."
