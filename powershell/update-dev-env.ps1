# Run PowerShell as Administrator

$ErrorActionPreference = "Continue"

Write-Host "=== Windows Update / WSL ==="
wsl --update
wsl --status
wsl --list --verbose

Write-Host "`n=== Winget Packages ==="
if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements
} else {
    Write-Host "winget: not installed"
}

Write-Host "`n=== Microsoft Store Apps ==="
if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget source update
}

Write-Host "`n=== PowerShell Modules ==="
if (Get-Command Update-Module -ErrorAction SilentlyContinue) {
    Update-Module -Force
} else {
    Write-Host "Update-Module: not available"
}

Write-Host "`n=== npm Global Packages ==="
if (Get-Command npm -ErrorAction SilentlyContinue) {
    npm install -g npm@latest
    npm update -g
} else {
    Write-Host "npm: not installed"
}

Write-Host "`n=== Python pip ==="
if (Get-Command python -ErrorAction SilentlyContinue) {
    python -m pip install --upgrade pip
} else {
    Write-Host "python: not installed"
}

Write-Host "`n=== Chocolatey ==="
if (Get-Command choco -ErrorAction SilentlyContinue) {
    choco upgrade all -y
} else {
    Write-Host "choco: not installed"
}

Write-Host "`n=== Scoop ==="
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    scoop update
    scoop update *
    scoop cleanup *
} else {
    Write-Host "scoop: not installed"
}

Write-Host "`n=== Rust ==="
if (Get-Command rustup -ErrorAction SilentlyContinue) {
    rustup update
} else {
    Write-Host "rustup: not installed"
}

Write-Host "`n=== Docker ==="
if (Get-Command docker -ErrorAction SilentlyContinue) {
    docker system prune -f
} else {
    Write-Host "docker: not installed"
}

Write-Host "`n=== Versions ==="

$commands = @(
    "winget",
    "wsl",
    "node",
    "npm",
    "python",
    "pip",
    "git",
    "docker",
    "rustc",
    "cargo",
    "go",
    "java",
    "dotnet",
    "pwsh"
)

foreach ($cmd in $commands) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        Write-Host "`n$cmd"
        try {
            & $cmd --version
        } catch {
            try {
                & $cmd -version
            } catch {
                Write-Host "version check failed"
            }
        }
    } else {
        Write-Host "`n$cmd`: not installed"
    }
}

Write-Host "`nDone."
