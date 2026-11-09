<#
  ALB FOREX - EMA 8/14 Scalper : automatic Strategy Tester runner (Windows, MT5)

  What it does (no MT5 clicks needed):
    1. Finds your MetaTrader 5 installation and data folder.
    2. Copies the EA (.ex5/.mq5) and the presets into MT5.
    3. Runs the Strategy Tester once per variant (A, B, C, D), unattended.
    4. Collects every report, journal and log into ONE zip on your Desktop.

  Requirements:
    - MetaTrader 5 logged in to your broker account at least once with "Save password".
    - MetaTrader 5 must be CLOSED while the script runs (the script waits for you to close it).

  Usage: double-click RUN_BACKTESTS.bat (in the project folder), or:
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_backtests.ps1 [-Symbol XAUUSD.std] [-From 2026.04.01] [-To 2026.08.31]
                [-Login 2100013908 -Server LirunexLimited-Demo]
  If a run fails, the script prints the reason from the MT5 log, stops, and (if the cause is the
  account) offers to retry with an account number you type. The password must be saved in MT5.
#>
param(
    [string]   $Symbol   = "XAUUSD.std",
    [string]   $From     = "2026.04.01",
    [string]   $To       = "2026.08.31",
    [int]      $Deposit  = 10000,
    [int]      $Leverage = 100,
    [string[]] $Variants = @("A_Baseline", "B_NextCandle", "C_FlatFilter", "D_BreakEven"),
    [string]   $AppData  = $env:APPDATA,
    [string]   $OutRoot  = [Environment]::GetFolderPath("Desktop"),
    [string]   $Login    = "",
    [string]   $Server   = "",
    [int]      $Install  = 0,
    [switch]   $DryRun
)

$ErrorActionPreference = "Stop"
# "-Variants A_Baseline,B_NextCandle" arrives as one string with -File: split it
$Variants = @($Variants | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$EaName  = "ALB_FOREX_EMA_SCALPER_EA"
$Here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$Project = Split-Path -Parent $Here

function Say([string]$msg, [string]$color = "Gray") { Write-Host $msg -ForegroundColor $color }
function Fail([string]$msg) { Say ""; Say "ERROR: $msg" "Red"; exit 1 }

# Last relevant lines of the MT5 terminal log (UTF-16) written after $since.
function Get-Mt5Reason([string]$dataDir, [datetime]$since) {
    $logDir = Join-Path $dataDir "logs"
    if (-not (Test-Path $logDir)) { return "" }
    $f = Get-ChildItem -Path $logDir -Filter "*.log" -File -ErrorAction SilentlyContinue |
         Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $f -or $f.LastWriteTime -lt $since.AddSeconds(-5)) { return "MT5 wrote nothing to its log (was MT5 still open?)" }
    $lines = @(Get-Content -Path $f.FullName -Encoding Unicode -ErrorAction SilentlyContinue | Select-Object -Last 60)
    $hits = @($lines | Where-Object { $_ -match '(?i)tester|not started|account|symbol|config|cannot|failed|error|authoriz' } |
              Where-Object { $_ -notmatch 'MQL5\.community' } | Select-Object -Last 3)
    $msgs = @($hits | ForEach-Object { $p = $_ -split "`t"; if ($p.Count -ge 2) { ($p[-2] + ": " + $p[-1]).Trim() } else { $_.Trim() } })
    return ($msgs -join " | ")
}

Say "=== ALB FOREX EMA Scalper - automatic backtests ===" "Cyan"
Say ("Symbol {0} | {1} -> {2} | deposit {3} USD | variants: {4}" -f $Symbol, $From, $To, $Deposit, ($Variants -join ", "))

# --- 1. project files ---------------------------------------------------------
$ex5 = Join-Path $Project "$EaName.ex5"
$mq5 = Join-Path $Project "$EaName.mq5"
$presetDir = Join-Path $Project "presets"
foreach ($f in @($ex5, $mq5, $presetDir)) { if (-not (Test-Path $f)) { Fail "missing project file: $f" } }

# --- 2. find MT5: data folders that contain origin.txt -> install folder ------
$termBase = Join-Path $AppData "MetaQuotes\Terminal"
if (-not (Test-Path $termBase)) { Fail "no MetaTrader data found in $termBase. Start MT5 once, then retry." }

$found = @()
foreach ($dir in Get-ChildItem -Path $termBase -Directory) {
    $originFile = Join-Path $dir.FullName "origin.txt"
    if (-not (Test-Path $originFile)) { continue }
    $origin = (Get-Content -Path $originFile -Raw).Trim()
    $exe = Join-Path $origin "terminal64.exe"
    if (-not (Test-Path $exe)) { continue }
    $logs = Join-Path $dir.FullName "logs"
    $last = if (Test-Path $logs) { (Get-Item $logs).LastWriteTime } else { $dir.LastWriteTime }
    $found += [pscustomobject]@{ Data = $dir.FullName; Exe = $exe; Origin = $origin; LastUsed = $last }
}
if ($found.Count -eq 0) { Fail "no MetaTrader 5 (terminal64.exe) found. Is MT5 installed?" }

$found = @($found | Sort-Object LastUsed -Descending)
Say ""
Say "MetaTrader 5 installations found:" "Cyan"
for ($i = 0; $i -lt $found.Count; $i++) { Say ("  [{0}] {1}   (last used {2})" -f ($i + 1), $found[$i].Origin, $found[$i].LastUsed) }
$pick = $found[0]
if ($Install -ge 1 -and $Install -le $found.Count) { $pick = $found[$Install - 1] }
elseif ($found.Count -gt 1 -and -not $DryRun) {
    $ans = Read-Host ("Which one has your broker account? Enter number (default 1)")
    if ($ans -match '^\d+$' -and [int]$ans -ge 1 -and [int]$ans -le $found.Count) { $pick = $found[[int]$ans - 1] }
}
$data = $pick.Data
$exe  = $pick.Exe
Say ("Using: {0}" -f $pick.Origin) "Green"

# --- 3. MT5 must be closed ----------------------------------------------------
function Get-Mt5Running {
    @(Get-Process -Name "terminal64" -ErrorAction SilentlyContinue | Where-Object {
        try { $_.Path -eq $exe } catch { $true }
    })
}
if (-not $DryRun) {
    while ((Get-Mt5Running).Count -gt 0) {
        Say ""
        Say "MetaTrader 5 is open. Please CLOSE it (File -> Exit), then press Enter here." "Yellow"
        [void](Read-Host)
    }
}

# --- 4. install EA + presets --------------------------------------------------
$eaDir     = Join-Path $data "MQL5\Experts\$EaName"
$testerDir = Join-Path $data "MQL5\Profiles\Tester"
$commonDir = Join-Path $termBase "Common\Files"
New-Item -ItemType Directory -Force -Path $eaDir, $testerDir | Out-Null
Copy-Item -Force $ex5, $mq5 -Destination $eaDir
Copy-Item -Force (Join-Path $presetDir "*.set") -Destination $testerDir
Say "EA and presets installed into MT5." "Green"

# --- 5. output folder ---------------------------------------------------------
$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$out = Join-Path $OutRoot ("ALBFX_Backtests_{0}" -f $stamp)
New-Item -ItemType Directory -Force -Path $out | Out-Null

$safeSym = ($Symbol -replace '[\\/:*?"<>|]', '_')
$summary = @()

# --- 6. run each variant ------------------------------------------------------
$n = 0
foreach ($v in $Variants) {
    $n++
    $preset = "Backtest_$v.set"
    if (-not (Test-Path (Join-Path $testerDir $preset))) { Say "skip $v : preset $preset not found" "Yellow"; continue }

    $reportName = "ALBFX_$v"
    $ini = Join-Path $data ("albfx_tester_{0}.ini" -f $v)
    $common = @()
    if ($Login) {
        $common += "[Common]"
        $common += "Login=$Login"
        if ($Server) { $common += "Server=$Server" }
    }
    $iniText = ($common + @(
        "[Tester]",
        "Expert=$EaName\$EaName.ex5",
        "ExpertParameters=$preset",
        "Symbol=$Symbol",
        "Period=M1",
        "Model=4",
        "ExecutionMode=0",
        "Optimization=0",
        "FromDate=$From",
        "ToDate=$To",
        "ForwardMode=0",
        "Deposit=$Deposit",
        "Currency=USD",
        "Leverage=$Leverage",
        "Visual=0",
        "UseLocal=1",
        "UseRemote=0",
        "UseCloud=0",
        "Report=$reportName",
        "ReplaceReport=1",
        "ShutdownTerminal=1"
    )) -join "`r`n"
    Set-Content -Path $ini -Value $iniText -Encoding ASCII

    # remove stale outputs so we never collect results from an older run
    Get-ChildItem -Path $data -Filter "$reportName*" -File -ErrorAction SilentlyContinue | Remove-Item -Force
    if (Test-Path $commonDir) {
        Get-ChildItem -Path $commonDir -Filter "ALBFX_EMA_SCALPER_Report_${safeSym}_*.txt" -File -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    Say ""
    Say ("[{0}/{1}] Running variant {2} ... (can take 10-40 minutes; first run also downloads tick data)" -f $n, $Variants.Count, $v) "Cyan"
    $t0 = Get-Date
    if ($DryRun) {
        Say "  (dry run) would start: `"$exe`" /config:`"$ini`""
    } else {
        $p = Start-Process -FilePath $exe -ArgumentList "/config:`"$ini`"" -PassThru
        $p.WaitForExit()   # waits for MT5 only (tester agents may outlive it)
    }
    $mins = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)

    $vOut = Join-Path $out $v
    New-Item -ItemType Directory -Force -Path $vOut | Out-Null
    Copy-Item -Force $ini -Destination $vOut
    Copy-Item -Force (Join-Path $testerDir $preset) -Destination $vOut
    $html = @(Get-ChildItem -Path $data -Filter "$reportName*" -File -ErrorAction SilentlyContinue)
    foreach ($f in $html) { Copy-Item -Force $f.FullName -Destination $vOut }
    $ext = @()
    if (Test-Path $commonDir) {
        $ext = @(Get-ChildItem -Path $commonDir -Filter "ALBFX_EMA_SCALPER_*${safeSym}*" -File -ErrorAction SilentlyContinue |
                 Where-Object { $_.LastWriteTime -ge $t0 })
        foreach ($f in $ext) { Copy-Item -Force $f.FullName -Destination $vOut }
    }
    $tlogDir = Join-Path $data "Tester\logs"
    if (Test-Path $tlogDir) {
        Get-ChildItem -Path $tlogDir -Filter "*.log" -File | Sort-Object LastWriteTime -Descending |
            Select-Object -First 1 | ForEach-Object { Copy-Item -Force $_.FullName -Destination (Join-Path $vOut "tester_journal.log") }
    }
    $agentRoot = Join-Path $data "Tester"
    if (Test-Path $agentRoot) {
        Get-ChildItem -Path $agentRoot -Filter "*.log" -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -like "*Agent-*" -and $_.LastWriteTime -ge $t0 } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1 |
            ForEach-Object { Copy-Item -Force $_.FullName -Destination (Join-Path $vOut "agent_log_EA_output.log") }
    }
    $tlog = Join-Path $data "logs"
    if (Test-Path $tlog) {
        Get-ChildItem -Path $tlog -Filter "*.log" -File | Sort-Object LastWriteTime -Descending |
            Select-Object -First 1 | ForEach-Object { Copy-Item -Force $_.FullName -Destination (Join-Path $vOut "terminal_journal.log") }
    }

    $ok = ($html.Count -gt 0) -or ($ext.Count -gt 0)
    $state = if ($DryRun) { "DRY RUN" } elseif ($ok) { "OK" } else { "NO REPORT" }
    $summary += ("{0,-14} {1,-10} {2,6} min" -f $v, $state, $mins)
    if ($ok -or $DryRun) {
        if ($ok) { Say ("  done in {0} min" -f $mins) "Green" }
        continue
    }

    # ---- failure: show MT5's own reason, offer one retry with an explicit account, else stop ----
    $reason = Get-Mt5Reason $data $t0
    if (-not $reason) { $reason = "no reason found in the MT5 log" }
    $summary += ("    reason: {0}" -f $reason)
    Say "  NO REPORT. MT5 says: $reason" "Yellow"
    if (-not $Login -and $reason -match '(?i)account|authoriz|symbol') {
        Say "  MT5 did not use your broker account. Type your account number to retry now" "Yellow"
        Say "  (the password must be saved in MT5), or just press Enter to stop:" "Yellow"
        $typed = (Read-Host "  Account number").Trim()
        if ($typed) {
            $Login = $typed
            $srv = (Read-Host "  Server (Enter = LirunexLimited-Demo)").Trim()
            $Server = if ($srv) { $srv } else { "LirunexLimited-Demo" }
            $summary += ("    retry with Login={0} Server={1}" -f $Login, $Server)
            $Variants = @($v) + @($Variants | Select-Object -Skip $n)
            $n = 0
            Say "  Retrying all remaining variants with account $Login on $Server ..." "Cyan"
            # restart the loop over the remaining variants
            & $PSCommandPath -Symbol $Symbol -From $From -To $To -Deposit $Deposit -Leverage $Leverage `
                -Variants ($Variants -join ",") -AppData $AppData -OutRoot $OutRoot -Login $Login -Server $Server `
                -Install ([array]::IndexOf($found, $pick) + 1)
            exit $LASTEXITCODE
        }
    }
    Say "  Stopping: the remaining variants would fail the same way." "Yellow"
    Say "  Fix: open MT5, log in to your broker account with 'Save password' ticked, close MT5, run again." "Yellow"
    break
}

# --- 7. zip -------------------------------------------------------------------
Set-Content -Path (Join-Path $out "SUMMARY.txt") -Value (@(
    "ALB FOREX EMA Scalper - automatic backtests",
    "Created : $(Get-Date -Format 'yyyy-MM-dd HH:mm')",
    "Terminal: $($pick.Origin)",
    "Symbol  : $Symbol  M1, real ticks, $From -> $To, deposit $Deposit USD, leverage 1:$Leverage",
    "",
    "Variant        Result     Time"
) + $summary) -Encoding UTF8

$zip = "$out.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path (Join-Path $out "*") -DestinationPath $zip
Say ""
Say "=========================================================" "Cyan"
$summary | ForEach-Object { Say "  $_" }
Say ""
Say "FINISHED. Send this ONE file to Claude:" "Green"
Say "  $zip" "Green"
Say "=========================================================" "Cyan"
if (-not $DryRun) {
    try { Start-Process explorer.exe -ArgumentList "/select,`"$zip`"" } catch { }
}
