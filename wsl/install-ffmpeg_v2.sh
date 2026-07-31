#!/bin/bash

# Script to install FFmpeg and check its capabilities
# Improved version with error handling and compatibility updates

# Exit on error
set -e

echo "=== FFmpeg Installation Script ==="

# Check if running as root (sudo)
if [ "$(id -u)" != "0" ]; then
   echo "This script needs to be run with sudo. Prepending sudo to commands."
   SUDO="sudo"
else
   SUDO=""
fi

# Check which system we're on
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo "Cannot determine OS distribution. Assuming Ubuntu/Debian."
    OS="ubuntu"
fi

echo "Detected OS: $OS"

# Install FFmpeg based on the OS
case $OS in
    ubuntu|debian)
        # First try the official repository
        echo "Adding FFmpeg repository..."
        $SUDO apt-get update
        # Check if add-apt-repository command exists
        if ! command -v add-apt-repository &> /dev/null; then
            echo "Installing software-properties-common to get add-apt-repository..."
            $SUDO apt-get install -y software-properties-common
        fi
        
        # Try to add the repository - use a modern repo instead of trusty-media
        echo "Adding FFmpeg repository..."
        $SUDO add-apt-repository -y ppa:savoury1/ffmpeg4
        
        # Fix the typo in apt- update (was missing "get")
        echo "Updating package lists..."
        $SUDO apt-get -y update
        
        # Install FFmpeg
        echo "Installing FFmpeg..."
        $SUDO apt-get install -y ffmpeg
        ;;
    fedora|centos|rhel)
        # For Red Hat based systems
        echo "Installing FFmpeg on Red Hat based system..."
        $SUDO dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
        $SUDO dnf install -y ffmpeg ffmpeg-devel
        ;;
    arch|manjaro)
        # For Arch based systems
        echo "Installing FFmpeg on Arch based system..."
        $SUDO pacman -S --noconfirm ffmpeg
        ;;
    *)
        echo "Unsupported OS. Trying generic Ubuntu/Debian approach..."
        $SUDO apt-get update
        $SUDO apt-get install -y ffmpeg
        ;;
esac

# Check if FFmpeg was installed successfully
if command -v ffmpeg &> /dev/null; then
    echo "=== FFmpeg installed successfully ==="
    echo "FFmpeg version information:"
    ffmpeg -version
    
    echo "=== Available encoders ==="
    ffmpeg -encoders | head -20
    echo "(Showing first 20 encoders. Run 'ffmpeg -encoders' to see all)"
    
    echo "=== Available decoders ==="
    ffmpeg -decoders | head -20
    echo "(Showing first 20 decoders. Run 'ffmpeg -decoders' to see all)"
else
    echo "ERROR: FFmpeg installation failed!"
    exit 1
fi

echo "=== FFmpeg installation and verification complete ==="