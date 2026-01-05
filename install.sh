#!/usr/bin/env bash
#
# Meldoc CLI Installer (macOS/Linux)
# Usage: curl -fsSL https://raw.githubusercontent.com/meldoc-io/meldoc-cli/main/install.sh | bash
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
# Configuration
# ============================================================================
TOOL_NAME="meldoc"
RELEASES_REPO="meldoc-io/meldoc-cli"
BASE_URL="https://raw.githubusercontent.com/${RELEASES_REPO}/main"

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
    # Warnings always shown, even in quiet mode
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    # Errors always shown, even in quiet mode
    echo -e "${RED}✗${NC} $1"
}

log_output() {
    [[ "$QUIET" -eq 1 ]] && return
    echo "$1"
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
  curl -fsSL <url>/install.sh | bash -s -- --quiet --force
  curl -fsSL <url>/install.sh | bash -s -- --global --quiet
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
            NO_PATH_HINT=1  # Quiet mode implies no path hints
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

log_output "Platform: ${OS}/${ARCH}"

# ============================================================================
# Version resolution
# ============================================================================
log_info "Resolving version..."

if [[ "$VERSION" == "latest" ]]; then
    RESOLVED_VERSION=$(curl -fsSL "${BASE_URL}/LATEST" | tr -d '[:space:]' || echo "")
    if [[ -z "$RESOLVED_VERSION" ]]; then
        log_error "Could not determine latest version"
        exit 1
    fi
    # Ensure version has 'v' prefix for URL path
    if [[ "$RESOLVED_VERSION" != v* ]]; then
        VERSION_TAG="v${RESOLVED_VERSION}"
    else
        VERSION_TAG="$RESOLVED_VERSION"
        RESOLVED_VERSION="${RESOLVED_VERSION#v}"
    fi
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

log_output "Version: ${RESOLVED_VERSION}"

# ============================================================================
# Target directory resolution
# ============================================================================
if [[ -n "$TARGET_DIR" ]]; then
    # Expand ~ to $HOME
    TARGET_DIR="${TARGET_DIR/#\~/$HOME}"
elif [[ "$GLOBAL" -eq 1 ]]; then
    # Global install
    if [[ "$OS" == "darwin" && -d "/opt/homebrew/bin" ]]; then
        TARGET_DIR="/opt/homebrew/bin"
    else
        TARGET_DIR="/usr/local/bin"
    fi
else
    # Default: user-space
    TARGET_DIR="${HOME}/.local/bin"
fi

log_output "Target directory: $TARGET_DIR"

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

# Try to create directory without sudo first
mkdir -p "$TARGET_DIR" 2>/dev/null || true

need_sudo=0
if writable_test "$TARGET_DIR"; then
    log_output "Directory is writable (no sudo needed)"
    need_sudo=0
else
    if [[ "$GLOBAL" -eq 1 ]]; then
        log_output "Directory requires elevated permissions"
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
    log_output "Location: $dest"
    log_output ""
    log_output "Use --force to overwrite, or --version to install different version"
    exit 0
fi

# ============================================================================
# Download artifact
# ============================================================================
tmp="$(mktemp -d)"
cleanup() {
    rm -rf "$tmp"
}
trap cleanup EXIT

# Build artifact name: meldoc-{version}-{os}-{arch}.tar.gz
artifact="${TOOL_NAME}-${RESOLVED_VERSION}-${OS}-${ARCH}.tar.gz"
url="${BASE_URL}/${VERSION_TAG}/${artifact}"
checksums_url="${BASE_URL}/${VERSION_TAG}/SHA256SUMS"

log_info "Downloading from: $url"

if ! curl -fsSL "$url" -o "$tmp/$artifact"; then
    log_error "Download failed"
    log_output "Please check:"
    log_output "  - Version exists: $VERSION_TAG"
    log_output "  - URL is accessible: $url"
    exit 1
fi

# Validate download
if [[ ! -s "$tmp/$artifact" ]]; then
    log_error "Downloaded file is empty or doesn't exist"
    exit 1
fi

# ============================================================================
# Verify checksum (optional)
# ============================================================================
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
                log_output "Expected: $expected_sum"
                log_output "Got:      $actual_sum"
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
    # Fallback: search in subdirectories
    bin_path="$(find "$tmp" -maxdepth 3 -type f -name "$TOOL_NAME" 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "$bin_path" || ! -f "$bin_path" ]]; then
    log_error "Binary not found after extraction"
    log_output "Expected: $TOOL_NAME"
    log_output "Extracted contents:"
    [[ "$QUIET" -eq 0 ]] && ls -la "$tmp"
    exit 1
fi

# ============================================================================
# Install binary (atomic)
# ============================================================================
dest_new="${TARGET_DIR}/${TOOL_NAME}.new.$$"

log_info "Installing binary..."

if [[ "$need_sudo" -eq 1 ]]; then
    log_output "Installing to (requires sudo): $dest"
    sudo mkdir -p "$TARGET_DIR"
    sudo cp "$bin_path" "$dest_new"
    sudo chmod 755 "$dest_new"
    sudo mv -f "$dest_new" "$dest"
else
    log_output "Installing to: $dest"
    cp "$bin_path" "$dest_new"
    chmod 755 "$dest_new"
    mv -f "$dest_new" "$dest"
fi

# ============================================================================
# Installation summary
# ============================================================================
installed_ver=$("$dest" version 2>/dev/null || echo "unknown")

if [[ "$QUIET" -eq 1 ]]; then
    # In quiet mode, just output the path for CI/CD parsing
    echo "$dest"
else
    echo ""
    log_success "Installation successful!"
    echo ""
    echo "Location: $dest"
    echo "Version:  $installed_ver"
    echo ""
    echo "Verify installation:"
    echo "  $TOOL_NAME --version"
    echo ""
fi

# ============================================================================
# PATH setup / guidance
# ============================================================================
if ! is_in_path "$TARGET_DIR"; then
    # Detect shell config file
    shell_rc=""
    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
        if [[ -f "$HOME/.bashrc" ]]; then
            shell_rc="$HOME/.bashrc"
        elif [[ -f "$HOME/.bash_profile" ]]; then
            shell_rc="$HOME/.bash_profile"
        fi
    fi
    
    path_export="export PATH=\"${TARGET_DIR}:\$PATH\""
    
    if [[ "$SETUP_PATH" -eq 1 && -n "$shell_rc" ]]; then
        # Auto-setup PATH
        if ! grep -q "${TARGET_DIR}" "$shell_rc" 2>/dev/null; then
            echo "" >> "$shell_rc"
            echo "# Added by meldoc installer" >> "$shell_rc"
            echo "$path_export" >> "$shell_rc"
            log_success "Added ${TARGET_DIR} to PATH in ${shell_rc}"
            echo ""
            echo "To apply changes, run:"
            echo "  source ${shell_rc}"
            echo ""
            echo "Or open a new terminal."
            echo ""
        else
            log_info "PATH already configured in ${shell_rc}"
        fi
    elif [[ "$NO_PATH_HINT" -eq 0 ]]; then
        # Show manual instructions
        log_warning "PATH configuration needed"
        echo ""
        echo "Run this command to configure PATH:"
        if [[ -n "$shell_rc" ]]; then
            echo "  echo '$path_export' >> ${shell_rc} && source ${shell_rc}"
        else
            echo "  $path_export"
        fi
        echo ""
        echo "Or use --setup-path flag to configure automatically:"
        echo "  curl -fsSL <url>/install.sh | bash -s -- --setup-path"
        echo ""
    fi
fi

# ============================================================================
# Uninstall hint (only in non-quiet mode)
# ============================================================================
if [[ "$QUIET" -eq 0 ]]; then
    echo "Uninstall:"
    if [[ "$need_sudo" -eq 1 ]]; then
        echo "  sudo rm $dest"
    else
        echo "  rm $dest"
    fi
    echo ""

    echo "🚀 Get started:"
    echo "  $ meldoc --help"
    echo "  $ meldoc init"
    echo ""
    echo "📚 Documentation: https://public.meldoc.io/meldoc/cli"
    echo ""
fi
