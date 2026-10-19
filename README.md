# KBO Playoff TV Guide

A simple guide to KBO postseason matchups and Korean broadcast listings.

The page is published with GitHub Pages from the repository root. Edit `index.html` to update teams, schedules, channel numbers, or broadcast information.

## Daily auto-update

A Windows Scheduled Task refreshes the page every day at **8:00 AM local time** (US Mountain, UTC-7):

- Task: `KBO-Site-Daily-Update` — view with `Get-ScheduledTask -TaskName 'KBO-Site-Daily-Update'`
- Script: `scripts/update-site.ps1` — runs `opencode run --auto` against this repo, then validates and pushes
- Manual trigger: `Start-ScheduledTask -TaskName 'KBO-Site-Daily-Update'`
- Logs: `scripts/logs/update-YYYY-MM-DD_HHmm.log` (kept 60 days, not committed)
- Dry run (no agent, no commit): `powershell -File scripts\update-site.ps1 -DryRun`

Safety checks in the script: the page must keep exactly 19 game cards, at least 7 EPG day rows, and a closing `</html>` — anything else reverts `index.html` to the last commit instead of pushing a broken page.

To change the time: `Set-ScheduledTask -TaskName 'KBO-Site-Daily-Update' -Trigger (New-ScheduledTaskTrigger -Daily -At 7:00am)`
