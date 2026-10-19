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
    Write-Host $line
}

Write-Log "Daily KBO site update started (DryRun=$DryRun)"

Set-Location -LiteralPath $RepoPath

Get-ChildItem -Path $logDir -Filter 'update-*.log' |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-60) } |
    Remove-Item -Force -ErrorAction SilentlyContinue

$prompt = @'
Refresh the KBO playoff TV guide in index.html for today (Korea time).

HARD RULES
- The page must keep exactly 19 game cards. Never add, delete or duplicate a card. Verify with: (Select-String -Path index.html -Pattern 'class="game-card').Count  -> must print 19.
- Do not invent scores, replay times or channel assignments. Every fact must come from a fetched source (koreabaseball.com, Korean news wires, Wikipedia ko, or the official KBS N EPG).
- If a result or time cannot be verified, leave it as "VS" / TBD instead of guessing.

STEPS
1. Verify last night's results and the next game from at least two sources.
2. Update the hero game, the countdown target (Date.parse in the script block) and mark finished games as completed with their final score.
3. Refresh the "KBO on Korean TV - Next 7 Days" EPG table from the official KBS N SPORTS EPG (https://www.kbsn.co.kr/schedule/?bdcst_code=sports&wdate=YYYYMMDD) plus the published terrestrial live rotation (KBS2 / SBS / MBC). Keep the same row CSS classes (epg-row / epg-live / epg-replay / epg-show / epg-hl, epg-date, epg-badge).
4. Refresh every "checked Oct. NN" pill and the "Updated" footer date.
5. Keep the existing English copy, layout and CSS.

FINISH
- Run the card-count check and confirm it prints 19.
- Then stage, commit with message "Daily guide update YYYY-MM-DD" and push to main.
'@

$opencode = Join-Path $env:APPDATA 'npm\opencode.cmd'
if (-not (Test-Path -LiteralPath $opencode)) { $opencode = 'opencode' }

if ($DryRun) {
    Write-Log "DryRun: would run '$opencode run --auto --model $Model --dir $RepoPath'"
} else {
    try {
        & $opencode run --auto --model $Model --dir $RepoPath $prompt 2>&1 |
            Tee-Object -FilePath $logFile -Append | Out-Null
        Write-Log ("opencode exit code: " + $LASTEXITCODE)
    } catch {
        Write-Log ("ERROR: opencode run failed - " + $_.Exception.Message)
    }
}

$index = Join-Path $RepoPath 'index.html'
$cards = (Select-String -Path $index -Pattern 'class="game-card').Count
$days = (Select-String -Path $index -Pattern 'class="epg-date"').Count
$closed = (Select-String -Path $index -Pattern '</html>').Count

if ($cards -ne 19 -or $days -lt 7 -or $closed -lt 1) {
    Write-Log "VALIDATION FAILED (cards=$cards days=$days html=$closed) - reverting index.html"
    git checkout -- index.html | Out-Null
} else {
    Write-Log "Validation passed (cards=$cards days=$days)"
    $status = git status --porcelain
    if (-not [string]::IsNullOrWhiteSpace($status)) {
        Write-Log ("Uncommitted changes remain, committing: " + ($status -replace "`r`n", '; '))
        git add -A | Out-Null
        git commit -m ("Daily guide update " + (Get-Date -Format 'yyyy-MM-dd')) | Out-Null
        git push origin main 2>&1 | Out-Null
    }
}

Write-Log "Daily KBO site update finished"
