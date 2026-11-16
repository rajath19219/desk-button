# One-time PC setup for the desk button bridge:
#   1. makes a small Python environment in desk-button\.venv with pyserial
#   2. adds a "Desk Button Bridge" shortcut to your Startup folder (starts hidden at login)
#   3. starts the bridge now
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$venv = Join-Path $here ".venv"

if (-not (Test-Path "$venv\Scripts\pythonw.exe")) {
    Write-Host "Creating Python environment..."
    py -3.12 -m venv $venv
}
& "$venv\Scripts\python.exe" -m pip install --quiet --disable-pip-version-check -r (Join-Path $here "requirements.txt")

$startup = [Environment]::GetFolderPath("Startup")
$lnk = Join-Path $startup "Desk Button Bridge.lnk"
$shell = New-Object -ComObject WScript.Shell
$s = $shell.CreateShortcut($lnk)
$s.TargetPath = "$venv\Scripts\pythonw.exe"
$s.Arguments = "`"$(Join-Path $here 'bridge.py')`""
$s.WorkingDirectory = $here
$s.Description = "Connects the USB desk button to Simple Timer"
$s.Save()
Write-Host "Startup shortcut: $lnk"

Start-Process "$venv\Scripts\pythonw.exe" -ArgumentList "`"$(Join-Path $here 'bridge.py')`"" -WorkingDirectory $here
Write-Host "Bridge running. Plug in the button; its ring turns dim green (ready) within a few seconds."
