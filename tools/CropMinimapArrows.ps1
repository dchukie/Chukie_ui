# Recorta la hoja de flechas (3x2) y exporta PNG con negro -> transparente.
# Ejecución: powershell -File tools\CropMinimapArrows.ps1
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$srcPath = Join-Path $PSScriptRoot "..\assets\source_arrows.png"
if (-not (Test-Path $srcPath)) {
  Write-Error "Missing source PNG: $srcPath (copy sheet to assets\\source_arrows.png)"
}

$outDir = Join-Path $PSScriptRoot "..\Media"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $srcPath).Path)
try {
  $W = $src.Width
  $H = $src.Height
  $w3 = [math]::Floor($W / 3)
  $cols = @($w3, $w3, ($W - 2 * $w3))
  $rowH = [math]::Floor($H / 2)
  $targets = @(
    @{ col = 0; row = 0; tw = 32;  th = 32;  name = "ChukieUi_PlayerArrow_Broad_32.png" },
    @{ col = 1; row = 0; tw = 64;  th = 64;  name = "ChukieUi_PlayerArrow_Broad_64.png" },
    @{ col = 2; row = 0; tw = 128; th = 128; name = "ChukieUi_PlayerArrow_Broad_128.png" },
    @{ col = 0; row = 1; tw = 64;  th = 64;  name = "ChukieUi_PlayerArrow_Thin64a.png" },
    @{ col = 1; row = 1; tw = 64;  th = 64;  name = "ChukieUi_PlayerArrow_Thin64b.png" },
    @{ col = 2; row = 1; tw = 128; th = 128; name = "ChukieUi_PlayerArrow_Thin128.png" }
  )

  function Get-CellRect($col, $row) {
    $x = 0
    for ($i = 0; $i -lt $col; $i++) { $x += $cols[$i] }
    $cw = $cols[$col]
    $y = $row * $rowH
    $ch = $rowH
    return @{ X = $x; Y = $y; W = $cw; H = $ch }
  }

  function New-ArgbBitmap([int]$w, [int]$h) {
    return [System.Drawing.Bitmap]::new($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  }

  function Copy-RegionChroma($bmp, [System.Drawing.Rectangle]$rect, [int]$thr) {
    $dst = New-ArgbBitmap $rect.Width $rect.Height
    for ($yy = 0; $yy -lt $rect.Height; $yy++) {
      for ($xx = 0; $xx -lt $rect.Width; $xx++) {
        $sx = $rect.X + $xx
        $sy = $rect.Y + $yy
        if (($sx -ge $bmp.Width) -or ($sy -ge $bmp.Height)) { continue }
        $c = $bmp.GetPixel($sx, $sy)
        if ($c.R -le $thr -and $c.G -le $thr -and $c.B -le $thr) {
          $dst.SetPixel($xx, $yy, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
        }
        else {
          $dst.SetPixel($xx, $yy, [System.Drawing.Color]::FromArgb(255, $c.R, $c.G, $c.B))
        }
      }
    }
    return $dst
  }

  function Resize-Bitmap($bmp, [int]$tw, [int]$th) {
    $out = New-ArgbBitmap $tw $th
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.DrawImage($bmp, 0, 0, $tw, $th)
    $g.Dispose()
    $bmp.Dispose()
    return $out
  }

  foreach ($t in $targets) {
    $cell = Get-CellRect $t.col $t.row
    $padX = [math]::Max(8, [math]::Floor($cell.W * 0.06))
    $padY = [math]::Max(8, [math]::Floor($cell.H * 0.05))
    $labelTrim = [math]::Max(28, [math]::Floor($cell.H * 0.18))
    $innerW = $cell.W - 2 * $padX
    $innerH = $cell.H - $padY - $labelTrim
    if ($innerW -lt 8 -or $innerH -lt 8) { throw "Cell too small col=$($t.col) row=$($t.row)" }
    $rect = New-Object System.Drawing.Rectangle ($cell.X + $padX), ($cell.Y + $padY), $innerW, $innerH
    $cut = Copy-RegionChroma $src $rect 28
    $final = Resize-Bitmap $cut $t.tw $t.th
    $outPath = Join-Path $outDir $t.name
    $final.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $final.Dispose()
    Write-Host "OK" $t.name
  }
}
finally {
  $src.Dispose()
}

Write-Host "Done:" $outDir
