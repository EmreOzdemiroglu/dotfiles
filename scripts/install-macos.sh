#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
REQ_FILE="${DOTFILES_DIR}/requirements/macos-brew.txt"
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/.dotfiles-backup}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_DIR:-$BACKUP_ROOT/$TIMESTAMP}"
NVIM_VERSION="${NVIM_VERSION:-0.11.6}"
INSTALL_ZSH_STACK="${INSTALL_ZSH_STACK:-1}"
SET_DEFAULT_SHELL="${SET_DEFAULT_SHELL:-1}"

backup_initialized=0
BREW_BIN=""

log() {
  printf '[install-macos] %s\n' "$*"
}

warn() {
  printf '[install-macos][warn] %s\n' "$*" >&2
}

die() {
  printf '[install-macos][error] %s\n' "$*" >&2
  exit 1
}

version_lt() {
  local a b i ai bi
  IFS='.' read -r -a a <<<"$1"
  IFS='.' read -r -a b <<<"$2"
  for i in 0 1 2; do
    ai="${a[$i]:-0}"
    bi="${b[$i]:-0}"
    if (( ai < bi )); then
      return 0
    fi
    if (( ai > bi )); then
      return 1
    fi
  done
  return 1
}

ensure_macos() {
  [[ "$(uname -s)" == "Darwin" ]] || die "This installer supports macOS only."
}

ensure_backup_dir() {
  if [[ "$backup_initialized" -eq 0 ]]; then
    mkdir -p "$BACKUP_DIR"
    backup_initialized=1
    log "Backup directory: $BACKUP_DIR"
  fi
}

backup_path() {
  local target="$1"
  local relative="${target#$HOME/}"
  printf '%s/%s' "$BACKUP_DIR" "$relative"
}

backup_if_needed() {
  local target="$1"
  if [[ -e "$target" ]] || [[ -L "$target" ]]; then
    ensure_backup_dir
    local out
    out="$(backup_path "$target")"
    mkdir -p "$(dirname "$out")"
    mv "$target" "$out"
    log "Backed up: $target -> $out"
  fi
}

link_with_backup() {
  local source="$1"
  local target="$2"
  mkdir -p "$(dirname "$target")"

  if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$source" ]]; then
    log "Already linked: $target"
    return 0
  fi

  backup_if_needed "$target"
  ln -s "$source" "$target"
  log "Linked: $target -> $source"
}

ensure_homebrew() {
  local candidate
  for candidate in "$(command -v brew || true)" /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -n "$candidate" ]] && [[ -x "$candidate" ]]; then
      BREW_BIN="$candidate"
      break
    fi
  done

  if [[ -z "$BREW_BIN" ]]; then
    log "Installing Homebrew"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      if [[ -x "$candidate" ]]; then
        BREW_BIN="$candidate"
        break
      fi
    done
  fi

  [[ -n "$BREW_BIN" ]] || die "Homebrew installation failed."
  eval "$("$BREW_BIN" shellenv)"
}

brew_do() {
  "$BREW_BIN" "$@"
}

install_brew_packages() {
  [[ -f "$REQ_FILE" ]] || die "Requirements file not found: $REQ_FILE"

  local packages=()
  local line
  while IFS= read -r line; do
    packages+=("$line")
  done < <(grep -Ev '^\s*(#|$)' "$REQ_FILE")
  brew_do update

  if [[ "${#packages[@]}" -eq 0 ]]; then
    return 0
  fi

  local pkg
  for pkg in "${packages[@]}"; do
    if brew_do list --versions "$pkg" >/dev/null 2>&1; then
      log "brew package already installed: $pkg"
    else
      brew_do install "$pkg"
    fi
  done
}

resolve_nvim_arch() {
  case "$(uname -m)" in
    arm64|aarch64) printf '%s' 'macos-arm64' ;;
    x86_64|amd64) printf '%s' 'macos-x86_64' ;;
    *) die "Unsupported architecture for Neovim tarball: $(uname -m)" ;;
  esac
}

install_nvim_pinned() {
  local current_version=""
  local requested="${NVIM_VERSION#v}"
  local arch
  local url
  local tmpdir
  local archive
  local install_dir="$HOME/.local/opt/nvim-v${requested}"

  export PATH="$HOME/.local/bin:$PATH"

  if command -v nvim >/dev/null 2>&1; then
    current_version="$(nvim --version | head -n1 | awk '{print $2}' | sed 's/^v//')"
    if [[ "$current_version" == "$requested" ]]; then
      log "Neovim v${requested} already installed."
      return 0
    fi
  fi

  arch="$(resolve_nvim_arch)"
  url="https://github.com/neovim/neovim/releases/download/v${requested}/nvim-${arch}.tar.gz"
  tmpdir="$(mktemp -d)"
  archive="${tmpdir}/nvim.tar.gz"

  log "Installing Neovim v${requested} (${arch})"
  curl -fsSL "$url" -o "$archive"

  mkdir -p "$HOME/.local/opt" "$HOME/.local/bin"
  rm -rf "$install_dir"
  mkdir -p "$install_dir"
  tar -xzf "$archive" --strip-components=1 -C "$install_dir"
  ln -sf "$install_dir/bin/nvim" "$HOME/.local/bin/nvim"

  current_version="$("$HOME/.local/bin/nvim" --version | head -n1 | awk '{print $2}' | sed 's/^v//')"
  rm -rf "$tmpdir"
  if [[ "$current_version" != "$requested" ]]; then
    die "Neovim version mismatch after install (expected $requested, got $current_version)"
  fi

  log "Neovim v${requested} installed."
}

install_tpm() {
  local tpm_dir="$HOME/.tmux/plugins/tpm"
  mkdir -p "$HOME/.tmux/plugins"
  if [[ -d "$tpm_dir/.git" ]]; then
    git -C "$tpm_dir" pull --ff-only || warn "TPM update failed; continuing."
  else
    git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
  fi
}

install_oh_my_zsh() {
  local omz_dir="$HOME/.oh-my-zsh"
  if [[ -d "$omz_dir/.git" ]]; then
    git -C "$omz_dir" pull --ff-only || warn "Oh My Zsh update failed; continuing."
  else
    git clone https://github.com/ohmyzsh/ohmyzsh "$omz_dir"
  fi
}

install_zsh_plugins() {
  local plugin_base="$HOME/.oh-my-zsh/custom/plugins"
  mkdir -p "$plugin_base"

  if [[ -d "$plugin_base/zsh-autosuggestions/.git" ]]; then
    git -C "$plugin_base/zsh-autosuggestions" pull --ff-only || warn "zsh-autosuggestions update failed; continuing."
  else
    git clone https://github.com/zsh-users/zsh-autosuggestions "$plugin_base/zsh-autosuggestions"
  fi

  if [[ -d "$plugin_base/zsh-syntax-highlighting/.git" ]]; then
    git -C "$plugin_base/zsh-syntax-highlighting" pull --ff-only || warn "zsh-syntax-highlighting update failed; continuing."
  else
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$plugin_base/zsh-syntax-highlighting"
  fi
}

ensure_macos_shellenv() {
  local zprofile="$HOME/.zprofile"
  local marker="dotfiles macos shellenv"

  touch "$zprofile"
  if grep -q "$marker" "$zprofile"; then
    log "macOS shell env already present in $zprofile"
    return 0
  fi

  cat >>"$zprofile" <<'EOF'
# >>> dotfiles macos shellenv >>>
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
export PATH="$HOME/.local/bin:$PATH"
# <<< dotfiles macos shellenv <<<
EOF

  log "Added macOS shell env block to $zprofile"
}

set_default_shell_to_zsh() {
  local target_user
  local zsh_path
  local current_shell

  target_user="${USER:-$(id -un)}"
  zsh_path="$(command -v zsh || true)"
  if [[ -z "$zsh_path" ]]; then
    warn "zsh not found; skipping default shell switch."
    return 0
  fi

  current_shell="$(dscl . -read "/Users/$target_user" UserShell 2>/dev/null | awk '{print $2}' || true)"
  if [[ "$current_shell" == "$zsh_path" ]]; then
    log "Default shell already zsh for $target_user."
    return 0
  fi

  if chsh -s "$zsh_path" "$target_user" >/dev/null 2>&1; then
    log "Default shell changed to zsh for $target_user."
  else
    warn "Could not change default shell for $target_user automatically. Run manually: chsh -s \"$zsh_path\" \"$target_user\""
  fi
}

sync_nvim_plugins() {
  local version_line
  local nvim_version
  local min_version="0.10.4"
  local sync_log

  export PATH="$HOME/.local/bin:$PATH"
  if ! command -v nvim >/dev/null 2>&1; then
    warn "nvim not found after install; skipping Lazy sync."
    return 0
  fi

  version_line="$(nvim --version | head -n1)"
  nvim_version="$(printf '%s' "$version_line" | awk '{print $2}' | sed 's/^v//')"
  if [[ -z "$nvim_version" ]]; then
    warn "Could not detect nvim version; skipping Lazy sync."
    return 0
  fi

  if version_lt "$nvim_version" "$min_version"; then
    warn "nvim version $nvim_version is below required $min_version; skipping Lazy sync."
    return 0
  fi

  sync_log="$(mktemp)"
  if nvim --headless "+Lazy! sync" +qa >"$sync_log" 2>&1; then
    rm -f "$sync_log"
    log "Neovim plugins synced."
  else
    warn "Lazy sync failed; check: $sync_log"
  fi
}

main() {
  ensure_macos
  [[ -d "$DOTFILES_DIR" ]] || die "Dotfiles directory not found: $DOTFILES_DIR"

  ensure_homebrew
  install_brew_packages
  install_nvim_pinned
  ensure_macos_shellenv

  local src_nvim="$DOTFILES_DIR/nvim"
  local src_tmux="$DOTFILES_DIR/tmux.conf"
  local src_sessionizer="$DOTFILES_DIR/scripts/tmux-sessionizer"
  local src_zshrc="$DOTFILES_DIR/.zshrc"

  [[ -d "$src_nvim" ]] || die "Missing source directory: $src_nvim"
  [[ -f "$src_tmux" ]] || die "Missing source file: $src_tmux"
  [[ -f "$src_sessionizer" ]] || die "Missing source file: $src_sessionizer"

  if [[ ! -x "$src_sessionizer" ]]; then
    chmod +x "$src_sessionizer"
  fi
  mkdir -p "$HOME/.config/tmux" "$HOME/scripts"

  link_with_backup "$src_nvim" "$HOME/.config/nvim"
  link_with_backup "$src_tmux" "$HOME/.config/tmux/tmux.conf"
  link_with_backup "$HOME/.config/tmux/tmux.conf" "$HOME/.tmux.conf"
  link_with_backup "$src_sessionizer" "$HOME/scripts/tmux-sessionizer"

  if [[ "$INSTALL_ZSH_STACK" == "1" ]]; then
    install_oh_my_zsh
    install_zsh_plugins

    if [[ -f "$src_zshrc" ]]; then
      link_with_backup "$src_zshrc" "$HOME/.zshrc"
    else
      warn "No .zshrc found in dotfiles; skipping .zshrc symlink."
    fi

    if [[ "$SET_DEFAULT_SHELL" == "1" ]]; then
      set_default_shell_to_zsh
    fi
  fi

  install_tpm
  sync_nvim_plugins

  if [[ "$backup_initialized" -eq 1 ]]; then
    log "Install complete with backups at: $BACKUP_DIR"
  else
    log "Install complete. No existing files needed backup."
  fi
}

main "$@"
