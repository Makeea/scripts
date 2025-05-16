#!/bin/bash

# ----------------------------------------------------------------------
# uninstall-jekyll-wsl.sh
# Fully removes Jekyll, GitHub Pages setup, Ruby, RubyGems from WSL
# ----------------------------------------------------------------------

echo "[*] Removing Jekyll site directory ~/myblog..."
rm -rf "$HOME/myblog"

echo "[*] Removing local RubyGems from ~/gems..."
rm -rf "$HOME/gems"

echo "[*] Cleaning up environment config in ~/.bashrc..."
sed -i '/# Install Ruby Gems to ~\/gems/d' ~/.bashrc
sed -i '/export GEM_HOME="\$HOME\/gems"/d' ~/.bashrc
sed -i '/export PATH="\$HOME\/gems\/bin:\$PATH"/d' ~/.bashrc

echo "[*] Uninstalling Ruby, RubyGems, Bundler, Git, and build tools..."
sudo apt remove --purge -y ruby ruby-full rubygems bundler git build-essential zlib1g-dev
sudo apt autoremove -y

echo "[*] Reloading shell configuration with source ~/.bashrc..."
source ~/.bashrc

echo ""
echo "[✓] Jekyll and all related components have been removed."
echo "💡 Your shell environment has been refreshed."
