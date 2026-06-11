Add-Type -AssemblyName System.Drawing

$source = "f:\music-flutter\assets\icons\ic_launcher_base.png"

$sizes = @{
    "f:\music-flutter\android\app\src\main\res\mipmap-mdpi\ic_launcher.png" = 48
    "f:\music-flutter\android\app\src\main\res\mipmap-hdpi\ic_launcher.png" = 72
    "f:\music-flutter\android\app\src\main\res\mipmap-xhdpi\ic_launcher.png" = 96
    "f:\music-flutter\android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png" = 144
    "f:\music-flutter\android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png" = 192
}

foreach ($dest in $sizes.Keys) {
    $size = $sizes[$dest]
    $img = [System.Drawing.Image]::FromFile($source)
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.DrawImage($img, 0, 0, $size, $size)
    $g.Dispose()
    $bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $img.Dispose()
    Write-Output "Done: $dest"
}

Copy-Item $source "f:\music-flutter\assets\icons\ic_launcher_playstore.png" -Force
Write-Output "Done: Play Store icon"
Write-Output "ALL DONE"