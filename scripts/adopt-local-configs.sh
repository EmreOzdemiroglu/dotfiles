#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIVE_NVIM_DIR="${HOME}/.config/nvim"
LIVE_TMUX_CONF="${HOME}/.config/tmux/tmux.conf"
BACKUP_DIR="${HOME}/.dotfiles-backups/adopt-$(date +%Y%m%d-%H%M%S)"
backup_initialized=0

usage() {
  cat <<'EOF'
Usage: ./scripts/adopt-local-configs.sh [options]

Copy your current live Neovim and tmux config into this repo, then relink
those live paths back to the repo so future edits stay in sync automatically.

Options:
  --dotfiles-dir <path>   Dotfiles repo path (default: script parent)
  --live-nvim <path>      Live Neovim config path (default: ~/.config/nvim)
  --live-tmux <path>      Live tmux config path (default: ~/.config/tmux/tmux.conf)
  -h, --help              Show this message
EOF
}

log() {
  printf '[adopt-local-configs] %s\n' "$*"
}

die() {
  printf '[adopt-local-configs][error] %s\n' "$*" >&2
  exit 1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dotfiles-dir)
        [[ $# -ge 2 ]] || die "--dotfiles-dir requires a value"
        DOTFILES_DIR="$2"
        shift 2
        ;;
      --live-nvim)
        [[ $# -ge 2 ]] || die "--live-nvim requires a value"
        LIVE_NVIM_DIR="$2"
        shift 2
        ;;
      --live-tmux)
        [[ $# -ge 2 ]] || die "--live-tmux requires a value"
        LIVE_TMUX_CONF="$2"
        shift 2
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

ensure_backup_dir() {
  if [[ "$backup_initialized" -eq 0 ]]; then
    mkdir -p "$BACKUP_DIR"
    backup_initialized=1
  fi
}

backup_path() {
  local target="$1"
  local relative="${target#$HOME/}"

  if [[ "$relative" == "$target" ]]; then
    relative="$(basename "$target")"
  fi

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

backup_repo_if_needed() {
  local target="$1"

  if [[ -e "$target" ]] || [[ -L "$target" ]]; then
    ensure_backup_dir
    local relative="${target#$DOTFILES_DIR/}"
    local out="$BACKUP_DIR/repo/${relative}"
    mkdir -p "$(dirname "$out")"
    mv "$target" "$out"
    log "Backed up repo copy: $target -> $out"
  fi
}

same_path() {
  local left="$1"
  local right="$2"
  [[ -e "$left" ]] && [[ -e "$right" ]] && [[ "$left" -ef "$right" ]]
}

replace_repo_nvim() {
  local source="$1"
  local destination="$2"
  local tmpdir
  tmpdir="$(mktemp -d)"

  mkdir -p "$tmpdir/nvim"
  cp -R "$source/." "$tmpdir/nvim/"

  find "$tmpdir/nvim" \( -name '.DS_Store' -o -name '.nvimlog' \) -exec rm -rf {} +

  backup_repo_if_needed "$destination"
  mkdir -p "$(dirname "$destination")"
  mv "$tmpdir/nvim" "$destination"
  rm -rf "$tmpdir"

  log "Imported Neovim config into $destination"
}

replace_repo_tmux() {
  local source="$1"
  local destination="$2"

  backup_repo_if_needed "$destination"
  mkdir -p "$(dirname "$destination")"
  cp "$source" "$destination"
  log "Imported tmux config into $destination"
}

link_with_backup() {
  local source="$1"
  local target="$2"

  mkdir -p "$(dirname "$target")"

  if same_path "$target" "$source"; then
    log "Already linked: $target"
    return 0
  fi

  backup_if_needed "$target"
  ln -s "$source" "$target"
  log "Linked: $target -> $source"
}

main() {
  parse_args "$@"

  local repo_nvim="$DOTFILES_DIR/nvim"
  local repo_tmux="$DOTFILES_DIR/tmux.conf"

  [[ -d "$DOTFILES_DIR/.git" ]] || die "Dotfiles repo not found: $DOTFILES_DIR"
  [[ -d "$LIVE_NVIM_DIR" ]] || die "Live Neovim config not found: $LIVE_NVIM_DIR"
  [[ -f "$LIVE_TMUX_CONF" ]] || die "Live tmux config not found: $LIVE_TMUX_CONF"

  if same_path "$LIVE_NVIM_DIR" "$repo_nvim"; then
    log "Live Neovim config already points at $repo_nvim"
  else
    replace_repo_nvim "$LIVE_NVIM_DIR" "$repo_nvim"
  fi

  if same_path "$LIVE_TMUX_CONF" "$repo_tmux"; then
    log "Live tmux config already points at $repo_tmux"
  else
    replace_repo_tmux "$LIVE_TMUX_CONF" "$repo_tmux"
  fi

  link_with_backup "$repo_nvim" "$LIVE_NVIM_DIR"
  link_with_backup "$repo_tmux" "$LIVE_TMUX_CONF"
  link_with_backup "$LIVE_TMUX_CONF" "$HOME/.tmux.conf"

  if [[ "$backup_initialized" -eq 1 ]]; then
    log "Adoption complete with backups at: $BACKUP_DIR"
  else
    log "Adoption complete. No live files needed backup."
  fi
}

main "$@"
