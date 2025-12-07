# meldoc installer for Windows
# Usage: irm https://raw.githubusercontent.com/meldoc-io/meldoc-cli/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

# Configuration
$ReleasesRepo = "meldoc-io/meldoc-cli"
$BinaryName = "meldoc"
$BaseUrl = "https://raw.githubusercontent.com/$ReleasesRepo/main"

# Installation directory
$InstallDir = if ($env:MELDOC_INSTALL_DIR) {
    $env:MELDOC_INSTALL_DIR
} else {
    "$env:LOCALAPPDATA\meldoc"
}

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "ℹ " -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "✗ " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

# Detect architecture
function Get-Architecture {
    $arch = $env:PROCESSOR_ARCHITECTURE
    
    switch ($arch) {
        "AMD64" { return "amd64" }
        "ARM64" { return "arm64" }
        default {
            Write-Error-Custom "Unsupported architecture: $arch"
            exit 1
        }
    }
}

# Get latest version from LATEST file
function Get-LatestVersion {
    Write-Info "Fetching latest version..."
    
    try {
        $version = (Invoke-WebRequest -Uri "$BaseUrl/LATEST" -UseBasicParsing).Content.Trim()
        if ([string]::IsNullOrWhiteSpace($version)) {
            throw "Empty version"
        }
        Write-Info "Latest version: $version"
        return $version
    }
    catch {
        Write-Error-Custom "Could not determine latest version: $_"
        exit 1
    }
}

# Verify checksum
function Test-Checksum {
    param(
        [string]$FilePath,
        [string]$ChecksumsFile
    )
    
    if (-not (Test-Path $ChecksumsFile)) {
        Write-Warning "SHA256SUMS file not found, skipping verification"
        return $true
    }
    
    Write-Info "Verifying checksum..."
    
    $fileName = Split-Path $FilePath -Leaf
    $checksumContent = Get-Content $ChecksumsFile
    $expectedLine = $checksumContent | Where-Object { $_ -match [regex]::Escape($fileName) } | Select-Object -First 1
    
    if (-not $expectedLine) {
        Write-Warning "Checksum not found for $fileName"
        return $true
    }
    
    $expectedSum = ($expectedLine -split '\s+')[0]
    
    $actualSum = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash.ToLower()
    $expectedSum = $expectedSum.ToLower()
    
    if ($actualSum -eq $expectedSum) {
        Write-Success "Checksum verified"
        return $true
    }
    else {
        Write-Error-Custom "Checksum verification failed!"
        Write-Error-Custom "Expected: $expectedSum"
        Write-Error-Custom "Got:      $actualSum"
        return $false
    }
}

# Download and install binary
function Install-Meldoc {
    param(
        [string]$Version,
        [string]$Arch
    )
    
    $archiveName = "$BinaryName-windows-$Arch.zip"
    $downloadUrl = "$BaseUrl/$Version/$archiveName"
    $checksumsUrl = "$BaseUrl/$Version/SHA256SUMS"
    $tempDir = Join-Path $env:TEMP "meldoc-install-$(Get-Random)"
    
    try {
        # Create temp directory
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        Write-Info "Downloading $archiveName..."
        $archivePath = Join-Path $tempDir $archiveName
        
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath -UseBasicParsing
        }
        catch {
            Write-Error-Custom "Failed to download binary from $downloadUrl"
            Write-Error-Custom $_.Exception.Message
            exit 1
        }
        
        # Download checksums
        $checksumsPath = Join-Path $tempDir "SHA256SUMS"
        try {
            Invoke-WebRequest -Uri $checksumsUrl -OutFile $checksumsPath -UseBasicParsing
            if (-not (Test-Checksum -FilePath $archivePath -ChecksumsFile $checksumsPath)) {
                exit 1
            }
        }
        catch {
            Write-Warning "Could not download SHA256SUMS, skipping verification"
        }
        
        Write-Info "Extracting archive..."
        Expand-Archive -Path $archivePath -DestinationPath $tempDir -Force
        
        # Find binary
        $binaryPath = Get-ChildItem -Path $tempDir -Filter "$BinaryName*.exe" -Recurse | Select-Object -First 1
        
        if (-not $binaryPath) {
            Write-Error-Custom "Binary not found in archive"
            exit 1
        }
        
        # Create install directory
        if (-not (Test-Path $InstallDir)) {
            Write-Info "Creating install directory: $InstallDir"
            New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
        }
        
        # Install binary
        $targetPath = Join-Path $InstallDir "$BinaryName.exe"
        Write-Info "Installing to $targetPath..."
        
        Copy-Item -Path $binaryPath.FullName -Destination $targetPath -Force
        
        Write-Success "meldoc installed successfully!"
        
        # Add to PATH if not already there
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath -notlike "*$InstallDir*") {
            Write-Info "Adding to PATH..."
            [Environment]::SetEnvironmentVariable(
                "Path",
                "$userPath;$InstallDir",
                "User"
            )
            Write-Success "Added to PATH (restart your terminal to apply)"
        }
    }
    finally {
        # Cleanup
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Verify installation
function Test-Installation {
    Write-Info "Verifying installation..."
    
    # Refresh environment variables for current session
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    
    $meldocPath = Join-Path $InstallDir "$BinaryName.exe"
    
    if (Test-Path $meldocPath) {
        Write-Success "Installation verified"
        Write-Host ""
        
        try {
            $version = & $meldocPath version 2>&1
            Write-Host "  $BinaryName version: $version"
        }
        catch {
            Write-Host "  $BinaryName installed at: $meldocPath"
        }
        
        Write-Host ""
        Write-Host "🚀 Get started:"
        Write-Host "  PS> meldoc --help"
        Write-Host "  PS> meldoc init"
        Write-Host ""
        Write-Host "Note: Restart your terminal to use 'meldoc' command"
        Write-Host "      or use the full path: $meldocPath"
        Write-Host ""
    }
    else {
        Write-Warning "Installation may have failed"
        Write-Host ""
        Write-Host "Expected location: $meldocPath"
        Write-Host ""
    }
}

# Main installation flow
function Main {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════╗"
    Write-Host "║     meldoc CLI Installer              ║"
    Write-Host "╚═══════════════════════════════════════╝"
    Write-Host ""
    
    $arch = Get-Architecture
    Write-Info "Detected architecture: $arch"
    
    $version = Get-LatestVersion
    
    Install-Meldoc -Version $version -Arch $arch
    
    Test-Installation
    
    Write-Host "📚 Documentation: https://github.com/$ReleasesRepo"
    Write-Host ""
}

# Run main function
Main
