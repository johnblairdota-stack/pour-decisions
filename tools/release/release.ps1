<#
Pour Decisions release job: ships main to John's play folder and his tablet in one go.
Run on John's PC by the ONE release thread, once or twice a day or when John says "ship it":

  powershell -ExecutionPolicy Bypass -File C:\Users\John\Documents\PourDecisions-tools\release.ps1
  (add -DryRun to see what it would do, -NoTablet to skip the tablet, -NoTag to skip the git tag)

Steps (stops at the first problem; nothing is overwritten before the backup exists):
  1. Refuse to run while Godot is open (it would hold files and skip re-imports).
  2. Fresh shallow clone of main into a temp folder. Release name = r<yyyyMMdd-HHmm>.
  3. Back up the play folder to Documents\PourDecisions_backup_<release> (without .godot).
  4. Copy main over the play folder (no deletes: John's own files stay; .import files only if new).
  5. Clear stale .godot\imported entries whose source changed (the "old picture" bug).
  6. Headless import, so the cache the tablet gets is current.
  7. Tablet sync with the existing sync_to_tablet.ps1 (tablet unlocked, File transfer allowed).
  8. Tag the release on GitHub and append it, with the changes since the last release, to releases.log.
#>
param(
  [string]$Play   = "$env:USERPROFILE\Documents\PourDecisions",
  [string]$Tools  = "$env:USERPROFILE\Documents\PourDecisions-tools",
  [string]$Repo   = "https://github.com/johnblairdota-stack/pour-decisions.git",
  [string]$Godot  = "",
  [switch]$DryRun,
  [switch]$NoTablet,
  [switch]$NoTag
)
$ErrorActionPreference = "Stop"
function Say($m) { Write-Host "[release] $m" }
function Fail($m) { Write-Host "[release] STOPPED: $m" -ForegroundColor Red; exit 1 }

# 1. Godot must be closed
$open = Get-Process | Where-Object { $_.ProcessName -like "Godot*" }
if ($open) { Fail "Godot is open (PID $($open.Id -join ', ')). Ask John to close it; never kill it." }

if (-not $Godot) {
  $cands = @("$Tools", "$env:USERPROFILE\Desktop", "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Documents", "C:\Program Files\Godot", "$env:LOCALAPPDATA\Programs")
  $Godot = Get-ChildItem -Path $cands -Recurse -Depth 2 -Filter "Godot_v4.7*_win64_console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
  if (-not $Godot) { $Godot = Get-ChildItem -Path $cands -Recurse -Depth 2 -Filter "Godot_v4.7*win64.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName }
  if (-not $Godot) { Fail "Couldn't find Godot 4.7. Pass -Godot <path to the .exe>." }
}
if (-not (Test-Path $Play)) { Fail "No play folder at $Play" }
Say "using Godot at $Godot"
$log = Join-Path $Tools "releases.log"

# 2. Fresh copy of main
$rel = "r" + (Get-Date -Format "yyyyMMdd-HHmm")
$tmp = Join-Path $env:TEMP "pd_release_$rel"
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
Say "release ${rel}: cloning main"
git clone --quiet --depth 50 --branch main $Repo $tmp
if ($LASTEXITCODE -ne 0) { Fail "git clone failed" }
$sha = (git -C $tmp rev-parse --short HEAD).Trim()
$lastSha = ""
if (Test-Path $log) {
  $m = Select-String -Path $log -Pattern "^r\S+ main (\w+)" | Select-Object -Last 1
  if ($m) { $lastSha = $m.Matches[0].Groups[1].Value }
}
if ($lastSha -eq $sha) { Say "main ($sha) is already the shipped release; nothing to do."; Remove-Item -Recurse -Force $tmp; exit 0 }
$changes = if ($lastSha) { git -C $tmp log --merges --format="  %s" "$lastSha..HEAD" 2>$null } else { git -C $tmp log --merges -10 --format="  %s" }
Say "main is $sha. Changes since the last release:"; $changes | ForEach-Object { Write-Host $_ }
if ($DryRun) { Say "dry run: stopping here."; Remove-Item -Recurse -Force $tmp; exit 0 }

# 3. Backup (without the regenerable .godot cache)
$bak = Join-Path (Split-Path $Play) ("PourDecisions_backup_" + $rel)
Say "backing up to $bak"
robocopy $Play $bak /E /XD .godot /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { Fail "backup failed (robocopy $LASTEXITCODE); play folder untouched" }

# 4. Copy main over the play folder (never deletes anything of John's)
Say "updating the play folder"
robocopy $tmp $Play /E /XD .git .github .godot /XF *.import /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { Fail "copy failed (robocopy $LASTEXITCODE); restore from $bak" }
robocopy $tmp $Play *.import /S /XD .git .godot /XC /XN /XO /NFL /NDL /NJH /NJS /NP | Out-Null   # (new .import files only)

# 5. Stale import cache: drop cached entries whose source MD5 changed
$cleared = 0
Get-ChildItem -Path $Play -Recurse -Filter *.import -File | Where-Object { $_.FullName -notlike "*\.godot\*" } | ForEach-Object {
  $src = $_.FullName.Substring(0, $_.FullName.Length - 7)
  if (-not (Test-Path $src)) { return }
  $p = Select-String -Path $_.FullName -Pattern '^path(\.\w+)?="res://\.godot/imported/([^"]+)\.\w+"' | Select-Object -First 1
  if (-not $p) { return }
  $stem = $p.Matches[0].Groups[2].Value
  $md5file = Join-Path $Play ".godot\imported\$stem.md5"
  if (-not (Test-Path $md5file)) { return }
  $want = (Select-String -Path $md5file -Pattern '^source_md5="(\w+)"' | Select-Object -First 1)
  if (-not $want) { return }
  $have = (Get-FileHash -Algorithm MD5 $src).Hash.ToLower()
  if ($have -ne $want.Matches[0].Groups[1].Value.ToLower()) {
    Get-ChildItem -Path (Join-Path $Play ".godot\imported") -Filter "$stem.*" | Remove-Item -Force
    $cleared++
  }
}
Say "cleared $cleared stale cache entr$(if ($cleared -eq 1) {'y'} else {'ies'})"

# 6. Headless import (started and waited on by PID; never kills anything else)
Say "importing with $Godot"
$pr = Start-Process -FilePath $Godot -ArgumentList "--headless","--path","`"$Play`"","--import" -PassThru -WindowStyle Hidden
if (-not $pr.WaitForExit(900000)) { Stop-Process -Id $pr.Id -Force; Fail "import took over 15 min (stopped PID $($pr.Id) only)" }

# 7. Tablet
if (-not $NoTablet) {
  $sync = Join-Path $Tools "sync_to_tablet.ps1"
  if (-not (Test-Path $sync)) { Fail "no $sync" }
  Say "syncing the tablet (it must be unlocked with File transfer allowed)"
  powershell -ExecutionPolicy Bypass -File $sync
  if ($LASTEXITCODE -ne 0) { Fail "tablet sync failed (play folder is updated; re-run with the tablet unlocked)" }
}

# 8. Tag and log
if (-not $NoTag) {
  git -C $tmp tag $rel 2>$null
  git -C $tmp push --quiet origin $rel 2>$null
  if ($LASTEXITCODE -ne 0) { Say "(couldn't push tag $rel; logged locally anyway)" }
}
Add-Content -Path $log -Value ("$rel main $sha " + (Get-Date -Format "yyyy-MM-dd HH:mm") + " backup " + (Split-Path $bak -Leaf))
$changes | ForEach-Object { Add-Content -Path $log -Value $_ }
Remove-Item -Recurse -Force $tmp
Say "DONE: $rel (main $sha) is on the PC$(if (-not $NoTablet) {' and the tablet'})."
