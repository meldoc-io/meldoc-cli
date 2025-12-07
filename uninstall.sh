#!/usr/bin/env bash
#
# meldoc uninstaller for Linux and macOS
# Usage: curl -fsSL https://raw.githubusercontent.com/meldoc-io/meldoc-cli/main/uninstall.sh | bash
#

set -e

# Configuration
BINARY_NAME="meldoc"
COMMON_INSTALL_DIRS=(
    "/usr/local/bin"
    "/usr/bin"
    "$HOME/.local/bin"
    "$HOME/bin"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

# Find installed meldoc
find_installation() {
    # Try which command first
    if command -v "$BINARY_NAME" >/dev/null 2>&1; then
        INSTALL_PATH=$(which "$BINARY_NAME")
        INSTALLED_VERSION=$("$BINARY_NAME" version 2>&1 || echo "unknown")
        return 0
    fi
    
    # Search in common directories
    for dir in "${COMMON_INSTALL_DIRS[@]}"; do
        if [ -f "$dir/$BINARY_NAME" ]; then
            INSTALL_PATH="$dir/$BINARY_NAME"
            INSTALLED_VERSION=$("$INSTALL_PATH" version 2>&1 || echo "unknown")
            return 0
        fi
    done
    
    return 1
}

# Remove meldoc binary
remove_binary() {
    log_info "Removing ${INSTALL_PATH}..."
    
    if rm "$INSTALL_PATH" 2>/dev/null; then
        log_success "Binary removed successfully"
        return 0
    else
        # Try with sudo if direct removal fails
        if command -v sudo >/dev/null 2>&1; then
            log_info "Requesting sudo privileges..."
            if sudo rm "$INSTALL_PATH"; then
                log_success "Binary removed successfully"
                return 0
            else
                log_error "Failed to remove binary"
                return 1
            fi
        else
            log_error "Failed to remove binary. Try running with sudo."
            return 1
        fi
    fi
}

# Find all .meldoc directories
find_meldoc_dirs() {
    log_info "Searching for .meldoc directories in your home folder..."
    echo ""
    
    # Find all .meldoc directories (limit depth to avoid searching too deep)
    MELDOC_DIRS=$(find "$HOME" -maxdepth 5 -type d -name ".meldoc" 2>/dev/null || true)
    
    if [ -z "$MELDOC_DIRS" ]; then
        log_info "No .meldoc directories found"
        return 1
    fi
    
    echo "$MELDOC_DIRS" | while read -r dir; do
        echo "  📂 $dir"
    done
    echo ""
    
    return 0
}

# Remove .meldoc directories
remove_meldoc_dirs() {
    echo "$MELDOC_DIRS" | while read -r dir; do
        if [ -d "$dir" ]; then
            rm -rf "$dir"
            log_success "Removed: $dir"
        fi
    done
}

# Prompt for confirmation
prompt_confirmation() {
    local message="$1"
    local response
    
    echo -e "${YELLOW}⚠${NC} $message"
    
    # Read from /dev/tty to work when piped from curl
    if [ -t 0 ]; then
        read -p "Continue? (yes/no): " -r response
    else
        read -p "Continue? (yes/no): " -r response </dev/tty
    fi
    echo ""
    
    if [[ $response =~ ^[Yy][Ee][Ss]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Main uninstallation flow
main() {
    echo ""
    echo "╔═══════════════════════════════════════╗"
    echo "║     meldoc CLI Uninstaller            ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""
    
    # Step 1: Find installation
    if ! find_installation; then
        log_error "meldoc is not installed or not found in PATH"
        echo ""
        echo "Searched in:"
        for dir in "${COMMON_INSTALL_DIRS[@]}"; do
            echo "  - $dir"
        done
        echo ""
        exit 1
    fi
    
    log_success "Found meldoc installation"
    echo ""
    echo "  Location: ${CYAN}${INSTALL_PATH}${NC}"
    echo "  Version:  ${CYAN}${INSTALLED_VERSION}${NC}"
    echo ""
    
    # Step 2: Confirm removal
    if ! prompt_confirmation "Remove meldoc binary?"; then
        log_warning "Uninstallation cancelled"
        exit 0
    fi
    
    # Step 3: Remove binary
    if ! remove_binary; then
        exit 1
    fi
    
    echo ""
    
    # Step 4: Ask about .meldoc directories
    if find_meldoc_dirs; then
        if prompt_confirmation "Remove all .meldoc project directories? (This will delete project configuration and state)"; then
            remove_meldoc_dirs
            echo ""
            log_success "All .meldoc directories removed"
        else
            log_info "Keeping .meldoc directories"
        fi
    fi
    
    echo ""
    echo "╔═══════════════════════════════════════╗"
    echo "║     ✓ Uninstallation Complete         ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""
    
    # Verify removal
    if command -v "$BINARY_NAME" >/dev/null 2>&1; then
        log_warning "meldoc is still in PATH (may be cached)"
        echo ""
        echo "Try running: hash -r"
        echo "Or restart your terminal"
    else
        log_success "meldoc has been completely removed"
    fi
    
    echo ""
    echo "Thank you for using meldoc! 👋"
    echo ""
}

main "$@"
