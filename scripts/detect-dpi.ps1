# detect-dpi.ps1
# 检测当前 Windows DPI 缩放比例（物理分辨率 / 逻辑分辨率）
# 用法: .\detect-dpi.ps1

Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class DpiProbe {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int nIndex);
}
"@

# 非 DPI-aware 时 GetSystemMetrics 返回逻辑尺寸
$logicalW = [DpiProbe]::GetSystemMetrics(0)
$logicalH = [DpiProbe]::GetSystemMetrics(1)

# 调用 SetProcessDPIAware 后再取（返回物理尺寸）
[DpiProbe]::SetProcessDPIAware() | Out-Null
$physW = [DpiProbe]::GetSystemMetrics(0)
$physH = [DpiProbe]::GetSystemMetrics(1)

$scr = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$scaleX = [math]::Round($physW / $logicalW, 2)
$scaleY = [math]::Round($physH / $logicalH, 2)

Write-Output "逻辑分辨率: $logicalW x $logicalH"
Write-Output "物理分辨率(DPI-aware后): $physW x $physH"
Write-Output "PrimaryScreen.Bounds: $($scr.Width) x $($scr.Height)"
Write-Output "缩放系数: X=$scaleX Y=$scaleY"

if ($scaleX -eq 1.0 -and $scaleY -eq 1.0) {
    Write-Output "结论: 缩放 100%（物理=逻辑），点击坐标 1:1 直接用截图坐标"
} else {
    Write-Output "结论: DPI 缩放 $([math]::Round($scaleX*100))%，点击坐标 = 截图物理坐标 ÷ $scaleX"
}
