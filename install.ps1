#Requires -Version 5.1
<#
.SYNOPSIS
    Meldoc CLI Installer for Windows

.DESCRIPTION
    Downloads and installs Meldoc CLI binary from GitHub Releases.

.PARAMETER Global
    Install system-wide (requires Administrator privileges)

.PARAMETER Dir
    Install to specific directory

.PARAMETER Version
    Install specific version (default: latest)

.PARAMETER Force
    Overwrite existing installation

.PARAMETER NoPathHint
    Don't show PATH configuration hints

.PARAMETER Quiet
    Minimal output (for CI/CD)

.EXAMPLE
    irm https://meldoc.io/install.ps1 | iex
    Install to user directory

.EXAMPLE
    .\install.ps1 -Global
    Install system-wide (requires admin)

.EXAMPLE
    .\install.ps1 -Dir "$HOME\bin"
    Install to specific directory
#>

[CmdletBinding()]
param(
    [switch]$Global,
    [string]$Dir = "",
    [string]$Version = "latest",
    [switch]$Force,
    [switch]$NoPathHint,
    [switch]$NoPathSetup,
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

# ============================================================================
# Configuration - CHANGE THESE FOR YOUR PROJECT
# ============================================================================
$ToolName = "meldoc"
$GitHubRepo = "meldoc-io/meldoc-cli"
$GitHubApi = "https://api.github.com/repos/$GitHubRepo"
$GitHubReleases = "https://github.com/$GitHubRepo/releases"

# ============================================================================
# Logging functions
# ============================================================================
function Write-Info {
    param([string]$Message)
    if ($Quiet) { return }
    Write-Host "==> " -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    if ($Quiet) { return }
    Write-Host "✓ " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warn {
    param([string]$Message)
    Write-Host "⚠ " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Err {
    param([string]$Message)
    Write-Host "✗ " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Write-Output-Msg {
    param([string]$Message)
    if ($Quiet) { return }
    Write-Host $Message
}

# ============================================================================
# Helper Functions
# ============================================================================
function Test-IsAdmin {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Dir([string]$Path) {
    if (!(Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Test-InPath([string]$Path) {
    $paths = $env:PATH -split ';' | ForEach-Object { $_.TrimEnd('\') }
    $normalizedPath = $Path.TrimEnd('\')
    return $paths -contains $normalizedPath
}

# ============================================================================
# Banner
# ============================================================================
if (-not $Quiet) {
    Write-Host ""
    Write-Host "                 _     _            " -ForegroundColor Cyan
    Write-Host "  _ __ ___   ___| | __| | ___   ___ " -ForegroundColor Cyan
    Write-Host " | '_ `` _ \ / _ \ |/ _`` |/ _ \ / __|" -ForegroundColor Cyan
    Write-Host " | | | | | |  __/ | (_| | (_) | (__ " -ForegroundColor Cyan
    Write-Host " |_| |_| |_|\___|_|\__,_|\___/ \___|" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Meldoc CLI Installer" -ForegroundColor White
    Write-Host ""
}

# Quiet mode implies no path hints
if ($Quiet) { $NoPathHint = $true }

# ============================================================================
# Pre-flight Checks
# ============================================================================
Write-Info "Checking prerequisites..."

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Err "PowerShell 5.1 or higher is required. Current version: $($PSVersionTable.PSVersion)"
    exit 1
}

# Check admin rights if global install
if ($Global -and !(Test-IsAdmin)) {
    Write-Err "Global installation requires Administrator privileges."
    Write-Host ""
    Write-Host "Please run PowerShell as Administrator, or omit -Global flag for user installation."
    Write-Host ""
    Write-Host "To run as Administrator:"
    Write-Host "  1. Right-click PowerShell icon"
    Write-Host "  2. Select 'Run as Administrator'"
    Write-Host "  3. Run the script again with -Global"
    exit 1
}

# ============================================================================
# Platform Detection
# ============================================================================
Write-Info "Detecting platform..."

$OS = "windows"
$Arch = switch ($env:PROCESSOR_ARCHITECTURE) {
    "AMD64" { "amd64" }
    "ARM64" { "arm64" }
    default {
        Write-Err "Unsupported architecture: $env:PROCESSOR_ARCHITECTURE"
        exit 1
    }
}

Write-Output-Msg "  Platform: $OS/$Arch"

# ============================================================================
# Version Resolution (using GitHub API)
# ============================================================================
Write-Info "Resolving version..."

if ($Version -eq "latest") {
    try {
        # Get latest release from GitHub API
        $headers = @{
            "Accept" = "application/vnd.github.v3+json"
            "User-Agent" = "MeldocInstaller"
        }
        
        $releaseInfo = Invoke-RestMethod -Uri "$GitHubApi/releases/latest" -Headers $headers -UseBasicParsing
        $VersionTag = $releaseInfo.tag_name
        
        if ([string]::IsNullOrWhiteSpace($VersionTag)) {
            throw "Could not determine latest version"
        }
        
        $ResolvedVersion = $VersionTag.TrimStart('v')
    }
    catch {
        Write-Err "Could not fetch release information from GitHub: $_"
        exit 1
    }
} else {
    if ($Version -match '^v') {
        $VersionTag = $Version
        $ResolvedVersion = $Version.TrimStart('v')
    } else {
        $VersionTag = "v$Version"
        $ResolvedVersion = $Version
    }
}

Write-Output-Msg "  Version: $VersionTag"

# ============================================================================
# Target Directory Resolution
# ============================================================================
if ($Dir -ne "") {
    $TargetDir = $Dir
} elseif ($Global) {
    $TargetDir = Join-Path $env:ProgramFiles "$ToolName\bin"
} else {
    $TargetDir = Join-Path $env:LOCALAPPDATA "Programs\$ToolName\bin"
}

Write-Output-Msg "  Install directory: $TargetDir"

# ============================================================================
# Check Existing Installation
# ============================================================================
$DestPath = Join-Path $TargetDir "$ToolName.exe"

if ((Test-Path $DestPath) -and !$Force) {
    $existingVer = "unknown"
    try {
        $existingVer = & $DestPath version 2>$null | Select-Object -First 1
    } catch {}
    
    Write-Output-Msg ""
    Write-Warn "Already installed: $existingVer"
    Write-Output-Msg "  Location: $DestPath"
    Write-Output-Msg ""
    Write-Output-Msg "  Use -Force to overwrite, or -Version to install different version"
    exit 0
}

# ============================================================================
# Download Artifact from GitHub Releases
# ============================================================================
$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "meldoc-install-$([System.Guid]::NewGuid().ToString('N'))"
Ensure-Dir $TempDir

try {
    # Build artifact name: meldoc-{version}-windows-{arch}.zip
    $Artifact = "$ToolName-$ResolvedVersion-$OS-$Arch.zip"
    
    # GitHub Releases download URL
    $Url = "$GitHubReleases/download/$VersionTag/$Artifact"
    $ChecksumsUrl = "$GitHubReleases/download/$VersionTag/SHA256SUMS"

    Write-Info "Downloading $ToolName $VersionTag..."
    Write-Output-Msg "  From: $Url"
    
    $ArtifactPath = Join-Path $TempDir $Artifact
    
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $ArtifactPath -UseBasicParsing
        $ProgressPreference = 'Continue'
    } catch {
        Write-Err "Download failed"
        Write-Host ""
        Write-Host "Please check:"
        Write-Host "  - Version exists: $VersionTag"
        Write-Host "  - Artifact exists: $Artifact"
        Write-Host "  - Releases page: $GitHubReleases"
        Write-Host ""
        Write-Host "Error: $_"
        exit 1
    }

    # Validate download
    if (!(Test-Path $ArtifactPath) -or (Get-Item $ArtifactPath).Length -eq 0) {
        Write-Err "Downloaded file is empty or doesn't exist"
        exit 1
    }
    
    Write-Success "Downloaded successfully"

    # ============================================================================
    # Verify Checksum (optional)
    # ============================================================================
    $ChecksumsPath = Join-Path $TempDir "SHA256SUMS"
    try {
        Invoke-WebRequest -Uri $ChecksumsUrl -OutFile $ChecksumsPath -UseBasicParsing
        
        Write-Info "Verifying checksum..."
        
        $checksumContent = Get-Content $ChecksumsPath
        $expectedLine = $checksumContent | Where-Object { $_ -match [regex]::Escape($Artifact) } | Select-Object -First 1
        
        if ($expectedLine) {
            $expectedSum = ($expectedLine -split '\s+')[0].ToLower()
            $actualSum = (Get-FileHash -Path $ArtifactPath -Algorithm SHA256).Hash.ToLower()
            
            if ($actualSum -eq $expectedSum) {
                Write-Success "Checksum verified"
            } else {
                Write-Err "Checksum verification failed!"
                Write-Host "Expected: $expectedSum"
                Write-Host "Got:      $actualSum"
                exit 1
            }
        } else {
            Write-Warn "Checksum not found for $Artifact"
        }
    } catch {
        Write-Warn "Could not download SHA256SUMS, skipping verification"
    }

    # ============================================================================
    # Extract Artifact
    # ============================================================================
    Write-Info "Extracting archive..."
    
    try {
        Expand-Archive -Path $ArtifactPath -DestinationPath $TempDir -Force
    } catch {
        Write-Err "Failed to extract archive: $_"
        exit 1
    }

    # ============================================================================
    # Locate Binary
    # ============================================================================
    $BinPath = Join-Path $TempDir "$ToolName.exe"
    if (!(Test-Path $BinPath)) {
        # Fallback: search in subdirectories
        $BinPath = Get-ChildItem -Path $TempDir -Recurse -Filter "*.exe" |
                   Where-Object { $_.Name -match "^${ToolName}(\.exe)?$" } |
                   Select-Object -First 1 |
                   ForEach-Object { $_.FullName }
    }

    if (!(Test-Path $BinPath)) {
        Write-Err "Binary not found after extraction."
        Write-Host "Expected: $ToolName.exe"
        Write-Host ""
        Write-Host "Extracted contents:"
        Get-ChildItem $TempDir -Recurse | Out-String | Write-Host
        exit 1
    }

    # ============================================================================
    # Install Binary (atomic)
    # ============================================================================
    Write-Info "Installing binary..."

    Ensure-Dir $TargetDir

    $DestNew = Join-Path $TargetDir "$ToolName.new.$PID.exe"
    
    Copy-Item -Path $BinPath -Destination $DestNew -Force
    Move-Item -Path $DestNew -Destination $DestPath -Force

    # ============================================================================
    # Installation Summary
    # ============================================================================
    $installedVer = "unknown"
    try {
        $installedVer = & $DestPath version 2>$null | Select-Object -First 1
    } catch {}
    
    if ($Quiet) {
        Write-Host $DestPath
    } else {
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
        Write-Host "  ✓ Installation successful!" -ForegroundColor Green
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Location: $DestPath"
        Write-Host "  Version:  $installedVer"
        Write-Host ""
    }

    # ============================================================================
    # PATH Setup
    # ============================================================================
    if (-not $NoPathSetup) {
        if (-not (Test-InPath $TargetDir)) {
            try {
                # Get current PATH from registry (persistent, not session)
                $scope = if ($Global) { 'Machine' } else { 'User' }
                $currentPath = [System.Environment]::GetEnvironmentVariable('PATH', $scope)
                
                if ($null -eq $currentPath) {
                    $currentPath = ""
                }
                
                # Normalize paths for comparison (remove trailing backslashes)
                $normalizedTargetDir = $TargetDir.TrimEnd('\')
                $pathEntries = $currentPath -split ';' | ForEach-Object { $_.TrimEnd('\') }
                
                # Check if already in PATH (case-insensitive)
                $alreadyInPath = $pathEntries | Where-Object { $_.ToLower() -eq $normalizedTargetDir.ToLower() }
                
                if (-not $alreadyInPath) {
                    # Add to PATH
                    $newPath = if ($currentPath -eq "") { $TargetDir } else { "$currentPath;$TargetDir" }
                    [System.Environment]::SetEnvironmentVariable('PATH', $newPath, $scope)
                    
                    # Also update current session
                    $env:PATH = "$env:PATH;$TargetDir"
                    
                    if (-not $Quiet) {
                        Write-Success "Added $TargetDir to PATH ($scope scope)"
                        Write-Host ""
                        Write-Host "  Note: Restart PowerShell or open a new terminal for changes to take effect in other processes"
                        Write-Host ""
                    }
                } else {
                    if (-not $Quiet) {
                        Write-Info "PATH already contains $TargetDir"
                    }
                }
            } catch {
                Write-Warn "Failed to add to PATH automatically: $_"
                Write-Host ""
                if (-not $NoPathHint) {
                    Write-Host "  Please add manually:" -ForegroundColor Yellow
                    Write-Host "    1. Open: sysdm.cpl"
                    Write-Host "    2. Advanced -> Environment Variables"
                    Write-Host "    3. Add to PATH: $TargetDir"
                    Write-Host ""
                }
            }
        } else {
            if (-not $Quiet) {
                Write-Info "PATH already configured (found in current session)"
            }
        }
    } elseif (-not $NoPathHint) {
        # Show hint if PATH setup was skipped
        if (-not (Test-InPath $TargetDir)) {
            Write-Warn "PATH configuration needed"
            Write-Host ""
            
            if ($Global) {
                Write-Host "  Add to system PATH (requires admin PowerShell):" -ForegroundColor Yellow
                Write-Host "    [System.Environment]::SetEnvironmentVariable('PATH', `$env:PATH + ';$TargetDir', 'Machine')"
            } else {
                Write-Host "  Add to user PATH:" -ForegroundColor Yellow
                Write-Host "    [System.Environment]::SetEnvironmentVariable('PATH', `$env:PATH + ';$TargetDir', 'User')"
            }
            
            Write-Host ""
            Write-Host "  Or manually:" -ForegroundColor Yellow
            Write-Host "    1. Open: sysdm.cpl"
            Write-Host "    2. Advanced -> Environment Variables"
            Write-Host "    3. Add to PATH: $TargetDir"
            Write-Host ""
            Write-Host "  Then restart PowerShell for changes to take effect"
            Write-Host ""
        }
    }

    # ============================================================================
    # Final Hints
    # ============================================================================
    if (-not $Quiet) {
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  🚀 Get started:"
        Write-Host "     PS> meldoc --help"
        Write-Host "     PS> meldoc init"
        Write-Host ""
        Write-Host "  📚 Documentation:"
        Write-Host "     https://public.meldoc.io/meldoc/cli"
        Write-Host ""
        Write-Host "  🗑️  Uninstall:"
        Write-Host "     Remove-Item '$DestPath'"
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    }

} finally {
    # Cleanup
    if (Test-Path $TempDir) {
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
