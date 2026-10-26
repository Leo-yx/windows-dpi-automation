# click.ps1
# 用逻辑坐标点击（非 DPI-aware PowerShell 中 SetCursorPos 接受逻辑坐标）
# 逻辑坐标 = 截图物理坐标 ÷ 缩放系数
# 用法: .\click.ps1 -X 344 -Y 10 [-ClickCount 1]

param(
    [Parameter(Mandatory=$true)][int]$X,
    [Parameter(Mandatory=$true)][int]$Y,
    [int]$ClickCount = 1
)

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Clicker {
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint cButtons, uint dwExtraInfo);
}
"@

[Clicker]::SetCursorPos($X, $Y)
Start-Sleep -Milliseconds 200

for ($i = 0; $i -lt $ClickCount; $i++) {
    [Clicker]::mouse_event(0x0002, 0, 0, 0, 0)  # 左键按下
    Start-Sleep -Milliseconds 80
    [Clicker]::mouse_event(0x0004, 0, 0, 0, 0)  # 左键抬起
    Start-Sleep -Milliseconds 100
}

Write-Output "已点击 ($X, $Y) x$ClickCount"
