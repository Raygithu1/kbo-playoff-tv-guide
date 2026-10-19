[CmdletBinding()]
param(
    [string]$RepoPath = 'C:\Code\KBO',
    [string]$Model = 'opencode/big-pickle',
    [switch]$DryRun
)

$logDir = Join-Path $RepoPath 'scripts\logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logFile = Join-Path $logDir ("update-" + (Get-Date -Format 'yyyy-MM-dd_HHmm') + ".log")

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

Write-Log "Daily KBO site update started (DryRun=$DryRun)"

Set-Location -LiteralPath $RepoPath

Get-ChildItem -Path $logDir -Filter 'update-*.log' |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-60) } |
    Remove-Item -Force -ErrorAction SilentlyContinue

$prompt = @'
Update the KBO playoff TV guide in index.html for today (Korea time).
1. Verify the latest 2026 KBO postseason results and schedule from reliable sources.
2. Update the hero game, the countdown target, and the next upcoming game.
3. Refresh the "KBO on Korean TV - Next 7 Days" EPG table using the official KBS N SPORTS EPG (kbsn.co.kr/schedule/?bdcst_code=sports&wdate=YYYYMMDD) plus the published terrestrial live rotation (KBS2 / MBC / SBS).
4. Refresh every "checked/updated" date and the footer.
5. Keep the existing English copy, layout and CSS. Never invent results or replay times - if something cannot be verified, mark it TBD.
Then stage, commit and push to main so GitHub Pages rebuilds.
'@

$opencode = Join-Path $env:APPDATA 'npm\opencode.cmd'
if (-not (Test-Path -LiteralPath $opencode)) { $opencode = 'opencode' }

if ($DryRun) {
    Write-Log "DryRun: would run '$opencode run --auto --model $Model --dir $RepoPath'"
} else {
    try {
        $output = & $opencode run --auto --model $Model --dir $RepoPath $prompt 2>&1 | Out-String
        Add-Content -Path $logFile -Value $output -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($output)) { Write-Log 'WARNING: opencode produced no output' }
    } catch {
        Write-Log ("ERROR: opencode run failed - " + $_.Exception.Message)
    }
}

$status = git status --porcelain
if (-not [string]::IsNullOrWhiteSpace($status)) {
    Write-Log ("Uncommitted changes remain, committing: " + ($status -replace "`r`n", '; '))
    git add -A | Out-Null
    git commit -m ("Daily guide update " + (Get-Date -Format 'yyyy-MM-dd')) | Out-Null
    git push origin main | Out-Null
}

Write-Log "Daily KBO site update finished"
