: << 'BATCH_HEADER'
@echo off
GOTO :BATCH
BATCH_HEADER

#!/usr/bin/env bash
#
# git-status-all.bat — Polyglot script (Batch + Bash in one file)
#
# On Windows: double-click to run. Batch finds Git Bash and re-invokes itself.
# On Linux/macOS: run with bash directly.
#
# Shows: uncommitted changes, untracked files, unpushed/unpulled commits, stashes, elapsed time.
#
# Usage:
#   git-status-all.bat [OPTIONS] [PATH]           (Windows double-click or cmd)
#   bash git-status-all.bat [OPTIONS] [PATH]      (any terminal)
#
# Options:
#   -d, --dirty         Only show repos with pending work
#   -f, --fetch         Run 'git fetch' before checking ahead/behind (slower, needs network)
#   -o, --output FILE   Export report to FILE (.csv, .md, .json)
#   -e, --export [FILE] Export report (defaults to git-status-report.csv)
#   -h, --help          Show this help message
#

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────

RED='\033[91m'
YELLOW='\033[93m'
GREEN='\033[92m'
CYAN='\033[96m'
MAGENTA='\033[95m'
GRAY='\033[90m'
WHITE='\033[97m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Arguments ────────────────────────────────────────────────────────────────

SCAN_PATH="."
DIRTY_ONLY=false
DO_FETCH=false
EXPORT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dirty)
            DIRTY_ONLY=true; shift ;;
        -f|--fetch)
            DO_FETCH=true;   shift ;;
        -o|--output)
            EXPORT_FILE="${2:-DEFAULT}"; shift 2 ;;
        -e|--export)
            if [[ $# -gt 1 && ! "$2" =~ ^- && ! -d "$2" ]]; then
                EXPORT_FILE="$2"; shift 2
            else
                EXPORT_FILE="DEFAULT"; shift
            fi
            ;;
        -h|--help)
            head -22 "$0" | tail -18
            exit 0
            ;;
        *)
            SCAN_PATH="$1"; shift
            ;;
    esac
done

SCAN_PATH="$(cd "$SCAN_PATH" && pwd)"

# ── Header ───────────────────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}  ╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}  ║${WHITE}         git status --all  ·  Status Report       ${CYAN}║${RESET}"
echo -e "${CYAN}  ╚══════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${GRAY}Scanning:${RESET} ${SCAN_PATH}"
if $DO_FETCH; then
    echo -e "  ${YELLOW}⟳ Fetch mode enabled — will contact remotes (slower)${RESET}"
fi
echo ""

# ── Timer Start ──────────────────────────────────────────────────────────────

START_MS=$(date +%s%3N 2>/dev/null || date +%s)

# ── Find repos ───────────────────────────────────────────────────────────────

mapfile -t GIT_DIRS < <(find "$SCAN_PATH" -type d -name ".git" 2>/dev/null | sort)

if [[ ${#GIT_DIRS[@]} -eq 0 ]]; then
    echo -e "  ${YELLOW}⚠  No Git repositories found under ${SCAN_PATH}${RESET}"
    echo ""
    echo -n "  Press Enter to close..."
    read -r _ || true
    exit 0
fi

TOTAL=${#GIT_DIRS[@]}

# ── Scan each repo ───────────────────────────────────────────────────────────

# Parallel arrays to hold results
declare -a R_NAME R_BRANCH R_MOD R_UNT R_AHEAD R_BEHIND R_STASH R_DIRTY
INDEX=0

for git_dir in "${GIT_DIRS[@]}"; do
    repo_path="$(dirname "$git_dir")"
    repo_name="${repo_path#"$SCAN_PATH"/}"
    [[ "$repo_name" == "$repo_path" ]] && repo_name="$(basename "$repo_path")"

    INDEX=$((INDEX + 1))
    printf "\r  ${GRAY}[%d/%d]${RESET} Scanning ${WHITE}%s${RESET} ...              " "$INDEX" "$TOTAL" "$repo_name" >&2

    pushd "$repo_path" > /dev/null

    # Optional fetch
    if $DO_FETCH; then
        git fetch --all --quiet 2>/dev/null || true
    fi

    # Branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "unknown")

    # Uncommitted changes
    modified=0
    untracked=0
    status_output=$(git status --porcelain 2>/dev/null || true)
    if [[ -n "$status_output" ]]; then
        while IFS= read -r status_line; do
            [[ -z "$status_line" ]] && continue
            if [[ "$status_line" =~ ^\?\? ]]; then
                untracked=$((untracked + 1))
            else
                modified=$((modified + 1))
            fi
        done <<< "$status_output"
    fi

    # Ahead / behind
    ahead=0
    behind=0
    upstream=$(git rev-parse --abbrev-ref "@{upstream}" 2>/dev/null || true)
    if [[ -n "$upstream" ]]; then
        ab=$(git rev-list --left-right --count "HEAD...$upstream" 2>/dev/null || echo "0 0")
        ahead=$(echo "$ab" | awk '{print $1}')
        behind=$(echo "$ab" | awk '{print $2}')
    fi
    ahead=${ahead:-0}
    behind=${behind:-0}

    # Stash count
    stashes=$(git stash list 2>/dev/null | wc -l)
    stashes=$(echo "$stashes" | tr -dc '0-9')
    stashes=${stashes:-0}

    # Dirty check
    total_issues=$((modified + untracked + ahead + behind + stashes))
    is_dirty=false
    [[ $total_issues -gt 0 ]] && is_dirty=true

    R_NAME+=("$repo_name")
    R_BRANCH+=("$branch")
    R_MOD+=("$modified")
    R_UNT+=("$untracked")
    R_AHEAD+=("$ahead")
    R_BEHIND+=("$behind")
    R_STASH+=("$stashes")
    R_DIRTY+=("$is_dirty")

    popd > /dev/null
done

# Clear progress line
printf "\r%100s\r" "" >&2

# ── Timer End & Format ────────────────────────────────────────────────────────

END_MS=$(date +%s%3N 2>/dev/null || date +%s)
diff_val=$(( END_MS - START_MS ))

if [[ ${#START_MS} -gt 10 && ${#END_MS} -gt 10 ]]; then
    # Milliseconds calculation
    if [[ $diff_val -lt 1000 ]]; then
        elapsed_time="${diff_val}ms"
    elif [[ $diff_val -lt 60000 ]]; then
        sec=$(( diff_val / 1000 ))
        dec=$(( (diff_val % 1000) / 100 ))
        elapsed_time="${sec}.${dec}s"
    else
        total_sec=$(( diff_val / 1000 ))
        min=$(( total_sec / 60 ))
        rem_sec=$(( total_sec % 60 ))
        elapsed_time="${min}m ${rem_sec}s"
    fi
else
    # Seconds fallback
    if [[ $diff_val -lt 60 ]]; then
        elapsed_time="${diff_val}s"
    else
        min=$(( diff_val / 60 ))
        rem_sec=$(( diff_val % 60 ))
        elapsed_time="${min}m ${rem_sec}s"
    fi
fi

# ── Compute column widths ─────────────────────────────────────────────────────

max_name=12
max_branch=8
for i in "${!R_NAME[@]}"; do
    len=${#R_NAME[$i]}
    [[ $len -gt $max_name ]] && max_name=$len
    len=${#R_BRANCH[$i]}
    [[ $len -gt $max_branch ]] && max_branch=$len
done
[[ $max_name   -gt 40 ]] && max_name=40
[[ $max_branch -gt 20 ]] && max_branch=20

# ── Display results ──────────────────────────────────────────────────────────

# Count for summary
dirty_count=0
clean_count=0
displayed=0

# Print header
printf "${CYAN}  %-${max_name}s  %-${max_branch}s  %5s  %5s  %5s  %5s  %5s  %s${RESET}\n" \
    "Repository" "Branch" "Mod" "Unt" "Push" "Pull" "Stash" "Status"
sep_len=$((max_name + max_branch + 46))
printf "  ${GRAY}%${sep_len}s${RESET}\n" "" | tr ' ' '─'

# Sort: dirty first, then clean
for pass in dirty clean; do
    for i in "${!R_NAME[@]}"; do
        is_dirty=${R_DIRTY[$i]}
        [[ "$pass" == "dirty" && "$is_dirty" == "false" ]] && continue
        [[ "$pass" == "clean" && "$is_dirty" == "true"  ]] && continue

        if $is_dirty; then
            dirty_count=$((dirty_count + 1))
        else
            clean_count=$((clean_count + 1))
        fi

        # Skip clean repos if --dirty
        if $DIRTY_ONLY && ! $is_dirty; then
            continue
        fi

        displayed=$((displayed + 1))

        name="${R_NAME[$i]}"
        branch="${R_BRANCH[$i]}"
        [[ ${#name}   -gt $max_name   ]] && name="${name:0:$((max_name-1))}…"
        [[ ${#branch} -gt $max_branch ]] && branch="${branch:0:$((max_branch-1))}…"

        # Color numbers
        mod=${R_MOD[$i]};     [[ $mod     -gt 0 ]] && mod_s="${RED}$(printf '%5d' "$mod")${RESET}"         || mod_s="${GRAY}$(printf '%5s' '·')${RESET}"
        unt=${R_UNT[$i]};     [[ $unt     -gt 0 ]] && unt_s="${YELLOW}$(printf '%5d' "$unt")${RESET}"      || unt_s="${GRAY}$(printf '%5s' '·')${RESET}"
        ah=${R_AHEAD[$i]};    [[ $ah      -gt 0 ]] && ah_s="${MAGENTA}$(printf '%5d' "$ah")${RESET}"       || ah_s="${GRAY}$(printf '%5s' '·')${RESET}"
        bh=${R_BEHIND[$i]};   [[ $bh      -gt 0 ]] && bh_s="${CYAN}$(printf '%5d' "$bh")${RESET}"         || bh_s="${GRAY}$(printf '%5s' '·')${RESET}"
        st=${R_STASH[$i]};    [[ $st      -gt 0 ]] && st_s="${YELLOW}$(printf '%5d' "$st")${RESET}"        || st_s="${GRAY}$(printf '%5s' '·')${RESET}"

        if $is_dirty; then
            status_s="${RED}● DIRTY${RESET}"
        else
            status_s="${GREEN}✓ clean${RESET}"
        fi

        # Branch color
        if [[ "$branch" == "main" || "$branch" == "master" ]]; then
            bc=$GREEN
        else
            bc=$YELLOW
        fi

        printf "  %-${max_name}s  ${bc}%-${max_branch}s${RESET}  %b  %b  %b  %b  %b  %b\n" \
            "$name" "$branch" "$mod_s" "$unt_s" "$ah_s" "$bh_s" "$st_s" "$status_s"
    done
done

# ── Summary ──────────────────────────────────────────────────────────────────

if [[ $displayed -eq 0 ]]; then
    echo -e "  ${GREEN}✓  All repositories are clean!${RESET}"
fi

echo ""
echo -e "  ${GRAY}─────────────────────────────────────────${RESET}"
total_repos=${#R_NAME[@]}
echo -e "  ${WHITE}Total: ${total_repos}${RESET}  │  ${RED}Dirty: ${dirty_count}${RESET}  │  ${GREEN}Clean: ${clean_count}${RESET}  │  ${CYAN}Time: ${elapsed_time}${RESET}"
echo ""
echo -e "  ${GRAY}Legend: Mod=Modified  Unt=Untracked  Push=Unpushed  Pull=Unpulled${RESET}"
echo -e "  ${GRAY}  Use -d/--dirty to show only repos needing attention${RESET}"
echo -e "  ${GRAY}  Use -f/--fetch to refresh remote status (needs network)${RESET}"
echo ""
echo -e "  ${GRAY}Built with ❤️ by AshV${RESET}"

# ── Export Helper ────────────────────────────────────────────────────────────

export_results() {
    local target_file="$1"
    local ext="${target_file##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

    case "$ext" in
        json)
            {
                echo "["
                local len=${#R_NAME[@]}
                for i in "${!R_NAME[@]}"; do
                    local comma=","
                    [[ $i -eq $((len - 1)) ]] && comma=""
                    cat <<EOF
  {
    "repository": "${R_NAME[$i]}",
    "branch": "${R_BRANCH[$i]}",
    "dirty": ${R_DIRTY[$i]},
    "modified": ${R_MOD[$i]},
    "untracked": ${R_UNT[$i]},
    "ahead": ${R_AHEAD[$i]},
    "behind": ${R_BEHIND[$i]},
    "stashes": ${R_STASH[$i]}
  }$comma
EOF
                done
                echo "]"
            } > "$target_file"
            ;;

        md)
            {
                echo "# git status --all — Scan Report"
                echo ""
                echo "- **Date**: $(date '+%Y-%m-%d %H:%M:%S')"
                echo "- **Scanned Path**: \`$SCAN_PATH\`"
                echo "- **Total**: ${#R_NAME[@]} | **Dirty**: $dirty_count | **Clean**: $clean_count | **Time**: $elapsed_time"
                echo ""
                echo "| Repository | Branch | Status | Mod | Unt | Push | Pull | Stash |"
                echo "| :--- | :--- | :--- | :---: | :---: | :---: | :---: | :---: |"
                for i in "${!R_NAME[@]}"; do
                    local st="clean"
                    [[ "${R_DIRTY[$i]}" == "true" ]] && st="DIRTY"
                    echo "| \`${R_NAME[$i]}\` | \`${R_BRANCH[$i]}\` | **$st** | ${R_MOD[$i]} | ${R_UNT[$i]} | ${R_AHEAD[$i]} | ${R_BEHIND[$i]} | ${R_STASH[$i]} |"
                done
                echo ""
                echo "_Built with ❤️ by AshV_"
            } > "$target_file"
            ;;

        *)
            # Default: CSV
            {
                echo "Repository,Branch,Status,Modified,Untracked,Unpushed,Unpulled,Stashes"
                for i in "${!R_NAME[@]}"; do
                    local st="clean"
                    [[ "${R_DIRTY[$i]}" == "true" ]] && st="DIRTY"
                    echo "\"${R_NAME[$i]}\",\"${R_BRANCH[$i]}\",\"$st\",${R_MOD[$i]},${R_UNT[$i]},${R_AHEAD[$i]},${R_BEHIND[$i]},${R_STASH[$i]}"
                done
            } > "$target_file"
            ;;
    esac

    echo ""
    echo -e "  ${GREEN}✓ Results exported to: ${WHITE}$target_file${RESET}"
}

# ── Export & Prompt ──────────────────────────────────────────────────────────

if [[ -n "$EXPORT_FILE" ]]; then
    if [[ "$EXPORT_FILE" == "DEFAULT" ]]; then
        EXPORT_FILE="git-status-report-$(date '+%Y%m%d-%H%M%S').csv"
    fi
    export_results "$EXPORT_FILE"
    echo ""
    echo -n "  Press Enter to close..."
    read -r _ || true
else
    echo ""
    echo -n "  Press Enter to close (or 'e' to export report)... "
    read -r choice || true
    choice=$(echo "${choice:-}" | tr '[:upper:]' '[:lower:]' | xargs 2>/dev/null || echo "${choice:-}")
    if [[ "$choice" == "e" || "$choice" == "export" ]]; then
        timestamped_file="git-status-report-$(date '+%Y%m%d-%H%M%S').csv"
        export_results "$timestamped_file"
        echo ""
        echo -n "  Press Enter to close..."
        read -r _ || true
    fi
fi

exit 0

REM ── Windows Batch section ──────────────────────────────────────────────────
REM Bash never reaches here (exit 0 above). cmd.exe GOTOs here from line 3.
:BATCH
@echo off

set "BASH_EXE="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH_EXE=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH_EXE if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "BASH_EXE=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not defined BASH_EXE (
    where bash >nul 2>&1 && (
        for /f "delims=" %%i in ('where bash') do set "BASH_EXE=%%i"
    )
)

if not defined BASH_EXE (
    echo.
    echo   ERROR: Git Bash not found!
    echo   Please install Git for Windows from https://git-scm.com
    echo.
    pause
    exit /b 1
)

"%BASH_EXE%" "%~f0" %*
if %ERRORLEVEL% neq 0 (
    echo.
    echo   Execution stopped with error code %ERRORLEVEL%.
    pause
)
