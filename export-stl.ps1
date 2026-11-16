# Exports every printed part of enclosure.scad to stl\<part>.stl and renders preview PNGs.
# Needs OpenSCAD installed (https://openscad.org/downloads.html, or: winget install OpenSCAD.OpenSCAD)
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$scad = Join-Path $here "enclosure.scad"
$exe = @("C:\Program Files\OpenSCAD\openscad.com", "C:\Program Files\OpenSCAD\openscad.exe",
         "C:\Program Files (x86)\OpenSCAD\openscad.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $exe) { $exe = (Get-Command openscad -ErrorAction SilentlyContinue).Source }
if (-not $exe) { throw "OpenSCAD not found. Install it first: winget install OpenSCAD.OpenSCAD" }

New-Item -ItemType Directory -Force (Join-Path $here "stl"), (Join-Path $here "preview") | Out-Null
Remove-Item (Join-Path $here "stl\*.stl") -ErrorAction SilentlyContinue
foreach ($p in "shell", "bezel", "bar", "back", "clamp") {
    Write-Host "Exporting $p..."
    & $exe -o (Join-Path $here "stl\$p.stl") -D ('part=\"' + $p + '\"') $scad
}
foreach ($v in @(@{n="assembly"; c="0,0,26,62,0,332,360"}, @{n="exploded"; c="0,0,26,62,0,332,440"},
                 @{n="print_all"; c="10,-30,0,35,0,0,620"})) {
    Write-Host "Rendering preview $($v.n)..."
    & $exe -o (Join-Path $here "preview\$($v.n).png") -D ('part=\"' + $v.n + '\"') --camera=$($v.c) `
        --imgsize=1600,1100 --colorscheme=Tomorrow $scad
}
Write-Host "Done. STLs in stl\, pictures in preview\"
