#!/usr/bin/env bash
set -euo pipefail

UBUNTU_TAG="24.04"
PRUNE_ALL=0
NVIM_VERSION="${NVIM_VERSION:-0.11.6}"
INSTALL_ZSH_STACK="${INSTALL_ZSH_STACK:-1}"
SET_DEFAULT_SHELL="${SET_DEFAULT_SHELL:-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTAINER_NAME="dotfiles-ubuntu-smoke-$(date +%s)-$RANDOM"
CONTAINER_DOTFILES_DIR="/root/dotfiles-under-test"

usage() {
  cat <<'USAGE'
Usage: ./scripts/test-ubuntu-docker.sh [options]

Options:
  --ubuntu-tag <tag>     Ubuntu tag to test (default: 24.04)
  --dotfiles-dir <path>  Dotfiles repo path to mount (default: repo root)
  --nvim-version <ver>   Neovim version for installer (default: 0.11.6)
  --prune-all            Also run full docker prune after test cleanup
  -h, --help             Show this message
USAGE
}

log() {
  printf '[docker-test] %s\n' "$*"
}

warn() {
  printf '[docker-test][warn] %s\n' "$*" >&2
}

die() {
  printf '[docker-test][error] %s\n' "$*" >&2
  exit 1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ubuntu-tag)
        [[ $# -ge 2 ]] || die "--ubuntu-tag requires a value"
        UBUNTU_TAG="$2"
        shift 2
        ;;
      --dotfiles-dir)
        [[ $# -ge 2 ]] || die "--dotfiles-dir requires a value"
        DOTFILES_DIR="$2"
        shift 2
        ;;
      --nvim-version)
        [[ $# -ge 2 ]] || die "--nvim-version requires a value"
        NVIM_VERSION="$2"
        shift 2
        ;;
      --prune-all)
        PRUNE_ALL=1
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

cleanup() {
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

  if [[ "$PRUNE_ALL" -eq 1 ]]; then
    warn "Running full docker prune (this removes unused images/cache/volumes)."
    docker system prune -af --volumes >/dev/null 2>&1 || true
  fi
}

require_tools() {
  command -v docker >/dev/null 2>&1 || die "docker is not installed"
  docker info >/dev/null 2>&1 || die "docker daemon is not reachable"
}

run_in_container() {
  local cmd="$1"
  docker exec "$CONTAINER_NAME" bash -lc "$cmd"
}

assertions() {
  run_in_container 'test -x /root/scripts/tmux-sessionizer'
  run_in_container "test -L /root/.config/nvim && [ \"\$(readlink /root/.config/nvim)\" = \"${CONTAINER_DOTFILES_DIR}/nvim\" ]"
  run_in_container "test -L /root/.config/tmux/tmux.conf && [ \"\$(readlink /root/.config/tmux/tmux.conf)\" = \"${CONTAINER_DOTFILES_DIR}/tmux.conf\" ]"
  run_in_container 'test -L /root/.tmux.conf && [ "$(readlink /root/.tmux.conf)" = "/root/.config/tmux/tmux.conf" ]'
  run_in_container "test -L /root/scripts/tmux-sessionizer && [ \"\$(readlink /root/scripts/tmux-sessionizer)\" = \"${CONTAINER_DOTFILES_DIR}/scripts/tmux-sessionizer\" ]"
  run_in_container "nvim --version | head -n1 | grep -q \"NVIM v${NVIM_VERSION#v}\""
  run_in_container 'tmux -V >/dev/null'
  run_in_container 'zsh --version >/dev/null'
  run_in_container "grep -q '~/scripts/tmux-sessionizer' ${CONTAINER_DOTFILES_DIR}/tmux.conf"
  run_in_container "grep -q '~/scripts/tmux-sessionizer' ${CONTAINER_DOTFILES_DIR}/nvim/lua/config/keymaps.lua"

  if [[ "$INSTALL_ZSH_STACK" == "1" ]]; then
    run_in_container 'test -d /root/.oh-my-zsh'
    run_in_container 'test -d /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions'
    run_in_container 'test -d /root/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting'
    run_in_container 'test -f /root/.zshrc'
  fi
}

main() {
  parse_args "$@"
  require_tools

  [[ -d "$DOTFILES_DIR/.git" ]] || die "Not a git repo: $DOTFILES_DIR"
  [[ -f "$DOTFILES_DIR/scripts/install-ubuntu.sh" ]] || die "Missing installer: $DOTFILES_DIR/scripts/install-ubuntu.sh"

  trap cleanup EXIT

  log "Starting ubuntu:${UBUNTU_TAG} container: $CONTAINER_NAME"
  docker run -d --name "$CONTAINER_NAME" -v "$DOTFILES_DIR:/dotfiles:ro" "ubuntu:${UBUNTU_TAG}" sleep infinity >/dev/null

  log "Preparing writable repo copy inside container"
  run_in_container "cp -a /dotfiles ${CONTAINER_DOTFILES_DIR}"
  run_in_container "chmod +x ${CONTAINER_DOTFILES_DIR}/scripts/install-ubuntu.sh ${CONTAINER_DOTFILES_DIR}/scripts/tmux-sessionizer"

  log "Running installer (first pass)"
  run_in_container "DOTFILES_DIR=${CONTAINER_DOTFILES_DIR} NVIM_VERSION=${NVIM_VERSION#v} INSTALL_ZSH_STACK=${INSTALL_ZSH_STACK} SET_DEFAULT_SHELL=${SET_DEFAULT_SHELL} ${CONTAINER_DOTFILES_DIR}/scripts/install-ubuntu.sh"

  log "Running installer (idempotency pass)"
  run_in_container "DOTFILES_DIR=${CONTAINER_DOTFILES_DIR} NVIM_VERSION=${NVIM_VERSION#v} INSTALL_ZSH_STACK=${INSTALL_ZSH_STACK} SET_DEFAULT_SHELL=${SET_DEFAULT_SHELL} ${CONTAINER_DOTFILES_DIR}/scripts/install-ubuntu.sh"

  log "Running assertions"
  assertions

  log "Smoke test passed."
}

main "$@"
