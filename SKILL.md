---
name: windows-dpi-automation
description: Windows 桌面自动化中的 DPI 缩放适配方案。当遇到截图只显示左上角一部分、点击坐标总是偏差、窗口位置和实际显示对不上等问题时使用。核心解决 125%/150%/200%/250% 等 DPI 缩放下，PowerShell/Windows API 截图与点击坐标不一致的坑。适用于所有需要通过截屏识别屏幕内容、然后点击操作的场景。
---

## 问题根因

Windows 开启 DPI 缩放（如 150%、250%）后，会出现两个坐标系：
- **物理分辨率**：显示器实际像素点数量（如 2560x1600）
- **逻辑分辨率**：缩放后应用看到的分辨率（如 2560/2.5=1024, 1600/2.5=640）

PowerShell 默认**不是 DPI 感知进程**，它会导致两个关键问题：

### 问题 A：截图只显示左上角一部分
1. `PrimaryScreen.Bounds` 返回的是**逻辑分辨率**（如 1024x640）
2. `CopyFromScreen` 把传入的尺寸当作**物理像素**来截取
3. 结果：只截了物理屏幕左上角那一块（如 1024x640），右边和下边的内容完全没截到

### 问题 B：点击坐标与截图坐标不一致
1. `SetCursorPos` / `mouse_event` 在非 DPI-aware 进程中接受的是**逻辑坐标**
2. 截图读出来的是**物理坐标**
3. 两者相差一个缩放比例（2.5 倍等），直接混用必然点错

## 快速检测方法

先运行这段代码，看看你遇到的是不是这个问题：

```powershell
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
Write-Output "PrimaryScreen.Bounds 返回: $($screen.Width) x $($screen.Height)"

# 如果这个值和显示器物理分辨率差很多，就是 DPI 缩放问题
# 比如物理 2560x1600，但这里返回 1024x640，就是 250% 缩放
```

## 标准解决方案

### 1. 用物理分辨率截取完整屏幕

**不要用 `PrimaryScreen.Bounds` 的返回值作为截图尺寸**，而是直接用物理分辨率：

```powershell
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 物理分辨率，根据你的显示器调整
$physicalWidth = 2560
$physicalHeight = 1600

$bmp = New-Object System.Drawing.Bitmap($physicalWidth, $physicalHeight)
$graphics = [System.Drawing.Graphics]::FromImage($bmp)
$graphics.CopyFromScreen(0, 0, 0, 0, (New-Object System.Drawing.Size($physicalWidth, $physicalHeight)))
$bmp.Save("screenshot.png", [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bmp.Dispose()
```

### 2. 点击坐标必须用逻辑坐标（重要！）

**截图读出的坐标是物理坐标，点击时必须换算成逻辑坐标：**

```
逻辑坐标 = 物理坐标 ÷ 缩放比例
```

例如 250% 缩放时，截图上看到按钮在物理 (860, 25)，点击时应使用：
```
SetCursorPos(860 ÷ 2.5, 25 ÷ 2.5) = SetCursorPos(344, 10)
```

```powershell
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class ClickHelper {
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint cButtons, uint dwExtraInfo);
}
"@

# 关键：这里填逻辑坐标（物理坐标 ÷ 缩放比例）
# 250% 缩放下：物理 (860,25) → 逻辑 (344, 10)
[ClickHelper]::SetCursorPos(344, 10)
Start-Sleep -Milliseconds 200
[ClickHelper]::mouse_event(0x0002, 0, 0, 0, 0)  # 左键按下
Start-Sleep -Milliseconds 80
[ClickHelper]::mouse_event(0x0004, 0, 0, 0, 0)  # 左键抬起
```

### 3. 如何获取准确的物理分辨率

如果不知道自己的物理分辨率，可以用这个方法检测：

```powershell
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 尝试用大尺寸截取，看实际能截到多少
# 先试 3840x2160，如果成功就是 4K 屏，再往下试
$testWidth = 3840
$testHeight = 2160

try {
    $bmp = New-Object System.Drawing.Bitmap($testWidth, $testHeight)
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    $graphics.CopyFromScreen(0, 0, 0, 0, (New-Object System.Drawing.Size($testWidth, $testHeight)))
    $bmp.Save("test_screen.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bmp.Dispose()
    Write-Output "成功截取 $testWidth x $testHeight"
} catch {
    Write-Output "截取失败，换小尺寸试试"
}
```

### 4. 如何确认缩放比例

```powershell
# 方法一：PrimaryScreen.Bounds 返回逻辑分辨率
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
Write-Output "逻辑分辨率: $($screen.Width) x $($screen.Height)"

# 方法二：通过注册表读取缩放比例
$dpi = (Get-ItemProperty "HKCU:\Control Panel\Desktop\WindowMetrics" -ErrorAction SilentlyContinue)
# 或直接算：物理分辨率 ÷ 逻辑分辨率 = 缩放比例
# 2560 ÷ 1024 = 2.5 → 250%
```

## 常见 DPI 缩放对应表

| 缩放比例 | 物理分辨率 | 逻辑分辨率 | 换算系数 |
|---------|-----------|-----------|---------|
| 100%    | 1920x1080 | 1920x1080 | 1.0 |
| 125%    | 1920x1080 | 1536x864  | 1.25 |
| 150%    | 2560x1600 | 1707x1067 | 1.5 |
| 150%    | 1920x1080 | 1280x720  | 1.5 |
| 200%    | 3840x2160 | 1920x1080 | 2.0 |
| 250%    | 2560x1600 | 1024x640  | 2.5 |

## 标准操作流程

1. **确认缩放**：用 `PrimaryScreen.Bounds` 确认逻辑分辨率，算出缩放比例
2. **截屏**：用物理分辨率截取完整屏幕
3. **读图**：识别目标元素在截图中的物理坐标
4. **换算**：物理坐标 ÷ 缩放比例 = 逻辑坐标
5. **点击**：用逻辑坐标 `SetCursorPos` + `mouse_event`
6. **验证**：再截一张图，确认点击是否命中

**核心原则：截图用物理坐标读，点击用逻辑坐标写，中间除以缩放比例。**

## 踩坑记录

1. **不要相信 `PrimaryScreen.Bounds`**：它返回的是逻辑分辨率，不是物理分辨率
2. **截图用物理坐标读**：CopyFromScreen 按物理像素截取，截图上读到的就是物理坐标
3. **点击用逻辑坐标写**：非 DPI-aware 进程 SetCursorPos 接受逻辑坐标，必须除以缩放比例
4. **不要混用**：直接用截图物理坐标点击 = 必错位
5. **`GetWindowRect` 返回的也是逻辑坐标**：和截图的物理坐标对不上，不要用它来反推截图坐标
6. **窗口最大化后问题依然存在**：即使窗口占满屏幕，DPI 缩放的坑还是一样的

## 特殊情况：直接改分辨率（非缩放）怎么办

用户可能直接改**分辨率**（如 2560x1600 → 800x600），而不是改缩放比例。这时规则不同：

### 检测方法：物理=逻辑 就是改分辨率
```powershell
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
# 调用 SetProcessDPIAware 前后分别取 GetSystemMetrics(0/1)
# 如果两次都返回 800x600，说明真的改了分辨率（缩放系数=1.0）
# 如果 DPI-aware 后变大（如 2560x1600），说明只是改了缩放
```

### 关键规则
- **桌面渲染分辨率 = 新分辨率**（800x600），鼠标坐标空间也是 800x600
- **截图用当前桌面分辨率（800x600）即可**，读出的坐标就是点击坐标（1:1，无需换算）
- **如果还用物理大分辨率（2560x1600）截**，得到的是被**拉伸**的画面（2560/800=3.2 倍），坐标需除以拉伸倍数
- 实际物理屏幕仍然是 2560x1600 像素，显卡负责把 800x600 画面拉伸/居中显示

### 实测示例（800x600 分辨率）
- 截屏：用 800x600 截取 → 完整画面
- 定位：WorkBuddy"帮助(H)"按钮在截图坐标 (235, 24)（不同时刻窗口可能漂移，点击前先截屏确认）
- 点击：SetCursorPos(235, 24) 直接点 → 帮助菜单成功弹出 ✅
- 若用 2560x1600 截，画面放大 3.2 倍，帮助按钮在 (752, 77)，需要 ÷3.2 才是点击坐标

### 窗口位置漂移注意
分辨率切换后窗口可能被系统重新摆放，**每次点击前先截屏或 GetWindowRect 确认窗口当前位置**，不要沿用旧坐标。

## 适用场景

- 需要截屏识别屏幕内容，然后点击操作的任何场景
- 遇到「截图只显示左上角一块」的问题
- 遇到「点击坐标总是偏，而且偏差比例固定」的问题
- 遇到「窗口位置查出来和截图里看到的对不上」的问题
- 遇到「改了缩放比例后，原来能点的坐标突然全部失效」的问题
- 遇到「改了分辨率后，截图要么太大要么太小」的问题
