# Makes the sounds in sound_list.json with ElevenLabs' sound effects API, on
# Windows with nothing to install (the same job as generate_sounds.py).
#
#   powershell -ExecutionPolicy Bypass -File tools\sounds\generate_sounds.ps1 [-Out C:\path\sound_staging] [-Again]
#
# The key comes from the ELEVENLABS_API_KEY user environment variable only and
# is never printed. Each sound lands in <Out>\<folder>\<name>.mp3; ones already
# made are skipped unless -Again.
param([string]$Out = "", [switch]$Again)

$key = $env:ELEVENLABS_API_KEY
if (-not $key) { $key = [Environment]::GetEnvironmentVariable('ELEVENLABS_API_KEY', 'User') }
if (-not $key) { Write-Error "Set ELEVENLABS_API_KEY first."; exit 1 }
$key = $key.Trim()
if (-not $Out) { $Out = Join-Path $PSScriptRoot "..\..\..\sound_staging" }
$list = (Get-Content (Join-Path $PSScriptRoot "sound_list.json") -Raw -Encoding UTF8 | ConvertFrom-Json).sounds

$made = 0; $skipped = 0; $failed = @()
foreach ($s in $list) {
    $dir = Join-Path $Out $s.folder
    $path = Join-Path $dir ($s.name + ".mp3")
    if ((Test-Path $path) -and -not $Again) { $skipped++; continue }
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $body = @{ text = $s.text; duration_seconds = $s.seconds; prompt_influence = 0.5 }
    if ($s.loop) { $body.loop = $true }
    $ok = $false
    for ($try = 0; $try -lt 3 -and -not $ok; $try++) {
        try {
            Invoke-WebRequest -Uri "https://api.elevenlabs.io/v1/sound-generation" -Method Post `
                -Headers @{ "xi-api-key" = $key; "Accept" = "audio/mpeg" } -ContentType "application/json; charset=utf-8" `
                -Body ([Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json))) -OutFile $path -UseBasicParsing -TimeoutSec 120
            $ok = $true
        } catch {
            $code = 0
            if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
            # (an older model may not take "loop": try again without it)
            if (($code -eq 400 -or $code -eq 422) -and $body.ContainsKey("loop")) { $body.Remove("loop"); continue }
            if ($code -eq 429) { Start-Sleep -Seconds (10 * ($try + 1)); continue }
            $failed += "$($s.folder)/$($s.name): HTTP $code $($_.Exception.Message)"
            Write-Host "FAILED $($s.folder)/$($s.name): HTTP $code"
            if (Test-Path $path) { Remove-Item $path }
            break
        }
    }
    if ($ok) {
        $made++
        Write-Host ("made {0}/{1} ({2} KB)" -f $s.folder, $s.name, [int]((Get-Item $path).Length / 1024))
        Start-Sleep -Milliseconds 500
    }
}
Write-Host ""
Write-Host ("{0} made, {1} already there, {2} failed -> {3}" -f $made, $skipped, $failed.Count, (Resolve-Path $Out))
if ($failed.Count -gt 0) { $failed | ForEach-Object { Write-Host $_ }; exit 1 }
