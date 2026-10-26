# screenshot.ps1
# 用物理分辨率截取完整屏幕（解决 DPI 缩放下只截左上角的问题）
# 用法: .\screenshot.ps1 -OutputPath "screen.png" [-Width 2560] [-Height 1600]

param(
    [string]$OutputPath = "screen.png",
    [int]$Width = 0,
    [int]$Height = 0
)

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# 未指定尺寸时，用 SetProcessDPIAware 后的 GetSystemMetrics 获取物理分辨率
if ($Width -eq 0 -or $Height -eq 0) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class DpiScr {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int nIndex);
}
"@
    [DpiScr]::SetProcessDPIAware() | Out-Null
    $Width = [DpiScr]::GetSystemMetrics(0)
    $Height = [DpiScr]::GetSystemMetrics(1)
}

$bmp = New-Object System.Drawing.Bitmap($Width, $Height)
$graphics = [System.Drawing.Graphics]::FromImage($bmp)
$graphics.CopyFromScreen(0, 0, 0, 0, (New-Object System.Drawing.Size($Width, $Height)))
$bmp.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bmp.Dispose()

Write-Output "已保存: $OutputPath ($Width x $Height)"
