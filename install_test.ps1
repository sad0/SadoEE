# Rebuilds SadoEE (build_sadoee.py) and installs components on a test game.
#   .\install_test.ps1 -Components "40"            (default game: the test BGEE 2.7.3)
#   .\install_test.ps1 -Game "<game folder>" -Components "0 1 10 11"
# The game must be closed. Language 0 = English.
param(
	[string]$Game = "E:\Enhanced Edition\Environnement de test\Baldur's Gate Enhanced Edition",
	[Parameter(Mandatory = $true)][string]$Components,
	[int]$Language = 0
)
$ErrorActionPreference = 'Continue'   # WeiDU writes its end notice to stderr: never stop on it
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Get-Process Baldur -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$Game*" }) { 'GAME RUNNING: close it first'; exit 1 }
python "$here\build_sadoee.py" | Out-Host
$dev = (Select-String -Path "$here\build_sadoee.py" -Pattern '^GAME = r"([^"]+)"').Matches[0].Groups[1].Value
if ($dev -ne $Game) {
	robocopy "$dev\SadoEE" "$Game\SadoEE" /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
	Copy-Item "$dev\setup-SadoEE.exe" "$Game\setup-SadoEE.exe" -Force
}
$wargs = "--language $Language --force-install-list $Components --no-exit-pause --noautoupdate --skip-at-view"
Start-Process -FilePath "$Game\setup-SadoEE.exe" -ArgumentList $wargs -WorkingDirectory $Game -Wait -WindowStyle Hidden
"errors: " + (Select-String -Path "$Game\SETUP-SADOEE.DEBUG" -Pattern 'NOT INSTALLED|^ERROR').Count
"installed: " + ((Select-String -Path "$Game\WeiDU.log" -Pattern '^~SADOEE[\\/]SADOEE.TP2~ #\d+ #(\d+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }) -join ' ')
