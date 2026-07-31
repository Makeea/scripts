#!/usr/bin/env bash

set -e

echo "=== Ubuntu ==="
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y

echo
echo "=== Snap ==="
if command -v snap >/dev/null 2>&1; then
    sudo snap refresh
else
    echo "snap: not installed"
fi

echo
echo "=== Node / npm ==="
if command -v npm >/dev/null 2>&1; then
    npm install -g npm@latest
    npm update -g
else
    echo "npm: not installed"
fi

echo
echo "=== Claude Code ==="
if command -v claude >/dev/null 2>&1; then
    npm update -g @anthropic-ai/claude-code || true
else
    echo "claude: not installed"
fi

echo
echo "=== Python / pip ==="
if command -v pip3 >/dev/null 2>&1; then
    pip3 install --upgrade pip --break-system-packages || pip3 install --upgrade pip || true
else
    echo "pip3: not installed"
fi

echo
echo "=== Rust ==="
if command -v rustup >/dev/null 2>&1; then
    rustup update
else
    echo "rustup: not installed"
fi

echo
echo "=== Go tools ==="
if command -v go >/dev/null 2>&1; then
    go install golang.org/x/tools/gopls@latest || true
else
    echo "go: not installed"
fi

echo
echo "=== SDKMAN ==="
if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
    source "$HOME/.sdkman/bin/sdkman-init.sh"
    sdk selfupdate || true
    sdk update || true
else
    echo "sdkman: not installed"
fi

echo
echo "=== Homebrew ==="
if command -v brew >/dev/null 2>&1; then
    brew update
    brew upgrade
    brew cleanup
else
    echo "brew: not installed"
fi

echo
echo "=== Conda ==="
if command -v conda >/dev/null 2>&1; then
    conda update -n base -c defaults conda -y || true
else
    echo "conda: not installed"
fi

echo
echo "=== Docker ==="
if command -v docker >/dev/null 2>&1; then
    docker system prune -f || true
else
    echo "docker: not installed"
fi

echo
echo "=== Versions ==="

if command -v node >/dev/null 2>&1; then
    node --version
else
    echo "node: not installed"
fi

if command -v npm >/dev/null 2>&1; then
    npm --version
else
    echo "npm: not installed"
fi

if command -v python3 >/dev/null 2>&1; then
    python3 --version
else
    echo "python3: not installed"
fi

if command -v pip3 >/dev/null 2>&1; then
    pip3 --version
else
    echo "pip3: not installed"
fi

if command -v rustc >/dev/null 2>&1; then
    rustc --version
else
    echo "rustc: not installed"
fi

if command -v cargo >/dev/null 2>&1; then
    cargo --version
else
    echo "cargo: not installed"
fi

if command -v go >/dev/null 2>&1; then
    go version
else
    echo "go: not installed"
fi

if command -v java >/dev/null 2>&1; then
    java -version 2>&1 | head -1
else
    echo "java: not installed"
fi

if command -v docker >/dev/null 2>&1; then
    docker --version
else
    echo "docker: not installed"
fi

if command -v claude >/dev/null 2>&1; then
    claude --version
else
    echo "claude: not installed"
fi

echo
echo "Done."
