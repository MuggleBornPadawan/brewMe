# brewMe

A workspace for system maintenance scripts and dotfiles backups.

## Scripts

### 1. `scripts/backup_dotfiles.sh`
Backs up your configuration (dot) files from the home folder (`~`) into the local `backup/` directory of this repository, preserving the directory structure.

#### Usage
Run the script to execute the backup:
```bash
./scripts/backup_dotfiles.sh
```

To see what would be copied without performing the actual copy, use the dry-run option:
```bash
./scripts/backup_dotfiles.sh --dry-run
```

#### Included Configurations
The script is pre-configured to back up:
- `~/.tmux.conf`
- `~/.tmux`
- `~/.zshrc`
- `~/.gitconfig`
- `~/.emacs.d/init.el`
- `~/.config/btop`
- `~/.config/htop`
- `~/.config/neofetch`

You can customize this list directly by editing the `DEFAULT_DOTFILES` array in [scripts/backup_dotfiles.sh](file:///Users/ganeshrajendran/brewMe/scripts/backup_dotfiles.sh).

---

### 2. `scripts/updateMe.sh`
Performs system-wide packages and dependencies updates for Homebrew, npm, and Python pip packages.

#### Usage
```bash
./scripts/updateMe.sh
```
