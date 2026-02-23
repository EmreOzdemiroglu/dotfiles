#!/usr/bin/env bash
set -euo pipefail

DOTFILES_REPO_URL="${DOTFILES_REPO_URL:-https://github.com/EmreOzdemiroglu/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
INSTALLER_PATH="scripts/install-ubuntu.sh"
SUDO=()

log() {
  printf '[bootstrap] %s\n' "$*"
}

die() {
  printf '[bootstrap][error] %s\n' "$*" >&2
  exit 1
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

ensure_git() {
  if command -v git >/dev/null 2>&1; then
    return 0
  fi

  log "Installing git..."
  "${SUDO[@]}" apt-get update
  "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y git ca-certificates curl
}

update_or_clone_repo() {
  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    log "Updating existing repo at $DOTFILES_DIR"
    git -C "$DOTFILES_DIR" pull --ff-only
    return 0
  fi

  if [[ -e "$DOTFILES_DIR" ]]; then
    die "$DOTFILES_DIR exists but is not a git repository."
  fi

  log "Cloning dotfiles into $DOTFILES_DIR"
  git clone "$DOTFILES_REPO_URL" "$DOTFILES_DIR"
}

main() {
  init_privileges
  ensure_git
  update_or_clone_repo

  local installer="${DOTFILES_DIR}/${INSTALLER_PATH}"
  [[ -f "$installer" ]] || die "Installer not found: $installer"
  chmod +x "$installer"

  log "Running Ubuntu installer..."
  DOTFILES_DIR="$DOTFILES_DIR" "$installer" "$@"
}

main "$@"
