---
title: Install guide
---
# meldoc CLI

Binary releases for meldoc CLI.

## 🚀 Quick Install

**Linux / macOS:**

```bash
curl -fsSL https://raw.githubusercontent.com/meldoc-io/meldoc-cli/main/install.sh | bash
```

**With automatic PATH setup:**

```bash
curl -fsSL https://raw.githubusercontent.com/meldoc-io/meldoc-cli/main/install.sh | bash -s -- --setup-path
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/meldoc-io/meldoc-cli/main/install.ps1 | iex
```

### Installation Options

| Flag | Description |
|------|-------------|
| `--global` | Install to `/usr/local/bin` (may require sudo) |
| `--setup-path` | Automatically add to PATH |
| `--dir <path>` | Install to custom directory |
| `--version <ver>` | Install specific version |
| `--force` | Overwrite existing installation |
| `--quiet` | Minimal output (for CI/CD) |

### CI/CD Installation

```bash
curl -fsSL .../install.sh | bash -s -- --quiet --force
export PATH="$HOME/.local/bin:$PATH"
```

## 🚀 Quick Start

After installation, get started in 3 steps:

### 1. Initialize Your Project

```bash
cd /path/to/your/project
meldoc init --project my-project
```

This creates `.meldoc/` directory with configuration and state files.

### 2. Create Documentation

Create files with `.meldoc.md` extension:

```bash
cat > docs/getting-started.meldoc.md << 'EOF'
---
title: Getting Started
author: Your Name
version: "1.0"
---

# Getting Started

Welcome to our documentation!
EOF
```

### 3. Scan and Publish

```bash
# Scan for documentation files
meldoc scan

# Publish to server
meldoc publish --token YOUR_TOKEN
```

**For detailed guide, see:** [QUICK_START.md](https://github.com/meldoc-io/meldoc-cli/blob/main/QUICK_START.md)

## 🔄 Update

To update to the latest version:

```bash
curl -fsSL https://raw.githubusercontent.com/meldoc-io/meldoc-cli/main/install.sh | bash -s -- --force
```

## 🗑️ Uninstall

**Quick uninstall:**

```bash
curl -fsSL https://raw.githubusercontent.com/meldoc-io/meldoc-cli/main/uninstall.sh | bash
```

**Manual uninstall:**

```bash
# User installation (default)
rm ~/.local/bin/meldoc

# Global installation
sudo rm /usr/local/bin/meldoc
```

## 📦 Available Versions

- **Latest:** See [LATEST](LATEST)
- **All versions:** See [index.json](index.json)

## 📥 Manual Download

You can also download specific versions manually from the version directories:

```
v1.0.0/
  ├── meldoc-1.0.0-linux-amd64.tar.gz
  ├── meldoc-1.0.0-linux-arm64.tar.gz
  ├── meldoc-1.0.0-darwin-amd64.tar.gz
  ├── meldoc-1.0.0-darwin-arm64.tar.gz
  ├── meldoc-1.0.0-windows-amd64.zip
  ├── meldoc-1.0.0-windows-arm64.zip
  └── SHA256SUMS
```

## 🔐 Verify Checksums

After downloading, verify the checksum:

```bash
# Download the checksum file
curl -fsSL https://raw.githubusercontent.com/meldoc-io/meldoc-cli/main/v1.0.0/SHA256SUMS > SHA256SUMS

# Verify (Linux/macOS)
sha256sum -c SHA256SUMS --ignore-missing
# or
shasum -a 256 -c SHA256SUMS --ignore-missing
```

## 📚 Documentation

- [Source Repository](https://github.com/meldoc-io/meldoc-cli)
- [Report Issues](https://github.com/meldoc-io/meldoc-cli/issues)

## 📄 License

This software is proprietary and confidential. See [LICENSE](LICENSE) for full terms.

**Quick Summary:**

- ✅ Use for managing documentation with Meldoc.io platform
- ❌ No copying, modifying, or redistributing
- ❌ No reverse engineering
- ❌ No commercial use outside of Meldoc.io platform

For licensing questions: <legal@meldoc.io>

## 🛠️ Commands

```bash
# Initialize project
meldoc init --project <id>

# Scan documentation files
meldoc scan

# Publish to server
meldoc publish --token <token>

# Pull updates from server
meldoc pull --token <token>

# Check version
meldoc version

# Get help
meldoc --help
```

### Configuration Options

**Option 1: Command-line flags**

```bash
meldoc init --project my-docs 
meldoc publish --project my-docs --token abc123
```

**Option 2: Environment variables (recommended for CI/CD)**

```bash
export MELDOC_PROJECT=my-docs
export MELDOC_SERVER=http://localhost:8089
export MELDOC_TOKEN=your-secret-token

meldoc init
meldoc publish
```

**Option 3: Project config** (after `meldoc init`, stored in `.meldoc/config.yml`)

```bash
# Only token needed for publish/pull
meldoc publish --token YOUR_TOKEN
```
