---
title: Install guide
---
# meldoc CLI

Documentation-as-code CLI tool for the Meldoc.io platform.

## 🚀 Install in 10 seconds

### Native Install (Recommended)

**macOS, Linux, WSL:**

```bash
curl -fsSL https://meldoc.io/install.sh | bash
```

**Windows PowerShell:**

```powershell
irm https://meldoc.io/install.ps1 | iex
```

**Windows CMD:**

```cmd
curl -fsSL https://meldoc.io/install.cmd -o install.cmd && install.cmd && del install.cmd
```

### Start using meldoc:

```bash
cd your-project
meldoc init --token YOUR_TOKEN
```

You'll be guided through the setup process. That's it!

---

## 📖 Installation Options

| Flag | Description |
|------|-------------|
| `--global` | Install to `/usr/local/bin` (may require sudo) |
| `--setup-path` | Automatically add to PATH |
| `--dir <path>` | Install to custom directory |
| `--version <ver>` | Install specific version |
| `--force` | Overwrite existing installation |
| `--quiet` | Minimal output (for CI/CD) |

### Examples

```bash
# Install specific version
curl -fsSL https://meldoc.io/install.sh | bash -s -- --version v1.0.1

# Global installation
curl -fsSL https://meldoc.io/install.sh | bash -s -- --global

# Auto-setup PATH
curl -fsSL https://meldoc.io/install.sh | bash -s -- --setup-path

# Custom directory
curl -fsSL https://meldoc.io/install.sh | bash -s -- --dir ~/bin
```

---

## 🔧 CI/CD Installation

**GitHub Actions:**

```yaml
- name: Install meldoc
  run: curl -fsSL https://meldoc.io/install.sh | bash -s -- --quiet --force

- name: Publish docs
  run: |
    export PATH="$HOME/.local/bin:$PATH"
    meldoc publish --token ${{ secrets.MELDOC_TOKEN }}
```

**GitLab CI:**

```yaml
publish-docs:
  script:
    - curl -fsSL https://meldoc.io/install.sh | bash -s -- --quiet --force
    - export PATH="$HOME/.local/bin:$PATH"
    - meldoc publish --token $MELDOC_TOKEN
```

**Windows CI (PowerShell):**

```powershell
irm https://meldoc.io/install.ps1 | iex -Quiet -Force
meldoc publish --token $env:MELDOC_TOKEN
```

---

## 🚀 Quick Start

After installation, get started in 3 steps:

### 1. Initialize Your Project

```bash
cd /path/to/your/project
meldoc init --token YOUR_TOKEN
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
meldoc publish
```

---

## 🔄 Update

To update to the latest version:

```bash
curl -fsSL https://meldoc.io/install.sh | bash -s -- --force
```

---

## 🗑️ Uninstall

**Quick uninstall:**

```bash
curl -fsSL https://meldoc.io/uninstall.sh | bash
```

**Manual uninstall:**

```bash
# User installation (default)
rm ~/.local/bin/meldoc

# Global installation
sudo rm /usr/local/bin/meldoc

# Windows
del %LOCALAPPDATA%\Programs\meldoc\bin\meldoc.exe
```

---

## 📦 Manual Download

If you prefer manual installation, download from [GitHub Releases](https://github.com/meldoc-io/meldoc-cli/releases):

| Platform | Architecture | File |
|----------|--------------|------|
| macOS | Intel | `meldoc-X.Y.Z-darwin-amd64.tar.gz` |
| macOS | Apple Silicon | `meldoc-X.Y.Z-darwin-arm64.tar.gz` |
| Linux | x86_64 | `meldoc-X.Y.Z-linux-amd64.tar.gz` |
| Linux | ARM64 | `meldoc-X.Y.Z-linux-arm64.tar.gz` |
| Windows | x86_64 | `meldoc-X.Y.Z-windows-amd64.zip` |
| Windows | ARM64 | `meldoc-X.Y.Z-windows-arm64.zip` |

### Manual Installation Steps

```bash
# Download (example for macOS ARM64)
curl -LO https://github.com/meldoc-io/meldoc-cli/releases/latest/download/meldoc-1.0.1-darwin-arm64.tar.gz

# Extract
tar -xzf meldoc-1.0.1-darwin-arm64.tar.gz

# Move to PATH
mv meldoc ~/.local/bin/

# Verify
meldoc --version
```

---

## 🔐 Verify Checksums

After downloading, verify the checksum:

```bash
# Download checksum file
curl -LO https://github.com/meldoc-io/meldoc-cli/releases/latest/download/SHA256SUMS

# Verify (Linux)
sha256sum -c SHA256SUMS --ignore-missing

# Verify (macOS)
shasum -a 256 -c SHA256SUMS --ignore-missing
```

---

## 🛠️ Commands Reference

```bash
# Initialize project
meldoc init --token <token>

# Scan documentation files
meldoc scan

# Publish to server
meldoc publish

# Pull updates from server
meldoc pull

# Track files
meldoc track <pattern>

# Validate configuration
meldoc validate

# Check version
meldoc version

# Get help
meldoc help
meldoc <command> --help
```

### Configuration

**Environment variables (recommended for CI/CD):**

```bash
export MELDOC_SERVER=https://api.meldoc.io
export MELDOC_TOKEN=your-secret-token

meldoc publish
```

---

## 📚 Documentation

- **Full Documentation:** [public.meldoc.io/meldoc/cli](https://public.meldoc.io/meldoc/cli)
- **Source Repository:** [github.com/meldoc-io/meldoc-cli](https://github.com/meldoc-io/meldoc-cli)
- **Report Issues:** [github.com/meldoc-io/meldoc-cli/issues](https://github.com/meldoc-io/meldoc-cli/issues)

---

## 📄 License

This software is proprietary and confidential. See [LICENSE](LICENSE) for full terms.

**Quick Summary:**

- ✅ Use for managing documentation with Meldoc.io platform
- ❌ No copying, modifying, or redistributing
- ❌ No reverse engineering
- ❌ No commercial use outside of Meldoc.io platform

For licensing questions: <legal@meldoc.io>
