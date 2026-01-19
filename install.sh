#!/usr/bin/env bash
#
# Meldoc CLI Installer (macOS/Linux)
# Usage: curl -fsSL https://meldoc.io/install.sh | bash
#
# Options:
#   --global              Install system-wide (may require sudo)
#   --dir <path>          Install to specific directory
#   --version <version>   Install specific version (default: latest)
#   --force               Overwrite existing installation
#   --no-path-hint        Don't show PATH configuration hints
#   --setup-path          Add install directory to PATH (modifies shell config)
#   --quiet               Minimal output (for CI/CD)
#

set -euo pipefail

# ============================================================================
# Configuration - CHANGE THESE FOR YOUR PROJECT
# ============================================================================
TOOL_NAME="meldoc"
GITHUB_REPO="meldoc-io/meldoc-cli"  # GitHub repository (owner/repo)
GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}"
GITHUB_RELEASES="https://github.com/${GITHUB_REPO}/releases"

# ============================================================================
# Arguments
# ============================================================================
GLOBAL=0
FORCE=0
NO_PATH_HINT=0
SETUP_PATH=0
QUIET=0
VERSION="latest"
TARGET_DIR=""

# ============================================================================
# Colors
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ============================================================================
# Logging functions
# ============================================================================
log_info() {
    [[ "$QUIET" -eq 1 ]] && return
    echo -e "${BLUE}==>${NC} $1"
}

log_success() {
    [[ "$QUIET" -eq 1 ]] && return
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_output() {
    [[ "$QUIET" -eq 1 ]] && return
    echo "$1"
}

# ============================================================================
# Banner
# ============================================================================
show_banner() {
    [[ "$QUIET" -eq 1 ]] && return
    echo -e "${CYAN}"
    cat << 'EOF'
                 _     _            
  _ __ ___   ___| | __| | ___   ___ 
 | '_ ` _ \ / _ \ |/ _` |/ _ \ / __|
 | | | | | |  __/ | (_| | (_) | (__ 
 |_| |_| |_|\___|_|\__,_|\___/ \___|
                                    
EOF
    echo -e "${NC}"
    echo -e "${BOLD}Meldoc CLI Installer${NC}"
    echo ""
}

# ============================================================================
# Usage
# ============================================================================
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --global              Install system-wide (may require sudo)
  --dir <path>          Install to specific directory
  --version <version>   Install specific version (default: latest)
  --force               Overwrite existing installation
  --no-path-hint        Don't show PATH configuration hints
  --setup-path          Add install directory to PATH (modifies shell config)
  --quiet               Minimal output (for CI/CD)
  -h, --help            Show this help message

Examples:
  $0                           # Install to ~/.local/bin
  $0 --global                  # Install to /usr/local/bin (or /opt/homebrew/bin)
  $0 --dir ~/bin               # Install to specific directory
  $0 --version v1.2.3          # Install specific version

CI/CD Usage:
  curl -fsSL https://meldoc.io/install.sh | bash -s -- --quiet --force
  curl -fsSL https://meldoc.io/install.sh | bash -s -- --global --quiet
EOF
}

# ============================================================================
# Argument parsing
# ============================================================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --global)
            GLOBAL=1
            shift
            ;;
        --dir)
            TARGET_DIR="${2:-}"
            if [[ -z "$TARGET_DIR" ]]; then
                log_error "--dir requires a path argument"
                exit 1
            fi
            shift 2
            ;;
        --version)
            VERSION="${2:-latest}"
            shift 2
            ;;
        --force)
            FORCE=1
            shift
            ;;
        --no-path-hint)
            NO_PATH_HINT=1
            shift
            ;;
        --setup-path)
            SETUP_PATH=1
            shift
            ;;
        --quiet|-q)
            QUIET=1
            NO_PATH_HINT=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

# ============================================================================
# Show banner
# ============================================================================
show_banner

# ============================================================================
# Pre-flight checks
# ============================================================================
log_info "Checking dependencies..."

for cmd in curl tar; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "Required command not found: $cmd"
        echo "Please install it using your package manager."
        exit 1
    fi
done

# ============================================================================
# Platform detection
# ============================================================================
log_info "Detecting platform..."

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$OS" in
    darwin)
        OS="darwin"
        ;;
    linux)
        OS="linux"
        ;;
    mingw*|msys*|cygwin*)
        log_error "Windows detected. Please use PowerShell installer:"
        echo ""
        echo "  irm https://meldoc.io/install.ps1 | iex"
        echo ""
        exit 1
        ;;
    *)
        log_error "Unsupported OS: $OS"
        exit 1
        ;;
esac

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64)
        ARCH="amd64"
        ;;
    arm64|aarch64)
        ARCH="arm64"
        ;;
    *)
        log_error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

log_output "  Platform: ${OS}/${ARCH}"

# ============================================================================
# Version resolution (using GitHub API)
# ============================================================================
log_info "Resolving version..."

if [[ "$VERSION" == "latest" ]]; then
    # Get latest release from GitHub API
    RELEASE_INFO=$(curl -fsSL "${GITHUB_API}/releases/latest" 2>/dev/null || echo "")
    
    if [[ -z "$RELEASE_INFO" ]]; then
        log_error "Could not fetch release information from GitHub"
        log_output "  Please check your internet connection"
        exit 1
    fi
    
    # Extract tag_name from JSON (works without jq)
    VERSION_TAG=$(echo "$RELEASE_INFO" | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    
    if [[ -z "$VERSION_TAG" ]]; then
        log_error "Could not determine latest version"
        exit 1
    fi
    
    # Remove 'v' prefix for artifact naming
    RESOLVED_VERSION="${VERSION_TAG#v}"
else
    # User provided version
    if [[ "$VERSION" == v* ]]; then
        VERSION_TAG="$VERSION"
        RESOLVED_VERSION="${VERSION#v}"
    else
        VERSION_TAG="v${VERSION}"
        RESOLVED_VERSION="$VERSION"
    fi
fi

log_output "  Version: ${VERSION_TAG}"

# ============================================================================
# Target directory resolution
# ============================================================================
if [[ -n "$TARGET_DIR" ]]; then
    TARGET_DIR="${TARGET_DIR/#\~/$HOME}"
elif [[ "$GLOBAL" -eq 1 ]]; then
    if [[ "$OS" == "darwin" && -d "/opt/homebrew/bin" ]]; then
        TARGET_DIR="/opt/homebrew/bin"
    else
        TARGET_DIR="/usr/local/bin"
    fi
else
    TARGET_DIR="${HOME}/.local/bin"
fi

log_output "  Install directory: $TARGET_DIR"

# ============================================================================
# Helper functions
# ============================================================================
is_in_path() {
    local dir="$1"
    case ":${PATH}:" in
        *:"${dir}":*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

writable_test() {
    local d="$1"
    local t="${d}/.${TOOL_NAME}-write-test.$$"
    if touch "$t" 2>/dev/null; then
        rm -f "$t" 2>/dev/null
        return 0
    fi
    return 1
}

# ============================================================================
# Directory setup
# ============================================================================
log_info "Preparing installation directory..."

mkdir -p "$TARGET_DIR" 2>/dev/null || true

need_sudo=0
if writable_test "$TARGET_DIR"; then
    log_output "  Directory is writable"
    need_sudo=0
else
    if [[ "$GLOBAL" -eq 1 ]]; then
        log_output "  Directory requires elevated permissions"
        need_sudo=1
    else
        log_error "Target directory is not writable: $TARGET_DIR"
        echo ""
        echo "Options:"
        echo "  - Choose a directory under \$HOME using --dir"
        echo "  - Use --global for system-wide installation"
        exit 1
    fi
fi

# ============================================================================
# Check existing installation
# ============================================================================
dest="${TARGET_DIR}/${TOOL_NAME}"

if [[ -f "$dest" && "$FORCE" -eq 0 ]]; then
    existing_ver=$("$dest" version 2>/dev/null | head -n1 || echo "unknown version")
    log_output ""
    log_warning "Already installed: $existing_ver"
    log_output "  Location: $dest"
    log_output ""
    log_output "  Use --force to overwrite, or --version to install a different version"
    exit 0
fi

# ============================================================================
# Download artifact from GitHub Releases
# ============================================================================
tmp="$(mktemp -d)"
cleanup() {
    rm -rf "$tmp"
}
trap cleanup EXIT

# Build artifact name: meldoc-{version}-{os}-{arch}.tar.gz
artifact="${TOOL_NAME}-${RESOLVED_VERSION}-${OS}-${ARCH}.tar.gz"

# GitHub Releases download URL
url="${GITHUB_RELEASES}/download/${VERSION_TAG}/${artifact}"

log_info "Downloading ${TOOL_NAME} ${VERSION_TAG}..."
log_output "  From: ${url}"

if ! curl -fsSL "$url" -o "$tmp/$artifact"; then
    log_error "Download failed"
    echo ""
    echo "Please check:"
    echo "  - Version exists: ${VERSION_TAG}"
    echo "  - Artifact exists: ${artifact}"
    echo "  - Releases page: ${GITHUB_RELEASES}"
    exit 1
fi

# Validate download
if [[ ! -s "$tmp/$artifact" ]]; then
    log_error "Downloaded file is empty or doesn't exist"
    exit 1
fi

log_success "Downloaded successfully"

# ============================================================================
# Verify checksum (optional)
# ============================================================================
checksums_url="${GITHUB_RELEASES}/download/${VERSION_TAG}/SHA256SUMS"

if curl -fsSL "$checksums_url" -o "$tmp/SHA256SUMS" 2>/dev/null; then
    log_info "Verifying checksum..."
    
    expected_sum=$(grep "$artifact" "$tmp/SHA256SUMS" | awk '{print $1}' || echo "")
    
    if [[ -n "$expected_sum" ]]; then
        if command -v sha256sum >/dev/null 2>&1; then
            actual_sum=$(sha256sum "$tmp/$artifact" | awk '{print $1}')
        elif command -v shasum >/dev/null 2>&1; then
            actual_sum=$(shasum -a 256 "$tmp/$artifact" | awk '{print $1}')
        else
            log_warning "sha256sum/shasum not found, skipping verification"
            actual_sum=""
        fi
        
        if [[ -n "$actual_sum" ]]; then
            if [[ "$expected_sum" == "$actual_sum" ]]; then
                log_success "Checksum verified"
            else
                log_error "Checksum verification failed!"
                echo "Expected: $expected_sum"
                echo "Got:      $actual_sum"
                exit 1
            fi
        fi
    else
        log_warning "Checksum not found for $artifact"
    fi
else
    log_warning "Could not download SHA256SUMS, skipping verification"
fi

# ============================================================================
# Extract artifact
# ============================================================================
log_info "Extracting archive..."

if ! tar -xzf "$tmp/$artifact" -C "$tmp"; then
    log_error "Failed to extract archive"
    exit 1
fi

# Locate binary
bin_path="$tmp/$TOOL_NAME"
if [[ ! -f "$bin_path" ]]; then
    bin_path="$(find "$tmp" -maxdepth 3 -type f -name "$TOOL_NAME" 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "$bin_path" || ! -f "$bin_path" ]]; then
    log_error "Binary not found after extraction"
    log_output "Expected: $TOOL_NAME"
    [[ "$QUIET" -eq 0 ]] && ls -la "$tmp"
    exit 1
fi

# ============================================================================
# Install binary (atomic)
# ============================================================================
dest_new="${TARGET_DIR}/${TOOL_NAME}.new.$$"

log_info "Installing binary..."

if [[ "$need_sudo" -eq 1 ]]; then
    log_output "  Installing to (requires sudo): $dest"
    sudo mkdir -p "$TARGET_DIR"
    sudo cp "$bin_path" "$dest_new"
    sudo chmod 755 "$dest_new"
    sudo mv -f "$dest_new" "$dest"
else
    log_output "  Installing to: $dest"
    cp "$bin_path" "$dest_new"
    chmod 755 "$dest_new"
    mv -f "$dest_new" "$dest"
fi

# ============================================================================
# Installation summary
# ============================================================================
installed_ver=$("$dest" version 2>/dev/null || echo "unknown")

if [[ "$QUIET" -eq 1 ]]; then
    echo "$dest"
else
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  ✓ Installation successful!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  Location: $dest"
    echo "  Version:  $installed_ver"
    echo ""
fi

# ============================================================================
# PATH setup / guidance
# ============================================================================
if ! is_in_path "$TARGET_DIR"; then
    shell_rc=""
    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
        if [[ -f "$HOME/.bashrc" ]]; then
            shell_rc="$HOME/.bashrc"
        elif [[ -f "$HOME/.bash_profile" ]]; then
            shell_rc="$HOME/.bash_profile"
        fi
    elif [[ "$SHELL" == *"fish"* ]]; then
        shell_rc="$HOME/.config/fish/config.fish"
    fi
    
    path_export="export PATH=\"${TARGET_DIR}:\$PATH\""
    fish_path_export="fish_add_path ${TARGET_DIR}"
    
    if [[ "$SETUP_PATH" -eq 1 && -n "$shell_rc" ]]; then
        if ! grep -q "${TARGET_DIR}" "$shell_rc" 2>/dev/null; then
            echo "" >> "$shell_rc"
            echo "# Added by meldoc installer" >> "$shell_rc"
            if [[ "$SHELL" == *"fish"* ]]; then
                echo "$fish_path_export" >> "$shell_rc"
            else
                echo "$path_export" >> "$shell_rc"
            fi
            log_success "Added ${TARGET_DIR} to PATH in ${shell_rc}"
            echo ""
            echo "  To apply changes, run:"
            echo "    source ${shell_rc}"
            echo ""
            echo "  Or open a new terminal."
            echo ""
        else
            log_info "PATH already configured in ${shell_rc}"
            echo ""
            echo "  If meldoc is not found, run:"
            echo "    source ${shell_rc}"
            echo ""
        fi
    elif [[ "$NO_PATH_HINT" -eq 0 ]]; then
        log_warning "PATH configuration needed"
        echo ""
        echo "  Run this command to configure PATH:"
        if [[ -n "$shell_rc" ]]; then
            if [[ "$SHELL" == *"fish"* ]]; then
                echo "    echo '$fish_path_export' >> ${shell_rc}"
            else
                echo "    echo '$path_export' >> ${shell_rc} && source ${shell_rc}"
            fi
        else
            echo "    $path_export"
        fi
        echo ""
        echo "  Or use --setup-path flag to configure automatically:"
        echo "    curl -fsSL https://meldoc.io/install.sh | bash -s -- --setup-path"
        echo ""
    fi
fi

# ============================================================================
# Final hints
# ============================================================================
if [[ "$QUIET" -eq 0 ]]; then
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  🚀 Get started:"
    echo "     $ meldoc --help"
    echo "     $ meldoc init"
    echo ""
    echo "  📚 Documentation:"
    echo "     https://public.meldoc.io/meldoc/cli"
    echo ""
    echo "  🗑️  Uninstall:"
    if [[ "$need_sudo" -eq 1 ]]; then
        echo "     sudo rm $dest"
    else
        echo "     rm $dest"
    fi
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
fi
