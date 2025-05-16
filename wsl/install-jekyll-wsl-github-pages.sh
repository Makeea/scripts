#!/bin/bash

# -------------------------------------------------------------------------
# install-jekyll-wsl-github-pages.sh
# Full setup of Jekyll with GitHub Pages on Ubuntu WSL
# Creates site using: jekyll new myblog and serves it at localhost:4000
# -------------------------------------------------------------------------

echo "[*] Starting Jekyll + GitHub Pages installer for WSL..."

# Check for Ruby
if ! command -v ruby &> /dev/null; then
    echo "[*] Ruby not found. Installing Ruby and build tools..."
    sudo apt update
    sudo apt install -y ruby-full build-essential zlib1g-dev
else
    echo "[✓] Ruby is already installed."
fi

# Check for Git
if ! command -v git &> /dev/null; then
    echo "[*] Git not found. Installing Git..."
    sudo apt install -y git
else
    echo "[✓] Git is already installed."
fi

# Add GEM_HOME and PATH if not already set in .bashrc
if ! grep -q 'GEM_HOME="\$HOME/gems"' ~/.bashrc; then
    echo "[*] Configuring RubyGems environment in ~/.bashrc..."
    echo '# Install Ruby Gems to ~/gems' >> ~/.bashrc
    echo 'export GEM_HOME="$HOME/gems"' >> ~/.bashrc
    echo 'export PATH="$HOME/gems/bin:$PATH"' >> ~/.bashrc
else
    echo "[✓] RubyGems config already exists in ~/.bashrc"
fi

# Apply environment to current shell session
export GEM_HOME="$HOME/gems"
export PATH="$HOME/gems/bin:$PATH"

echo "[*] Applying environment config..."
source ~/.bashrc

# Install bundler if not already available
if ! command -v bundle &> /dev/null; then
    echo "[*] Installing Bundler..."
    gem install bundler
else
    echo "[✓] Bundler is already installed."
fi

# Install Jekyll and GitHub Pages gems
if ! command -v jekyll &> /dev/null; then
    echo "[*] Installing Jekyll and GitHub Pages gem..."
    gem install jekyll github-pages
else
    echo "[✓] Jekyll is already installed."
fi

# Create new Jekyll site if it doesn't exist
SITE_DIR="$HOME/myblog"
if [ ! -d "$SITE_DIR" ]; then
    echo "[*] Creating new Jekyll site at: $SITE_DIR"
    jekyll new "$SITE_DIR"
else
    echo "[✓] Site already exists at: $SITE_DIR"
fi

# Move into the site directory
cd "$SITE_DIR"

# Start the Jekyll server bound to 127.0.0.1 (localhost)
echo "[*] Starting the Jekyll server at http://localhost:4000"
bundle exec jekyll serve --host 127.0.0.1
