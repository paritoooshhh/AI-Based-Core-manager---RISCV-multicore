# run_all_testbenches.ps1
# Runs each Verilog testbench in the project's tb folder independently.
# It does not modify RTL, testbenches, datasets, or ML model files.

$ErrorActionPreference = "Continue"  # Native compiler diagnostics should be logged, not abort the whole run.

$Root = "C:\Users\parit\Desktop\AI Project\Designs\Final Folder"
$RtlDir = Join-Path $Root "rtl"
$TbDir = Join-Path $Root "tb"
$BuildDir = Join-Path $Root "build\all_testbench_runs"
$LogDir = Join-Path $BuildDir "logs"
$SimDir = Join-Path $BuildDir "simulations"

Set-Location $Root
New-Item -ItemType Directory -Force -Path $LogDir, $SimDir | Out-Null

foreach ($tool in @("iverilog", "vvp")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool was not found in PATH. Install Icarus Verilog and reopen VS Code."
    }
}
if (-not (Test-Path $RtlDir)) { throw "RTL directory not found: $RtlDir" }
if (-not (Test-Path $TbDir)) { throw "Testbench directory not found: $TbDir" }

# Gather RTL files, while preferring the known primary RTL files when present.
$AllRtlFiles = @(Get-ChildItem -Path $RtlDir -File -Include *.v,*.sv -Recurse |
    Where-Object { $_.Name -ne "14_Multicore-Zeta.v" } |
    Sort-Object FullName | ForEach-Object { $_.FullName })

# Use the corrected Zeta RTL as the primary design. The older 14_Multicore-Zeta.v
# is excluded from all automatic source lists because it declares a duplicate alu module.
$PrimaryRtl = @(
    (Join-Path $RtlDir "14_Multicore-Zeta_corrected.v"),
    (Join-Path $RtlDir "heavy_workload_rtl_addon.v")
) | Where-Object { Test-Path $_ }

if ($AllRtlFiles.Count -eq 0) { throw "No .v or .sv RTL files found in $RtlDir" }

# Discover all Verilog/SystemVerilog testbench files.
$TestFiles = @(Get-ChildItem -Path $TbDir -File -Include *.v,*.sv -Recurse |
    Sort-Object FullName)

if ($TestFiles.Count -eq 0) { throw "No .v or .sv testbench files found in $TbDir" }

$Results = [System.Collections.Generic.List[object]]::new()
$Index = 0

foreach ($tb in $TestFiles) {
    $Index++
    # Read safely: Get-Content can return $null for an empty/unreadable file.
    try {
        $tbText = Get-Content -LiteralPath $tb.FullName -Raw -ErrorAction Stop
    } catch {
        Write-Host "`n[SKIP] Could not read testbench: $($tb.FullName) -- $($_.Exception.Message)" -ForegroundColor Yellow
        $Results.Add([pscustomobject]@{
            Testbench = $tb.Name; TopModule = "(unreadable)"; Compile = "SKIP"; Simulation = "SKIP"; Result = "READ ERROR"
        })
        continue
    }

    if ([string]::IsNullOrWhiteSpace($tbText)) {
        Write-Host "`n[SKIP] Testbench file is empty: $($tb.FullName)" -ForegroundColor Yellow
        $Results.Add([pscustomobject]@{
            Testbench = $tb.Name; TopModule = "(empty)"; Compile = "SKIP"; Simulation = "SKIP"; Result = "EMPTY FILE"
        })
        continue
    }

    # Use the first module declared in this testbench as its simulation top.
    $moduleMatch = [regex]::Match([string]$tbText, '(?im)^\s*module\s+([A-Za-z_][A-Za-z0-9_$]*)')
    if (-not $moduleMatch.Success) {
        Write-Host "`n[SKIP] No module declaration found: $($tb.Name)" -ForegroundColor Yellow
        $Results.Add([pscustomobject]@{
            Testbench = $tb.Name; TopModule = "(not found)"; Compile = "SKIP"; Simulation = "SKIP"; Result = "NO MODULE"
        })
        continue
    }
    $top = $moduleMatch.Groups[1].Value
    $safeName = [IO.Path]::GetFileNameWithoutExtension($tb.Name) -replace '[^A-Za-z0-9_.-]', '_'
    $tag = "{0:D2}_{1}" -f $Index, $safeName
    $simFile = Join-Path $SimDir "$tag.vvp"
    $compileLog = Join-Path $LogDir "${tag}_compile.log"
    $runLog = Join-Path $LogDir "${tag}_run.log"

    Write-Host "`n==================================================" -ForegroundColor Cyan
    Write-Host "Testbench: $($tb.FullName)"
    Write-Host "Top module: $top"

    # Prefer a testbench-specific RTL source set. Compiling every RTL file together
    # can create duplicate module definitions (for example, multiple "alu" modules).
    $sourceSets = @()
    $tbNameLower = $tb.Name.ToLowerInvariant()

    if ($tbNameLower -eq "tb_integrated_multicore_combiner.v") {
        $needed = @(
            (Join-Path $RtlDir "14_Multicore-Zeta_corrected.v"),
            (Join-Path $RtlDir "heavy_workload_rtl_addon.v"),
            (Join-Path $RtlDir "result_combiner.v")
        )
        $sourceSets += ,@($needed | Where-Object { Test-Path $_ })
    } elseif ($tbNameLower -eq "tb_multicore_integrated_system.v") {
        $needed = @(
            (Join-Path $RtlDir "14_Multicore-Zeta_corrected.v"),
            (Join-Path $RtlDir "heavy_workload_rtl_addon.v"),
            (Join-Path $RtlDir "multicore_integrated_top.v")
        )
        $sourceSets += ,@($needed | Where-Object { Test-Path $_ })
    } elseif ($tbNameLower -match "heavy|workload|scheduler") {
        if ($PrimaryRtl.Count -gt 0) { $sourceSets += ,$PrimaryRtl }
        # Do not automatically compile every RTL variant: that can duplicate
        # module names. Missing dependencies are reported in the compile log.
    } else {
        if ($PrimaryRtl.Count -gt 0) { $sourceSets += ,$PrimaryRtl }
        # Use the primary design by default; avoid combining unrelated RTL variants.
    }

    $compiled = $false
    $compileStatus = "FAIL"
    $compileOutput = @()

    for ($attempt = 0; $attempt -lt $sourceSets.Count; $attempt++) {
        $sources = @($sourceSets[$attempt] | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique)
        if ($sources.Count -eq 0) { continue }

        $compileOutput = @(& iverilog -g2012 -s $top -o $simFile @sources $tb.FullName 2>&1)
        $exitCode = $LASTEXITCODE
        $compileOutput | Out-File -LiteralPath $compileLog -Encoding utf8
        if ($exitCode -eq 0) {
            $compiled = $true
            $compileStatus = "PASS"
            if ($attempt -gt 0) {
                Add-Content -LiteralPath $compileLog -Encoding utf8 -Value "`r`nNOTE: Compilation succeeded using source-set attempt $($attempt + 1)."
            }
            break
        }
    }

    if (-not $compiled) {
        Write-Host "[COMPILE FAIL] See $compileLog" -ForegroundColor Red
        $Results.Add([pscustomobject]@{
            Testbench = $tb.Name; TopModule = $top; Compile = "FAIL"; Simulation = "NOT RUN"; Result = "COMPILE FAIL"
        })
        continue
    }

    # Run from project root so relative files such as ml_prediction.mem resolve there.
    $runOutput = @(& vvp $simFile 2>&1)
    $runExitCode = $LASTEXITCODE
    $runOutput | Out-File -LiteralPath $runLog -Encoding utf8
    $logText = ($runOutput | ForEach-Object { "$_" }) -join "`n"

    $simStatus = if ($runExitCode -eq 0) { "PASS" } else { "FAIL" }
    if ($logText -match 'BENCHMARK_RESULT,PASS|RESULT:\s*PASS|PASS:\s*Complete multicore_system testbench|PASS:\s*ML-DRIVEN ADDITION TEST') {
        $resultStatus = "PASS"
    } elseif ($logText -match 'BENCHMARK_RESULT,FAIL|RESULT:\s*FAIL|FAIL:|FATAL:') {
        $resultStatus = "FAIL"
    } elseif ($runExitCode -ne 0) {
        $resultStatus = "FAIL"
    } else {
        $resultStatus = "CHECK LOG"
    }

    Write-Host "Compile: $compileStatus | Simulation exit: $simStatus | Detected result: $resultStatus"
    Write-Host "Run log: $runLog"
    $Results.Add([pscustomobject]@{
        Testbench = $tb.Name; TopModule = $top; Compile = $compileStatus; Simulation = $simStatus; Result = $resultStatus
    })
}

$summaryPath = Join-Path $BuildDir "summary.csv"
$Results | Export-Csv -LiteralPath $summaryPath -NoTypeInformation -Encoding utf8

Write-Host "`n================ FINAL SUMMARY ================" -ForegroundColor Cyan
$Results | Format-Table -AutoSize
Write-Host "Summary CSV: $summaryPath"
Write-Host "All logs:    $LogDir"
Write-Host "Simulations: $SimDir"
Write-Host "`nNote: 'CHECK LOG' means the simulation ran but did not print a recognized PASS/FAIL marker."
Write-Host "A test that requires ml_prediction.mem will fail if that input file is absent or invalid."
