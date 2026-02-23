#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
REQ_FILE="${DOTFILES_DIR}/requirements/ubuntu-packages.txt"
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/.dotfiles-backup}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_DIR:-$BACKUP_ROOT/$TIMESTAMP}"
NVIM_VERSION="${NVIM_VERSION:-0.11.6}"
INSTALL_ZSH_STACK="${INSTALL_ZSH_STACK:-1}"
SET_DEFAULT_SHELL="${SET_DEFAULT_SHELL:-1}"

backup_initialized=0
SUDO=()

log() {
  printf '[install] %s\n' "$*"
}

warn() {
  printf '[install][warn] %s\n' "$*" >&2
}

die() {
  printf '[install][error] %s\n' "$*" >&2
  exit 1
}

version_lt() {
  [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" != "$2" ]]
}

init_privileges() {
  if [[ "$(id -u)" -eq 0 ]]; then
    SUDO=()
    return 0
  fi

  if command -v sudo >/dev/null 2>&1; then
    SUDO=(sudo)
    return 0
  fi

  die "sudo is required when running as a non-root user."
}

ensure_ubuntu() {
  [[ -f /etc/os-release ]] || die "/etc/os-release not found"
  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID:-}" != "ubuntu" ]] && [[ "${ID_LIKE:-}" != *ubuntu* ]]; then
    die "This installer supports Ubuntu only (detected: ${ID:-unknown})"
  fi
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

install_apt_packages() {
  [[ -f "$REQ_FILE" ]] || die "Requirements file not found: $REQ_FILE"

  "${SUDO[@]}" apt-get update
  "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl git

  mapfile -t packages < <(grep -Ev '^\s*(#|$)' "$REQ_FILE")
  if [[ "${#packages[@]}" -gt 0 ]]; then
    "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
  fi
}

resolve_nvim_arch() {
  case "$(uname -m)" in
    x86_64|amd64) printf '%s' 'x86_64' ;;
    aarch64|arm64) printf '%s' 'arm64' ;;
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
  local install_dir="/opt/nvim-v${requested}"

  if command -v nvim >/dev/null 2>&1; then
    current_version="$(nvim --version | head -n1 | awk '{print $2}' | sed 's/^v//')"
    if [[ "$current_version" == "$requested" ]]; then
      log "Neovim v${requested} already installed."
      return 0
    fi
  fi

  arch="$(resolve_nvim_arch)"
  url="https://github.com/neovim/neovim/releases/download/v${requested}/nvim-linux-${arch}.tar.gz"

  tmpdir="$(mktemp -d)"
  archive="${tmpdir}/nvim.tar.gz"

  log "Installing Neovim v${requested} (${arch})"
  curl -fsSL "$url" -o "$archive"

  "${SUDO[@]}" rm -rf "$install_dir"
  "${SUDO[@]}" mkdir -p "$install_dir"
  "${SUDO[@]}" tar -xzf "$archive" --strip-components=1 -C "$install_dir"
  "${SUDO[@]}" ln -sf "$install_dir/bin/nvim" /usr/local/bin/nvim

  current_version="$(nvim --version | head -n1 | awk '{print $2}' | sed 's/^v//')"
  if [[ "$current_version" != "$requested" ]]; then
    rm -rf "$tmpdir"
    die "Neovim version mismatch after install (expected $requested, got $current_version)"
  fi

  rm -rf "$tmpdir"
  log "Neovim v${requested} installed."
}

ensure_fd_alias() {
  if command -v fd >/dev/null 2>&1; then
    return 0
  fi

  if command -v fdfind >/dev/null 2>&1; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    log "Created alias: $HOME/.local/bin/fd -> $(command -v fdfind)"
    warn "Ensure ~/.local/bin is in PATH for fd compatibility."
  fi
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

set_default_shell_to_zsh() {
  local zsh_path
  local current_shell
  local target_user

  zsh_path="$(command -v zsh || true)"
  if [[ -z "$zsh_path" ]]; then
    warn "zsh not found; skipping default shell switch."
    return 0
  fi

  target_user="${SUDO_USER:-${USER:-$(id -un)}}"
  current_shell="$(getent passwd "$target_user" | cut -d: -f7 || true)"
  if [[ "$current_shell" == "$zsh_path" ]]; then
    log "Default shell already zsh for $target_user."
    return 0
  fi

  if chsh -s "$zsh_path" "$target_user" >/dev/null 2>&1; then
    log "Default shell changed to zsh for $target_user."
    return 0
  fi

  if [[ "${#SUDO[@]}" -gt 0 ]] && "${SUDO[@]}" chsh -s "$zsh_path" "$target_user" >/dev/null 2>&1; then
    log "Default shell changed to zsh for $target_user (via sudo)."
    return 0
  fi

  warn "Could not change default shell for $target_user automatically. Run manually: chsh -s \"$zsh_path\" \"$target_user\""
}

sync_nvim_plugins() {
  local version_line
  local nvim_version
  local min_version="0.10.4"
  local sync_log

  if ! command -v nvim >/dev/null 2>&1; then
    warn "nvim not found after package install; skipping Lazy sync."
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
    if grep -Eq "Error detected while processing|Failed to run \\\`config\\\`|E[0-9]{4}" "$sync_log"; then
      warn "Lazy sync reported errors; check: $sync_log"
    else
      rm -f "$sync_log"
      log "Neovim plugins synced."
    fi
  else
    warn "Lazy sync failed; check: $sync_log"
  fi
}

main() {
  init_privileges
  ensure_ubuntu
  [[ -d "$DOTFILES_DIR/.git" ]] || die "Dotfiles repo not found: $DOTFILES_DIR"

  install_apt_packages
  install_nvim_pinned
  ensure_fd_alias

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
