#!/usr/bin/env bash
#
# meldoc installer for Linux and macOS
# Usage: curl -fsSL https://raw.githubusercontent.com/meldoc-io/meldoc-cli/main/install.sh | bash
#

set -e

# Configuration
RELEASES_REPO="meldoc-io/meldoc-cli"
BINARY_NAME="meldoc"
INSTALL_DIR="${MELDOC_INSTALL_DIR:-/usr/local/bin}"
BASE_URL="https://raw.githubusercontent.com/${RELEASES_REPO}/main"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Detect OS and architecture
detect_platform() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    case "$OS" in
        linux*)
            OS="linux"
            ;;
        darwin*)
            OS="darwin"
            ;;
        *)
            log_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
    
    case "$ARCH" in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    log_info "Detected platform: ${OS}/${ARCH}"
}

# Check if meldoc is already installed
check_existing_installation() {
    if command -v "$BINARY_NAME" >/dev/null 2>&1; then
        CURRENT_VERSION=$("$BINARY_NAME" version 2>&1 | awk '{print $2}' || echo "")
        if [ -n "$CURRENT_VERSION" ]; then
            CURRENT_INSTALL_PATH=$(which "$BINARY_NAME")
            return 0
        fi
    fi
    return 1
}

# Compare versions (returns 0 if v1 < v2, 1 if v1 >= v2)
version_less_than() {
    local v1="$1"
    local v2="$2"
    
    # Remove 'v' prefix if present
    v1="${v1#v}"
    v2="${v2#v}"
    
    # Simple version comparison
    if [ "$v1" = "$v2" ]; then
        return 1
    fi
    
    # Use sort -V for version comparison
    if printf '%s\n%s\n' "$v1" "$v2" | sort -V -C; then
        return 0
    else
        return 1
    fi
}

# Get latest version from LATEST file
get_latest_version() {
    log_info "Fetching latest version..."
    
    if command -v curl >/dev/null 2>&1; then
        VERSION=$(curl -fsSL "${BASE_URL}/LATEST" | tr -d '[:space:]' || echo "")
    else
        log_error "curl is required but not installed"
        exit 1
    fi
    
    if [ -z "$VERSION" ]; then
        log_error "Could not determine latest version"
        exit 1
    fi
    
    log_info "Latest version: ${VERSION}"
}

# Verify checksum
verify_checksum() {
    local file="$1"
    local checksums_file="$2"
    
    if [ ! -f "$checksums_file" ]; then
        log_warning "SHA256SUMS file not found, skipping verification"
        return 0
    fi
    
    log_info "Verifying checksum..."
    
    local filename=$(basename "$file")
    local expected_sum=$(grep "$filename" "$checksums_file" | awk '{print $1}')
    
    if [ -z "$expected_sum" ]; then
        log_warning "Checksum not found for $filename"
        return 0
    fi
    
    if command -v sha256sum >/dev/null 2>&1; then
        local actual_sum=$(sha256sum "$file" | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        local actual_sum=$(shasum -a 256 "$file" | awk '{print $1}')
    else
        log_warning "sha256sum/shasum not found, skipping verification"
        return 0
    fi
    
    if [ "$expected_sum" = "$actual_sum" ]; then
        log_success "Checksum verified"
        return 0
    else
        log_error "Checksum verification failed!"
        log_error "Expected: $expected_sum"
        log_error "Got:      $actual_sum"
        return 1
    fi
}

# Download and install binary
install_binary() {
    # Extract version number (v1.0.0 -> 1.0.0)
    VERSION_NUMBER="${VERSION#v}"
    ARCHIVE_NAME="${BINARY_NAME}-${VERSION_NUMBER}-${OS}-${ARCH}.tar.gz"
    DOWNLOAD_URL="${BASE_URL}/v${VERSION}/${ARCHIVE_NAME}"
    CHECKSUMS_URL="${BASE_URL}/v${VERSION}/SHA256SUMS"
    TEMP_DIR=$(mktemp -d)
    
    log_info "Downloading ${ARCHIVE_NAME}..."
    
    if ! curl -fsSL "$DOWNLOAD_URL" -o "${TEMP_DIR}/${ARCHIVE_NAME}"; then
        log_error "Failed to download binary from ${DOWNLOAD_URL}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Download checksums
    if curl -fsSL "$CHECKSUMS_URL" -o "${TEMP_DIR}/SHA256SUMS" 2>/dev/null; then
        if ! verify_checksum "${TEMP_DIR}/${ARCHIVE_NAME}" "${TEMP_DIR}/SHA256SUMS"; then
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    else
        log_warning "Could not download SHA256SUMS, skipping verification"
    fi
    
    log_info "Extracting archive..."
    tar -xzf "${TEMP_DIR}/${ARCHIVE_NAME}" -C "$TEMP_DIR"
    
    # Find the binary (it should be the only non-archive file)
    BINARY_PATH=$(find "$TEMP_DIR" -type f -name "${BINARY_NAME}*" ! -name "*.tar.gz" ! -name "SHA256SUMS" | head -n 1)
    
    if [ -z "$BINARY_PATH" ] || [ ! -f "$BINARY_PATH" ]; then
        log_error "Binary not found in archive"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Create install directory if it doesn't exist
    if [ ! -d "$INSTALL_DIR" ]; then
        log_info "Creating install directory: $INSTALL_DIR"
        if ! mkdir -p "$INSTALL_DIR" 2>/dev/null; then
            log_error "Failed to create install directory. Try running with sudo."
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    fi
    
    # Install binary
    log_info "Installing to ${INSTALL_DIR}/${BINARY_NAME}..."
    
    if ! cp "$BINARY_PATH" "${INSTALL_DIR}/${BINARY_NAME}" 2>/dev/null; then
        # Try with sudo if direct copy fails
        if command -v sudo >/dev/null 2>&1; then
            log_info "Requesting sudo privileges..."
            if ! sudo cp "$BINARY_PATH" "${INSTALL_DIR}/${BINARY_NAME}"; then
                log_error "Failed to install binary"
                rm -rf "$TEMP_DIR"
                exit 1
            fi
            sudo chmod +x "${INSTALL_DIR}/${BINARY_NAME}"
        else
            log_error "Failed to install binary. Try running with sudo."
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    else
        chmod +x "${INSTALL_DIR}/${BINARY_NAME}"
    fi
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    
    log_success "meldoc installed successfully!"
}

# Verify installation
verify_installation() {
    local is_upgrade="$1"
    
    if command -v "$BINARY_NAME" >/dev/null 2>&1; then
        INSTALLED_VERSION=$("$BINARY_NAME" version 2>&1 || echo "unknown")
        
        if [ "$is_upgrade" = "true" ]; then
            log_success "Upgrade successful!"
            echo ""
            echo "  Previous version: ${CURRENT_VERSION}"
            echo "  Current version:  $INSTALLED_VERSION"
        else
            log_success "Installation verified"
            echo ""
            echo "  $BINARY_NAME version: $INSTALLED_VERSION"
        fi
        
        echo ""
        echo "🚀 Get started:"
        echo "  $ meldoc --help"
        echo "  $ meldoc init"
        echo ""
    else
        log_warning "Installation complete, but '${BINARY_NAME}' not found in PATH"
        echo ""
        echo "Add ${INSTALL_DIR} to your PATH:"
        echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
        echo ""
    fi
}

# Main installation flow
main() {
    local is_upgrade="false"
    
    echo ""
    echo "╔═══════════════════════════════════════╗"
    echo "║     meldoc CLI Installer              ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""
    
    detect_platform
    get_latest_version
    
    # Check if already installed
    if check_existing_installation; then
        log_info "meldoc is already installed"
        echo ""
        echo "  Location: ${CURRENT_INSTALL_PATH}"
        echo "  Current version: ${CURRENT_VERSION}"
        echo "  Latest version:  ${VERSION#v}"
        echo ""
        
        # Compare versions
        if version_less_than "$CURRENT_VERSION" "${VERSION#v}"; then
            log_info "A newer version is available!"
            echo ""
            
            # Read from /dev/tty to work when piped from curl
            if [ -t 0 ]; then
                read -p "$(echo -e ${YELLOW}⚠${NC}) Upgrade to ${VERSION}? (yes/no): " -r
            else
                read -p "$(echo -e ${YELLOW}⚠${NC}) Upgrade to ${VERSION}? (yes/no): " -r </dev/tty
            fi
            echo ""
            
            if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
                log_info "Keeping current version"
                echo ""
                echo "To upgrade later, run this script again or:"
                echo "  curl -fsSL https://raw.githubusercontent.com/${RELEASES_REPO}/main/install.sh | bash"
                echo ""
                exit 0
            fi
            
            is_upgrade="true"
            log_info "Upgrading meldoc..."
            echo ""
        else
            log_success "You have the latest version installed"
            echo ""
            
            # Read from /dev/tty to work when piped from curl
            if [ -t 0 ]; then
                read -p "$(echo -e ${YELLOW}⚠${NC}) Reinstall ${VERSION}? (yes/no): " -r
            else
                read -p "$(echo -e ${YELLOW}⚠${NC}) Reinstall ${VERSION}? (yes/no): " -r </dev/tty
            fi
            echo ""
            
            if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
                log_info "Installation cancelled"
                exit 0
            fi
            
            log_info "Reinstalling meldoc..."
            echo ""
        fi
    fi
    
    install_binary
    verify_installation "$is_upgrade"
    
    echo "📚 Documentation: https://github.com/${RELEASES_REPO}"
    echo ""
    
    if [ "$is_upgrade" = "true" ]; then
        echo "🔗 Release notes: https://github.com/${RELEASES_REPO}/releases/tag/${VERSION}"
        echo ""
    fi
}

main "$@"
