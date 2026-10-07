<#
.SYNOPSIS
    Scans a directory tree for Git repositories and reports pending work.

.DESCRIPTION
    Recursively finds every Git repository under a given folder and displays
    a summary table showing:
      - Uncommitted (staged + unstaged) changes
      - Untracked files
      - Unpushed commits (ahead of remote)
      - Unpulled commits (behind remote)
      - Stash entries
      - Elapsed scan time

    Repos with nothing pending are shown as clean. Use -Dirty to hide them.

.PARAMETER Path
    Root folder to scan. Defaults to the current directory.

.PARAMETER Dirty
    If set, only repos with pending work are shown.

.PARAMETER Fetch
    If set, runs 'git fetch' on each repo before checking ahead/behind.
    This gives accurate remote status but is slower and needs network.

.PARAMETER Export
    Export results to a file (.csv, .md, .json). Defaults to CSV.

.EXAMPLE
    .\git-status-all.ps1
    .\git-status-all.ps1 -Path "D:\Projects" -Dirty
    .\git-status-all.ps1 -Path "D:\Projects" -Export "report.csv"
    .\git-status-all.ps1 -Path "D:\Projects" -Export "report.md"
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path = ".",

    [switch]$Dirty,

    [switch]$Fetch,

    [Alias("Output")]
    [string]$Export
)

# ── Helpers ──────────────────────────────────────────────────────────────────

function Get-AnsiColor {
    param([string]$Color)
    switch ($Color) {
        "Red"     { "`e[91m" }
        "Yellow"  { "`e[93m" }
        "Green"   { "`e[92m" }
        "Cyan"    { "`e[96m" }
        "Magenta" { "`e[95m" }
        "Gray"    { "`e[90m" }
        "White"   { "`e[97m" }
        "Reset"   { "`e[0m"  }
        default   { ""       }
    }
}

$R = Get-AnsiColor "Reset"

function Write-Header {
    $line = "─" * 90
    Write-Host ""
    Write-Host "$(Get-AnsiColor 'Cyan')  ╔══════════════════════════════════════════════════╗$R"
    Write-Host "$(Get-AnsiColor 'Cyan')  ║$(Get-AnsiColor 'White')         git status --all  ·  Status Report        $(Get-AnsiColor 'Cyan')║$R"
    Write-Host "$(Get-AnsiColor 'Cyan')  ╚══════════════════════════════════════════════════╝$R"
    Write-Host ""
}

# ── Resolve root path ───────────────────────────────────────────────────────

$RootPath = (Resolve-Path -Path $Path -ErrorAction Stop).Path

Write-Header
Write-Host "  $(Get-AnsiColor 'Gray')Scanning:$R $RootPath"
if ($Fetch) {
    Write-Host "  $(Get-AnsiColor 'Yellow')⟳ Fetch mode enabled — will contact remotes (slower)$R"
}
Write-Host ""

# ── Timer Start ──────────────────────────────────────────────────────────────

$sw = [System.Diagnostics.Stopwatch]::StartNew()

# ── Find all .git directories recursively ────────────────────────────────────

$gitDirs = Get-ChildItem -Path $RootPath -Directory -Recurse -Force -Filter ".git" -ErrorAction SilentlyContinue

if (-not $gitDirs -or $gitDirs.Count -eq 0) {
    Write-Host "  $(Get-AnsiColor 'Yellow')⚠  No Git repositories found under $RootPath$R"
    Write-Host ""
    Read-Host "  Press Enter to close"
    exit 0
}

# ── Scan each repo ───────────────────────────────────────────────────────────

$results  = @()
$total    = $gitDirs.Count
$current  = 0

foreach ($gitDir in $gitDirs) {
    $current++
    $repoPath = $gitDir.Parent.FullName
    $repoName = [System.IO.Path]::GetRelativePath($RootPath, $repoPath)
    if ($repoName -eq ".") { $repoName = (Split-Path $repoPath -Leaf) }

    # Progress indicator
    Write-Host "`r  $(Get-AnsiColor 'Gray')[$current/$total]$R Scanning $(Get-AnsiColor 'White')$repoName$R ...          " -NoNewline

    Push-Location $repoPath
    try {
        # Optionally fetch from remote
        if ($Fetch) {
            git fetch --all --quiet 2>$null
        }

        # Current branch
        $branch = git symbolic-ref --short HEAD 2>$null
        if (-not $branch) { $branch = git rev-parse --short HEAD 2>$null }
        if (-not $branch) { $branch = "unknown" }

        # Uncommitted changes (staged + unstaged, excluding untracked)
        $statusOutput = git status --porcelain 2>$null
        $modified  = @($statusOutput | Where-Object { $_ -and $_ -notmatch '^\?\?' }).Count
        $untracked = @($statusOutput | Where-Object { $_ -and $_ -match '^\?\?' }).Count

        # Ahead / behind remote
        $ahead  = 0
        $behind = 0
        $upstream = git rev-parse --abbrev-ref "@{upstream}" 2>$null
        if ($upstream) {
            $aheadBehind = git rev-list --left-right --count "HEAD...$upstream" 2>$null
            if ($aheadBehind -match '(\d+)\s+(\d+)') {
                $ahead  = [int]$Matches[1]
                $behind = [int]$Matches[2]
            }
        }

        # Stash count
        $stashes = @(git stash list 2>$null).Count

        # Determine overall status
        $isDirty = ($modified + $untracked + $ahead + $behind + $stashes) -gt 0

        $results += [PSCustomObject]@{
            Name      = $repoName
            Branch    = $branch
            Modified  = $modified
            Untracked = $untracked
            Ahead     = $ahead
            Behind    = $behind
            Stashes   = $stashes
            IsDirty   = $isDirty
            Path      = $repoPath
        }
    }
    finally {
        Pop-Location
    }
}

# Clear the progress line
Write-Host "`r$(' ' * 100)`r" -NoNewline

# ── Timer Stop & Format ──────────────────────────────────────────────────────

$sw.Stop()
$elapsed = $sw.Elapsed
$elapsedStr = if ($elapsed.TotalMinutes -ge 1) {
    "{0}m {1:d2}s" -f [int]$elapsed.TotalMinutes, $elapsed.Seconds
} elseif ($elapsed.TotalSeconds -ge 1) {
    "{0:N1}s" -f $elapsed.TotalSeconds
} else {
    "{0}ms" -f $elapsed.Milliseconds
}

# ── Filter ──────────────────────────────────────────────────────────────────

$displayResults = if ($Dirty) {
    @($results | Where-Object { $_.IsDirty })
} else {
    $results
}

# ── Display ──────────────────────────────────────────────────────────────────

if ($displayResults.Count -eq 0) {
    Write-Host "  $(Get-AnsiColor 'Green')✓  All repositories are clean!$R"
} else {
    # Column widths
    $nameWidth   = [Math]::Max(($displayResults | ForEach-Object { $_.Name.Length }   | Measure-Object -Maximum).Maximum, 12)
    $branchWidth = [Math]::Max(($displayResults | ForEach-Object { $_.Branch.Length } | Measure-Object -Maximum).Maximum, 8)
    $nameWidth   = [Math]::Min($nameWidth, 40)
    $branchWidth = [Math]::Min($branchWidth, 20)

    # Header
    $headerFmt = "  {0,-$nameWidth}  {1,-$branchWidth}  {2,5}  {3,5}  {4,5}  {5,5}  {6,5}  {7}"
    $header = $headerFmt -f "Repository", "Branch", "Mod", "Unt", "Push", "Pull", "Stash", "Status"
    Write-Host "$(Get-AnsiColor 'Cyan')$header$R"
    Write-Host "$(Get-AnsiColor 'Gray')  $("─" * ($nameWidth + $branchWidth + 46))$R"

    foreach ($repo in $displayResults | Sort-Object -Property IsDirty -Descending) {
        $name   = $repo.Name.Length -gt $nameWidth ? $repo.Name.Substring(0, $nameWidth - 1) + "…" : $repo.Name
        $branch = $repo.Branch.Length -gt $branchWidth ? $repo.Branch.Substring(0, $branchWidth - 1) + "…" : $repo.Branch

        # Color-code each number
        $modStr     = if ($repo.Modified  -gt 0) { "$(Get-AnsiColor 'Red')$("{0,5}" -f $repo.Modified)$R"  } else { "$(Get-AnsiColor 'Gray')$("{0,5}" -f '·')$R" }
        $untStr     = if ($repo.Untracked -gt 0) { "$(Get-AnsiColor 'Yellow')$("{0,5}" -f $repo.Untracked)$R" } else { "$(Get-AnsiColor 'Gray')$("{0,5}" -f '·')$R" }
        $aheadStr   = if ($repo.Ahead     -gt 0) { "$(Get-AnsiColor 'Magenta')$("{0,5}" -f $repo.Ahead)$R"    } else { "$(Get-AnsiColor 'Gray')$("{0,5}" -f '·')$R" }
        $behindStr  = if ($repo.Behind    -gt 0) { "$(Get-AnsiColor 'Cyan')$("{0,5}" -f $repo.Behind)$R"      } else { "$(Get-AnsiColor 'Gray')$("{0,5}" -f '·')$R" }
        $stashStr   = if ($repo.Stashes   -gt 0) { "$(Get-AnsiColor 'Yellow')$("{0,5}" -f $repo.Stashes)$R"   } else { "$(Get-AnsiColor 'Gray')$("{0,5}" -f '·')$R" }

        # Status label
        if ($repo.IsDirty) {
            $statusStr = "$(Get-AnsiColor 'Red')● DIRTY$R"
        } else {
            $statusStr = "$(Get-AnsiColor 'Green')✓ clean$R"
        }

        $branchColor = if ($repo.Branch -eq "main" -or $repo.Branch -eq "master") { Get-AnsiColor 'Green' } else { Get-AnsiColor 'Yellow' }

        Write-Host "  $("{0,-$nameWidth}" -f $name)  $branchColor$("{0,-$branchWidth}" -f $branch)$R  $modStr  $untStr  $aheadStr  $behindStr  $stashStr  $statusStr"
    }
}

# ── Summary ──────────────────────────────────────────────────────────────────

$dirtyCount = @($results | Where-Object { $_.IsDirty }).Count
$cleanCount = @($results | Where-Object { -not $_.IsDirty }).Count

Write-Host ""
Write-Host "$(Get-AnsiColor 'Gray')  ─────────────────────────────────────────$R"
Write-Host "  $(Get-AnsiColor 'White')Total: $($results.Count)$R  │  $(Get-AnsiColor 'Red')Dirty: $dirtyCount$R  │  $(Get-AnsiColor 'Green')Clean: $cleanCount$R  │  $(Get-AnsiColor 'Cyan')Time: $elapsedStr$R"

# Legend
Write-Host ""
Write-Host "  $(Get-AnsiColor 'Gray')Legend: Mod=Modified  Unt=Untracked  Push=Unpushed  Pull=Unpulled$R"
Write-Host "  $(Get-AnsiColor 'Gray')  Use -Dirty to show only repos needing attention$R"
Write-Host "  $(Get-AnsiColor 'Gray')  Use -Fetch to refresh remote status (needs network)$R"
Write-Host ""
Write-Host "  $(Get-AnsiColor 'Gray')Built with ❤️ by AshV$R"

# ── Export Function ──────────────────────────────────────────────────────────

function Export-ScanReport {
    param([string]$FilePath)
    $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
    switch ($ext) {
        ".json" {
            $results | Select-Object Name, Branch, IsDirty, Modified, Untracked, Ahead, Behind, Stashes, Path |
                ConvertTo-Json -Depth 2 | Set-Content -Path $FilePath -Encoding UTF8
        }
        ".md" {
            $sb = [System.Text.StringBuilder]::new()
            [void]$sb.AppendLine("# git status --all — Scan Report")
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("- **Date**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
            [void]$sb.AppendLine("- **Scanned Path**: \`$RootPath\`")
            [void]$sb.AppendLine("- **Total**: $($results.Count) | **Dirty**: $dirtyCount | **Clean**: $cleanCount | **Time**: $elapsedStr")
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("| Repository | Branch | Status | Mod | Unt | Push | Pull | Stash |")
            [void]$sb.AppendLine("| :--- | :--- | :--- | :---: | :---: | :---: | :---: | :---: |")
            foreach ($r in ($results | Sort-Object -Property IsDirty -Descending)) {
                $st = if ($r.IsDirty) { "**DIRTY**" } else { "clean" }
                [void]$sb.AppendLine("| \`$($r.Name)\` | \`$($r.Branch)\` | $st | $($r.Modified) | $($r.Untracked) | $($r.Ahead) | $($r.Behind) | $($r.Stashes) |")
            }
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("_Built with ❤️ by AshV_")
            $sb.ToString() | Set-Content -Path $FilePath -Encoding UTF8
        }
        default {
            $results | Select-Object @{N="Repository";E={$_.Name}}, Branch, @{N="Status";E={if ($_.IsDirty){"DIRTY"}else{"clean"}}}, Modified, Untracked, @{N="Unpushed";E={$_.Ahead}}, @{N="Unpulled";E={$_.Behind}}, Stashes, Path |
                Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8
        }
    }
    Write-Host ""
    Write-Host "  $(Get-AnsiColor 'Green')✓ Results exported to: $(Get-AnsiColor 'White')$FilePath$R"
}

# ── Export & Prompt ──────────────────────────────────────────────────────────

if ($Export) {
    if ($Export -eq "DEFAULT" -or $Export -eq "$true" -or [string]::IsNullOrWhiteSpace($Export)) {
        $timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
        $Export = "git-status-report-$timestamp.csv"
    }
    Export-ScanReport -FilePath $Export
    Write-Host ""
    Read-Host "  Press Enter to close"
} else {
    Write-Host ""
    $choice = Read-Host "  Press Enter to close (or 'e' to export report)"
    if ($choice -match '^\s*(e|export)\s*$') {
        $timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
        $reportFile = "git-status-report-$timestamp.csv"
        Export-ScanReport -FilePath $reportFile
        Write-Host ""
        Read-Host "  Press Enter to close"
    }
}
