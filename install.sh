#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Detect OS ──────────────────────────────────────────────────────
detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
      else
        echo "linux"
      fi
      ;;
    *) echo "unknown" ;;
  esac
}

detect_pm() {
  if command -v brew &>/dev/null; then echo "brew"
  elif command -v apt &>/dev/null; then echo "apt"
  elif command -v pacman &>/dev/null; then echo "pacman"
  elif command -v dnf &>/dev/null; then echo "dnf"
  elif command -v zypper &>/dev/null; then echo "zypper"
  elif command -v nix-env &>/dev/null; then echo "nix"
  else echo "unknown"
  fi
}

OS=$(detect_os)
PM=$(detect_pm)
echo "→ Detected OS: $OS, Package Manager: $PM"

# ── Install yazi + dependencies ───────────────────────────────────
install_deps() {
  case "$PM" in
    brew)
      brew install yazi ffmpeg p7zip jq poppler fd ripgrep fzf zoxide imagemagick 2>/dev/null || true
      ;;
    apt)
      sudo apt-get update -qq
      sudo apt-get install -y ffmpeg p7zip jq poppler-utils fd-find ripgrep fzf zoxide imagemagick 2>/dev/null || true
      ;;
    pacman)
      sudo pacman -S --noconfirm --needed yazi ffmpeg p7zip jq poppler fd ripgrep fzf zoxide imagemagick 2>/dev/null || true
      ;;
    dnf)
      sudo dnf install -y ffmpeg p7zip jq poppler-utils fd-find ripgrep fzf zoxide ImageMagick 2>/dev/null || true
      ;;
    zypper)
      sudo zypper install -y ffmpeg p7zip jq poppler-utils fd ripgrep fzf zoxide ImageMagick 2>/dev/null || true
      ;;
  esac
}

# ── Install yazi (cargo fallback for distros without packages) ────
install_yazi() {
  if command -v yazi &>/dev/null; then
    echo "→ yazi already installed"
    return
  fi

  case "$PM" in
    brew|pacman)
      ;; # already handled in install_deps
    *)
      if command -v cargo &>/dev/null; then
        echo "→ Installing yazi via cargo..."
        cargo install --locked yazi-fm yazi-cli 2>/dev/null || true
      else
        echo "→ yazi not available via $PM and cargo not found"
        echo "  Install Rust first: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        echo "  Then run: cargo install --locked yazi-fm yazi-cli"
      fi
      ;;
  esac
}

echo "→ Installing yazi and dependencies..."
install_deps
install_yazi

# ── Create config directory ───────────────────────────────────────
CONFIG_DIR="$HOME/.config/yazi"
mkdir -p "$CONFIG_DIR"

# ── Create symlinks ───────────────────────────────────────────────
for file in config.toml package.toml theme.toml; do
  TARGET="$CONFIG_DIR/$file"
  if [[ -f "$TARGET" && ! -L "$TARGET" ]]; then
    BACKUP="${TARGET}.backup.$(date +%Y%m%d%H%M%S)"
    echo "→ Backing up existing $TARGET to $BACKUP"
    mv "$TARGET" "$BACKUP"
  elif [[ -L "$TARGET" ]]; then
    rm "$TARGET"
  fi
  ln -s "${SCRIPT_DIR}/$file" "$TARGET"
  echo "✔ Linked $file → $TARGET"
done

# Link flavors directory
FLAVORS_TARGET="$CONFIG_DIR/flavors"
if [[ -d "$FLAVORS_TARGET" && ! -L "$FLAVORS_TARGET" ]]; then
  BACKUP="${FLAVORS_TARGET}.backup.$(date +%Y%m%d%H%M%S)"
  echo "→ Backing up existing $FLAVORS_TARGET to $BACKUP"
  mv "$FLAVORS_TARGET" "$BACKUP"
elif [[ -L "$FLAVORS_TARGET" ]]; then
  rm "$FLAVORS_TARGET"
fi
ln -s "${SCRIPT_DIR}/flavors" "$FLAVORS_TARGET"
echo "✔ Linked flavors/ → $FLAVORS_TARGET"
