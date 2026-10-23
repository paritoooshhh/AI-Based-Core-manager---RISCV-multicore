$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
New-Item -ItemType Directory -Force .\build | Out-Null
iverilog -g2012 -s matrix_core_demo -o .\matrix_demo.vvp .\matrix_core_demo.v
if ($LASTEXITCODE -ne 0) { throw "iverilog compilation failed" }
Write-Host "Compile PASS"
python .\predict_and_run.py 4
if ($LASTEXITCODE -ne 0) { throw "Demo run failed" }
