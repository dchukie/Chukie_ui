$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$ver = "0.1.0"
$stamp = Get-Date -Format "yyyy-MM-dd"
$stage = Join-Path $env:TEMP ("ChukieUi_pkg_" + [guid]::NewGuid().ToString("N"))
$pkg = Join-Path $stage "Chukie_Ui"
New-Item -ItemType Directory -Path $pkg -Force | Out-Null
$destDir = $PSScriptRoot
foreach ($f in @(
    "Chukie_Ui.toc",
    "README.md",
    ".gitignore",
    "Core.lua",
    "Profiles.lua",
    "MinimapPosition.lua",
    "MinimapBar.lua",
    "ConfigPanel.lua"
  )) {
  $srcF = Join-Path $root $f
  if (Test-Path $srcF) {
    Copy-Item $srcF $pkg
  }
}
$tools = Join-Path $root "tools"
if (Test-Path $tools) {
  Copy-Item $tools $pkg -Recurse
}
$docs = Join-Path $root "docs"
if (Test-Path $docs) {
  Copy-Item $docs $pkg -Recurse
}
$media = Join-Path $root "Media"
if (Test-Path $media) {
  Copy-Item $media $pkg -Recurse
}
$relMeta = Join-Path $pkg "releases"
New-Item -ItemType Directory -Path $relMeta -Force | Out-Null
Copy-Item (Join-Path $PSScriptRoot "README.txt") $relMeta -ErrorAction SilentlyContinue
Copy-Item (Join-Path $PSScriptRoot "pack_backup.ps1") $relMeta
$zip = Join-Path $destDir ("Chukie_Ui_v" + $ver + "_backup_" + $stamp + ".zip")
if (Test-Path $zip) {
  Remove-Item $zip -Force
}
Compress-Archive -Path $pkg -DestinationPath $zip -Force
Remove-Item $stage -Recurse -Force
Get-Item $zip | Select-Object FullName, Length, LastWriteTime | Format-List
