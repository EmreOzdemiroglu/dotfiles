# Dotfiles Bootstrap

## Fresh Ubuntu (single command)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/EmreOzdemiroglu/dotfiles/main/bootstrap/ubuntu-bootstrap.sh)
```

## Fresh Ubuntu (repo already cloned)

```bash
cd ~/dotfiles
NVIM_VERSION=0.11.6 INSTALL_ZSH_STACK=1 SET_DEFAULT_SHELL=1 ./scripts/install-ubuntu.sh
```

## Remote Setup (`kasa`)

Run from your Mac:

```bash
cd ~/dotfiles
./scripts/bootstrap-remote-kasa.sh --host kasa --nvim-version 0.11.6
```

Useful flags:

```bash
./scripts/bootstrap-remote-kasa.sh --host kasa --dotfiles-dir '$HOME/dotfiles' --repo-url https://github.com/EmreOzdemiroglu/dotfiles.git
./scripts/bootstrap-remote-kasa.sh --host kasa --no-zsh-stack --no-default-shell
```

## Docker Smoke Test (Ubuntu 24.04)

```bash
cd ~/dotfiles
./scripts/test-ubuntu-docker.sh --nvim-version 0.11.6
```

## Docker Cleanup Modes

- Default: removes only the test container.
- Aggressive:

```bash
./scripts/test-ubuntu-docker.sh --prune-all
```

`--prune-all` runs full Docker prune and can remove unrelated image/cache/volume data.
