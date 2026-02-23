#!/usr/bin/env bash
set -euo pipefail

DOTFILES_REPO_URL="${DOTFILES_REPO_URL:-https://github.com/EmreOzdemiroglu/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
INSTALLER_PATH="scripts/install-macos.sh"

log() {
  printf '[bootstrap-macos] %s\n' "$*"
}

die() {
  printf '[bootstrap-macos][error] %s\n' "$*" >&2
  exit 1
}

require_tools() {
  command -v git >/dev/null 2>&1 || die "git is required"
  command -v curl >/dev/null 2>&1 || die "curl is required"
}

clone_or_update_repo() {
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

run_installer() {
  local installer="${DOTFILES_DIR}/${INSTALLER_PATH}"
  [[ -f "$installer" ]] || die "Installer not found: $installer"
  chmod +x "$installer"

  log "Running macOS installer"
  DOTFILES_DIR="$DOTFILES_DIR" "$installer" "$@"
}

main() {
  [[ "$(uname -s)" == "Darwin" ]] || die "This bootstrap supports macOS only."
  require_tools
  clone_or_update_repo
  run_installer "$@"
  log "Bootstrap complete"
}

main "$@"
