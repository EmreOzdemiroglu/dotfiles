#!/usr/bin/env bash
set -euo pipefail

REMOTE_HOST="kasa"
REMOTE_DOTFILES_DIR='$HOME/dotfiles'
DOTFILES_REPO_URL="${DOTFILES_REPO_URL:-https://github.com/EmreOzdemiroglu/dotfiles.git}"
NVIM_VERSION="${NVIM_VERSION:-0.11.6}"
INSTALL_ZSH_STACK="${INSTALL_ZSH_STACK:-1}"
SET_DEFAULT_SHELL="${SET_DEFAULT_SHELL:-1}"

usage() {
  cat <<'USAGE'
Usage: ./scripts/bootstrap-remote-kasa.sh [options]

Options:
  --host <ssh-host>          SSH host alias (default: kasa)
  --dotfiles-dir <path>      Remote dotfiles path (default: $HOME/dotfiles)
  --repo-url <url>           Dotfiles repository URL
  --nvim-version <version>   Neovim version to install (default: 0.11.6)
  --no-zsh-stack             Skip oh-my-zsh + plugins setup
  --no-default-shell         Do not attempt chsh to zsh
  -h, --help                 Show this message
USAGE
}

log() {
  printf '[remote-bootstrap] %s\n' "$*"
}

die() {
  printf '[remote-bootstrap][error] %s\n' "$*" >&2
  exit 1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --host)
        [[ $# -ge 2 ]] || die "--host requires a value"
        REMOTE_HOST="$2"
        shift 2
        ;;
      --dotfiles-dir)
        [[ $# -ge 2 ]] || die "--dotfiles-dir requires a value"
        REMOTE_DOTFILES_DIR="$2"
        shift 2
        ;;
      --repo-url)
        [[ $# -ge 2 ]] || die "--repo-url requires a value"
        DOTFILES_REPO_URL="$2"
        shift 2
        ;;
      --nvim-version)
        [[ $# -ge 2 ]] || die "--nvim-version requires a value"
        NVIM_VERSION="$2"
        shift 2
        ;;
      --no-zsh-stack)
        INSTALL_ZSH_STACK="0"
        shift
        ;;
      --no-default-shell)
        SET_DEFAULT_SHELL="0"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  command -v ssh >/dev/null 2>&1 || die "ssh not found"

  log "Connecting to ${REMOTE_HOST}"
  ssh "$REMOTE_HOST" bash -s -- \
    "$REMOTE_DOTFILES_DIR" \
    "$DOTFILES_REPO_URL" \
    "${NVIM_VERSION#v}" \
    "$INSTALL_ZSH_STACK" \
    "$SET_DEFAULT_SHELL" <<'REMOTE_SCRIPT'
set -euo pipefail

remote_dotfiles_dir="$1"
repo_url="$2"
nvim_version="$3"
install_zsh_stack="$4"
set_default_shell="$5"

if [[ -d "$remote_dotfiles_dir/.git" ]]; then
  git -C "$remote_dotfiles_dir" pull --ff-only
else
  git clone "$repo_url" "$remote_dotfiles_dir"
fi

cd "$remote_dotfiles_dir"
chmod +x scripts/install-ubuntu.sh
DOTFILES_DIR="$remote_dotfiles_dir" \
NVIM_VERSION="$nvim_version" \
INSTALL_ZSH_STACK="$install_zsh_stack" \
SET_DEFAULT_SHELL="$set_default_shell" \
./scripts/install-ubuntu.sh
REMOTE_SCRIPT

  log "Remote bootstrap completed on ${REMOTE_HOST}"
}

main "$@"
