# 🔍 git status --all — Multi-Repo Status Scanner

Quickly check **all** Git repositories under a folder for pending work —
uncommitted changes, untracked files, unpushed/unpulled commits, and stashes.

Perfect for when you work across multiple machines and want to make sure
nothing is left behind before you leave.

## Features

| Check               | Description                                   |
| ------------------- | --------------------------------------------- |
| **Modified (Mod)**  | Staged + unstaged changes                     |
| **Untracked (Unt)** | New files not yet added to Git                |
| **Unpushed (Push)** | Local commits not yet pushed to remote        |
| **Unpulled (Pull)** | Remote commits not yet pulled (with `--fetch`) |
| **Stashes**         | Stashed changes                               |

## Quick Start

### Windows Double-Click / CMD (.bat)

Double-click `git-status-all.bat` directly from Windows Explorer, or run in cmd:

```cmd
:: Scan current folder
git-status-all.bat

:: Scan specific folder
git-status-all.bat "D:\Projects"

:: Dirty repos only
git-status-all.bat -d "D:\Projects"
```

### PowerShell (Windows)

```powershell
# Scan current directory
.\git-status-all.ps1

# Scan a specific folder
.\git-status-all.ps1 -Path "D:\Projects"

# Only show dirty repos
.\git-status-all.ps1 -Path "D:\Projects" -Dirty

# Fetch remotes first (accurate push/pull, needs network)
.\git-status-all.ps1 -Path "D:\Projects" -Fetch -Dirty
```

### Bash (Linux / macOS / Git Bash / WSL)

```bash
# Make executable (first time only)
chmod +x git-status-all.sh

# Scan current directory
./git-status-all.sh

# Scan a specific folder
./git-status-all.sh ~/Projects

# Only show dirty repos
./git-status-all.sh -d ~/Projects

# Fetch remotes first
./git-status-all.sh -f -d ~/Projects
```

## Sample Output

```
  ╔══════════════════════════════════════════════════╗
  ║         git status --all  ·  Status Report        ║
  ╚══════════════════════════════════════════════════╝

  Scanning: D:\Projects

  Repository          Branch        Mod    Unt   Push   Pull  Stash  Status
  ─────────────────────────────────────────────────────────────────────────
  my-web-app          main            3      1      2      ·      ·  ● DIRTY
  api-server          feature/auth    ·      ·      5      ·      ·  ● DIRTY
  docs-site           main            ·      ·      ·      ·      1  ● DIRTY
  utils-lib           main            ·      ·      ·      ·      ·  ✓ clean

  ─────────────────────────────────────────
  Total: 4  │  Dirty: 3  │  Clean: 1  │  Time: 1.4s

  Built with ❤️ by AshV
```

## Options

| Flag | PowerShell | Bash / Bat | Description |
| :--- | :--- | :--- | :--- |
| **Scan path** | `-Path <dir>` | `<dir>` (arg) | Root folder to scan (default: `.`) |
| **Dirty only** | `-Dirty` | `-d, --dirty` | Hide clean repos |
| **Fetch remotes** | `-Fetch` | `-f, --fetch` | Run `git fetch` first (slower, hits remotes) |
| **Export report** | `-Export <file>` | `-o, --output <file>` | Export results to file (`.csv`, `.md`, `.json`) |
| **Quick export** | `-Export` | `-e, --export` | Quick export to timestamped CSV (`git-status-report-YYYYMMDD-HHmmss.csv`) |

> [!TIP]
> **Interactive Export**: When running without export flags, the prompt at the end lets you press **`e`** to instantly save `git-status-report-YYYYMMDD-HHmmss.csv`!

## Requirements

- **Git** (any recent version)
- **PowerShell 7+** (for `.ps1`) or **Bash 4+** (for `.sh`)
- No other dependencies!

## Tips & Git Integration

- **Run as `git status-all`**:
  Add a global Git alias:
  ```bash
  git config --global alias.status-all "!bash 'A:/GitHub/GitScript/git-status-all.sh'"
  ```
  Now you can run `git status-all` from any directory or terminal!

- **Run literally as `git status --all`**:
  Add this to your PowerShell profile (`$PROFILE`):
  ```powershell
  function git {
      if ($args[0] -eq "status" -and $args[1] -eq "--all") {
          & "A:\GitHub\GitScript\git-status-all.ps1" @($args | Select-Object -Skip 2)
      } else {
          & (Get-Command -CommandType Application git)[0].Source @args
      }
  }
  ```
  Or in `~/.bashrc` / `~/.zshrc`:
  ```bash
  git() {
      if [[ "$1" == "status" && "$2" == "--all" ]]; then
          shift 2
          "A:/GitHub/GitScript/git-status-all.sh" "$@"
      else
          command git "$@"
      fi
  }
  ```

- **Quick CLI aliases**:
  ```powershell
  # PowerShell profile
  Set-Alias gscan "A:\GitHub\GitScript\git-status-all.ps1"
  ```
  ```bash
  # ~/.bashrc or ~/.zshrc
  alias gscan="A:/GitHub/GitScript/git-status-all.sh"
  ```

## License

MIT — Built with ❤️ by AshV
