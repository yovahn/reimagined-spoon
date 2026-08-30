$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$godotPath = Join-Path $env:USERPROFILE 'Documents\Godot\Godot_v4.7.2-stable_win64.exe'
$outputDirectory = Join-Path $projectRoot 'artifacts\screenshots'

if (-not (Test-Path -LiteralPath $godotPath)) {
    throw "Godot was not found at $godotPath"
}

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WindowCapture {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr handle, out Rect rect);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr handle);
}
'@

$captureProcess = Start-Process -FilePath $godotPath -ArgumentList @('--path', $projectRoot) -WorkingDirectory $projectRoot -PassThru
try {
    $deadline = (Get-Date).AddSeconds(15)
    do {
        Start-Sleep -Milliseconds 250
        $captureProcess.Refresh()
    } while ($captureProcess.MainWindowHandle -eq [IntPtr]::Zero -and (Get-Date) -lt $deadline)

    if ($captureProcess.MainWindowHandle -eq [IntPtr]::Zero) {
        throw 'Godot did not create a render window within 15 seconds.'
    }

    [WindowCapture]::SetForegroundWindow($captureProcess.MainWindowHandle) | Out-Null
    Start-Sleep -Milliseconds 800
    $rect = New-Object WindowCapture+Rect
    [WindowCapture]::GetWindowRect($captureProcess.MainWindowHandle, [ref]$rect) | Out-Null
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    if ($width -le 0 -or $height -le 0) { throw 'Godot returned an invalid window size.' }

    $bitmap = New-Object System.Drawing.Bitmap $width, $height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
    $outputPath = Join-Path $outputDirectory 'world-preview.png'
    $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
    Write-Output "SCREENSHOT_CAPTURE: $outputPath"
} finally {
    if (-not $captureProcess.HasExited) { Stop-Process -Id $captureProcess.Id }
}
