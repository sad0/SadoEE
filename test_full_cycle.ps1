# Release test: uninstall every SadoEE component of a test game, check nothing of ours is left in override, then
# rebuild and install the given list again. The game must be closed.
#   .\test_full_cycle.ps1 -Components "4 1 5 6 7 10 11 12 13 14 20 21 22 23 24 25 27 28 29 30 31 32 40"
param(
	[string]$Game = "E:\Enhanced Edition\Environnement de test\Baldur's Gate Enhanced Edition",
	[Parameter(Mandatory = $true)][string]$Components
)
$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Get-Process Baldur -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$Game*" }) { 'GAME RUNNING: close it first'; exit 1 }
$installed = Select-String -Path "$Game\WeiDU.log" -Pattern '^~SADOEE[\\/]SADOEE.TP2~ #\d+ #(\d+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }
"before: " + ($installed -join ' ')
if ($installed) {
	$wargs = "--language 0 --force-uninstall-list $($installed -join ' ') --no-exit-pause --noautoupdate --skip-at-view"
	Start-Process -FilePath "$Game\setup-SadoEE.exe" -ArgumentList $wargs -WorkingDirectory $Game -Wait -WindowStyle Hidden
}
"after uninstall: " + ((Select-String -Path "$Game\WeiDU.log" -Pattern '^~SADOEE' | Measure-Object).Count) + " SadoEE lines in WeiDU.log"
# our own resources (prefixes of SadoEE files); game files we patched are restored by WeiDU from its backup
$left = Get-ChildItem "$Game\override" | Where-Object { $_.Name -match '^(M_PS|M_SQ|PSX|PSTASH|SQ[A-Z]|PSS|PST|PSARROW|PSHELP|PSBUT|PSCONT|PSINV|PSPRC|PSBTACT|MWIT)' }
"leftovers: " + ($left.Name -join ' ')
& "$here\install_test.ps1" -Game $Game -Components $Components
