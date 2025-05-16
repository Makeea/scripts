#!/bin/bash

# -----------------------------------------------------------------------------
# install-jekyll-wsl-github-pages.sh
# Sets up Jekyll + GitHub Pages on Ubuntu WSL using Ruby 2.7.8 via rbenv
# -----------------------------------------------------------------------------

echo "[*] Starting full Jekyll + GitHub Pages install for WSL (Ruby 2.7.8)..."

# Install dependencies
echo "[*] Installing system packages..."
sudo apt update
sudo apt install -y git curl libssl-dev libreadline-dev zlib1g-dev build-essential autoconf bison libyaml-dev libncurses5-dev libffi-dev libgdbm-dev

# Install rbenv
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

# Install ruby-build
if [ ! -d "$HOME/.rbenv/plugins/ruby-build" ]; then
    echo "[*] Installing ruby-build plugin..."
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
else
    echo "[✓] ruby-build already installed."
fi

# Install Ruby 2.7.8 if not already installed
if ! rbenv versions | grep -q "2.7.8"; then
    echo "[*] Installing Ruby 2.7.8..."
    rbenv install 2.7.8
else
    echo "[✓] Ruby 2.7.8 already installed."
fi

# Set Ruby 2.7.8 as global
rbenv global 2.7.8
rbenv rehash

# Install bundler and github-pages gems
echo "[*] Installing Bundler and GitHub Pages gems..."
gem install bundler
gem install github-pages
rbenv rehash

# Create Jekyll site if not exists
SITE_DIR="$HOME/myblog"
if [ ! -d "$SITE_DIR" ]; then
    echo "[*] Creating Jekyll site: $SITE_DIR"
    jekyll new "$SITE_DIR"
else
    echo "[✓] Jekyll site already exists at $SITE_DIR"
fi

# Change into site directory
cd "$SITE_DIR"

# Info message before starting server
echo ""
echo "✅ Your Jekyll site is ready!"
echo ""
echo "📍 SITE DIRECTORY:"
echo "   $SITE_DIR"
echo ""
echo "▶ TO SERVE THE SITE LOCALLY:"
echo "   bundle exec jekyll serve --host 127.0.0.1"
echo ""
echo "🌐 Then open your browser and go to:"
echo "   http://localhost:4000"
echo ""
echo "🔁 FOR FUTURE PROJECTS:"
echo "If you clone or copy a Jekyll project that has a Gemfile, run:"
echo "   bundle install"
echo "This installs the required gems listed in the Gemfile."
echo ""
echo "Then you can run the Jekyll server with:"
echo "   bundle exec jekyll serve --host 127.0.0.1"
echo ""

# Start the server
bundle exec jekyll serve --host 127.0.0.1
