#!/bin/bash

# -----------------------------------------------------------------------------
# uninstall-jekyll-wsl.sh
# Cleans up Ruby, rbenv, Jekyll, GitHub Pages setup on WSL (keeps build tools)
# -----------------------------------------------------------------------------

echo "[*] Removing Jekyll site directory at ~/myblog..."
rm -rf "$HOME/myblog"

echo "[*] Removing RubyGems directory ~/gems..."
rm -rf "$HOME/gems"

echo "[*] Removing rbenv and Ruby versions..."
rm -rf "$HOME/.rbenv"

echo "[*] Cleaning up .bashrc entries added by rbenv or Jekyll setup..."
sed -i '/rbenv/d' ~/.bashrc
sed -i '/GEM_HOME/d' ~/.bashrc
sed -i '/gems\/bin/d' ~/.bashrc

echo "[*] Reloading shell configuration with source ~/.bashrc..."
source ~/.bashrc

echo ""
echo "[✓] Uninstallation complete."
echo "💡 Ruby, rbenv, and Jekyll have been removed."
echo "✅ Your build tools and git are still installed."
