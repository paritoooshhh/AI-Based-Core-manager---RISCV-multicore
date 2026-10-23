$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$CpuRtl = Join-Path $ProjectRoot "rtl\14_Multicore-Zeta_corrected.v"
$TopRtl = Join-Path $PSScriptRoot "matrix_multicore_ml_top.v"
if (!(Test-Path $CpuRtl)) { throw "Original project RTL not found: $CpuRtl" }
iverilog -g2012 -s matrix_multicore_ml_top -o .\matrix_demo.vvp $CpuRtl $TopRtl
if ($LASTEXITCODE -ne 0) { throw "iverilog compile failed" }
Write-Host "Compile PASS using original project RTL: $CpuRtl"
python .\predict_and_run.py 4
if ($LASTEXITCODE -ne 0) { throw "Demo run failed" }
