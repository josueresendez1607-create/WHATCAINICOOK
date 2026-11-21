# Genera los PNG del logotipo WHATCANICOOK de forma reproducible.
# Requisitos: Windows con .NET System.Drawing (incluido en Windows 10/11).
# Uso: powershell -ExecutionPolicy Bypass -File tools\generate_assets.ps1

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$logoDir = Join-Path $root 'assets\logos'
$iconDir = Join-Path $root 'assets\icons'
$imageDir = Join-Path $root 'assets\images'
New-Item -ItemType Directory -Force -Path $logoDir, $iconDir, $imageDir | Out-Null

$cream = [System.Drawing.Color]::FromArgb(255, 255, 246, 236)
$orange = [System.Drawing.Color]::FromArgb(255, 242, 106, 27)
$orangeDark = [System.Drawing.Color]::FromArgb(255, 201, 78, 10)
$white = [System.Drawing.Color]::White
$green = [System.Drawing.Color]::FromArgb(255, 78, 158, 99)
$charcoal = [System.Drawing.Color]::FromArgb(255, 43, 36, 34)

function New-Canvas([int]$width, [int]$height, [bool]$transparent) {
    $bitmap = New-Object System.Drawing.Bitmap($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    if (-not $transparent) {
        $graphics.Clear($cream)
    } else {
        $graphics.Clear([System.Drawing.Color]::Transparent)
    }
    return @{ Bitmap = $bitmap; Graphics = $graphics }
}

function Save-Canvas($canvas, [string]$path) {
    $canvas.Bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $canvas.Graphics.Dispose()
    $canvas.Bitmap.Dispose()
    Write-Output "Generado: $path"
}

function Draw-Mark($g, [double]$scale, [double]$offsetX, [double]$offsetY) {
    function R([double]$v) { return [int][math]::Round($v * $scale) }

    $oldTransform = $g.Transform
    $g.TranslateTransform([single]$offsetX, [single]$offsetY)
    $g.ScaleTransform([single]$scale, [single]$scale)

    # Círculo naranja principal.
    $brushOrange = New-Object System.Drawing.SolidBrush($orange)
    $g.FillEllipse($brushOrange, 162, 150, 700, 700)

    # Plato: dos elipses concéntricas.
    $brushWhite = New-Object System.Drawing.SolidBrush($white)
    $penDark = New-Object System.Drawing.Pen($orangeDark, 16)
    $g.FillEllipse($brushWhite, 260, 574, 504, 152)
    $g.DrawEllipse($penDark, 260, 574, 504, 152)
    $brushCream = New-Object System.Drawing.SolidBrush($cream)
    $g.FillEllipse($brushCream, 334, 600, 356, 84)

    # Base del gorro.
    $hatPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $hatPath.AddRectangle((New-Object System.Drawing.Rectangle(392, 520, 240, 158)))
    $g.FillPath($brushWhite, $hatPath)
    $g.DrawPath($penDark, $hatPath)

    # Tres pompones del gorro.
    $g.FillEllipse($brushWhite, 314, 314, 212, 212)
    $g.DrawEllipse($penDark, 314, 314, 212, 212)
    $g.FillEllipse($brushWhite, 394, 260, 236, 236)
    $g.DrawEllipse($penDark, 394, 260, 236, 236)
    $g.FillEllipse($brushWhite, 498, 314, 212, 212)
    $g.DrawEllipse($penDark, 498, 314, 212, 212)

    # Hoja verde.
    $leafBrush = New-Object System.Drawing.SolidBrush($green)
    $g.FillEllipse($leafBrush, 680, 288, 132, 72)

    $g.Transform = $oldTransform
    $brushOrange.Dispose(); $brushWhite.Dispose(); $penDark.Dispose(); $brushCream.Dispose(); $leafBrush.Dispose(); $hatPath.Dispose()
}

# --- Icono Android (1024) ---
$icon = New-Canvas 1024 1024 $false
Draw-Mark $icon.Graphics 1.0 0 0
Save-Canvas $icon (Join-Path $iconDir 'app_icon.png')

# --- Foreground adaptativo (1024, transparente) ---
$fg = New-Canvas 1024 1024 $true
Draw-Mark $fg.Graphics 0.78 113 95
Save-Canvas $fg (Join-Path $iconDir 'app_icon_foreground.png')

# --- Logotipo horizontal (1200x400) ---
$logo = New-Canvas 1200 400 $false
Draw-Mark $logo.Graphics 0.72 40 40
$font = New-Object System.Drawing.Font('Arial', 84, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$textBrush = New-Object System.Drawing.SolidBrush($charcoal)
$logo.Graphics.DrawString('WHATCANICOOK', $font, $textBrush, 380, 150)
$accentBrush = New-Object System.Drawing.SolidBrush($orange)
$logo.Graphics.FillRectangle($accentBrush, 382, 252, 430, 12)
$font.Dispose(); $textBrush.Dispose(); $accentBrush.Dispose()
Save-Canvas $logo (Join-Path $logoDir 'logo.png')

# --- Pantalla de carga (1200x1200) ---
$splash = New-Canvas 1200 1200 $false
Draw-Mark $splash.Graphics 0.82 100 160
$splashFont = New-Object System.Drawing.Font('Arial', 58, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$splashBrush = New-Object System.Drawing.SolidBrush($charcoal)
$splash.Graphics.DrawString('WHATCANICOOK', $splashFont, $splashBrush, 170, 900)
$subtitleFont = New-Object System.Drawing.Font('Arial', 26, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$subtitleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 111, 101, 96))
$splash.Graphics.DrawString('Descubre qué puedes cocinar', $subtitleFont, $subtitleBrush, 300, 980)
$splashFont.Dispose(); $splashBrush.Dispose(); $subtitleFont.Dispose(); $subtitleBrush.Dispose()
Save-Canvas $splash (Join-Path $imageDir 'splash.png')
