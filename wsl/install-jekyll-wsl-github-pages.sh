#!/bin/bash

# -----------------------------------------------------------------------------
# install-jekyll-latest.sh
# Installs the latest version of Ruby (3.2.x), Jekyll, and Bundler for Ubuntu WSL
# -----------------------------------------------------------------------------

echo "[*] Starting Jekyll installation with Ruby 3.2.x..."

# Install dependencies
sudo apt update
sudo apt install -y git curl libssl-dev libreadline-dev zlib1g-dev build-essential autoconf bison libyaml-dev libncurses5-dev libffi-dev libgdbm-dev

# Install rbenv if it's not installed
if [ ! -d "$HOME/.rbenv" ]; then
    echo "[*] Installing rbenv..."
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    cd ~/.rbenv && src/configure && make -C src
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(rbenv init - bash)"' >> ~/.bashrc
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init - bash)"
else
    echo "[✓] rbenv already installed."
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init - bash)"
fi

# Install ruby-build if it's not installed
if [ ! -d "$HOME/.rbenv/plugins/ruby-build" ]; then
    echo "[*] Installing ruby-build plugin..."
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
else
    echo "[✓] ruby-build already installed."
fi

# Install the latest stable Ruby version (3.2.x)
echo "[*] Installing Ruby 3.2.x..."
rbenv install 3.2.0
rbenv global 3.2.0
rbenv rehash

# Install Bundler (latest version)
echo "[*] Installing Bundler..."
gem install bundler
rbenv rehash

# Install the latest version of Jekyll
echo "[*] Installing the latest version of Jekyll..."
gem install jekyll
rbenv rehash

# Verify Jekyll installation
echo "[*] Verifying Jekyll installation..."
jekyll -v

# Create Jekyll site if not exists
SITE_DIR="$HOME/myblog"
if [ ! -d "$SITE_DIR" ]; then
    echo "[*] Creating Jekyll site at $SITE_DIR"
    jekyll new "$SITE_DIR"
    if [ $? -ne 0 ]; then
        echo "[❌] Failed to create Jekyll site. Exiting."
        exit 1
    fi
else
    echo "[✓] Site already exists: $SITE_DIR"
fi

cd "$SITE_DIR" || { echo "[❌] Could not cd into $SITE_DIR"; exit 1; }

if [ ! -f "Gemfile" ]; then
    echo "[❌] Gemfile not found in $SITE_DIR. Something went wrong."
    exit 1
fi

echo ""
echo "✅ Your Jekyll site is ready!"
echo ""
echo "📍 SITE DIRECTORY:"
echo "   $SITE_DIR"
echo ""
echo "▶ TO SERVE THE SITE LOCALLY:"
echo "   bundle exec jekyll serve --host 127.0.0.1 --watch"
echo ""
echo "🌐 Then open your browser and go to:"
echo "   http://localhost:4000"
echo ""
echo "🔁 FOR FUTURE PROJECTS:"
echo "If you clone or copy a Jekyll project that has a Gemfile, run:"
echo "   bundle install"
echo "Then run:"
echo "   bundle exec jekyll serve --host 127.0.0.1 --watch"
echo ""

# Reload the shell environment to apply changes
echo "[*] Reloading shell environment..."
source ~/.bashrc

# Serve the site with live reload
bundle exec jekyll serve --host 127.0.0.1 --watch
