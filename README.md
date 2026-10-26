# windows-dpi-automation

**Fix Windows DPI coordinate scaling for desktop automation (PowerShell + .NET, zero dependencies).**

Windows DPI 缩放下 PowerShell/Windows API 截图与点击坐标不一致的完整解决方案。纯 PowerShell + .NET 实现，零外部依赖，无需安装任何东西。

## The Problem / 问题根因

Windows 开启 DPI 缩放（125%/150%/200%/250% 等）后存在**两套坐标系**：

- **物理分辨率**：显示器实际像素点数量（如 2560x1600）
- **逻辑分辨率**：缩放后应用看到的分辨率（如 2560÷2.5=1024, 1600÷2.5=640）

PowerShell 默认**不是 DPI 感知进程**，会导致两个典型故障：

1. **截图只显示左上角一部分** — `PrimaryScreen.Bounds` 返回逻辑分辨率，而 `CopyFromScreen` 按物理像素截取，两者混用就只截到左上角一块
2. **点击永远点偏** — 截图读出来的是物理坐标，而 `SetCursorPos` 在非 DPI-aware 进程中接受逻辑坐标，直接混用必然错位

## The Solution / 核心方法（实测验证）

```
截图用物理坐标读，点击用逻辑坐标写，中间除以缩放系数。
```

| 步骤 | 坐标系 | 说明 |
|------|--------|------|
| 检测 | — | `PrimaryScreen.Bounds` 得逻辑分辨率，算出缩放系数（物理÷逻辑） |
| 截图 | 物理 | `CopyFromScreen` 用物理尺寸（如 2560x1600）截全屏 |
| 读坐标 | 物理 | 从截图上读到的就是物理坐标 |
| 换算 | — | 逻辑坐标 = 物理坐标 ÷ 缩放系数 |
| 点击 | 逻辑 | `SetCursorPos` + `mouse_event` 用逻辑坐标 |

## Quick Start / 快速开始

```powershell
# 1. 检测当前缩放比例
.\scripts\detect-dpi.ps1

# 2. 物理分辨率截全屏
.\scripts\screenshot.ps1 -OutputPath "screen.png"

# 3. 逻辑坐标点击（从截图读出物理坐标后 ÷ 缩放系数）
.\scripts\click.ps1 -X 344 -Y 10
```

## Special Case / 特殊情况：直接改分辨率

用户直接改**分辨率**（如 2560x1600 → 800x600）而非缩放时：

- `SetProcessDPIAware()` 前后 `GetSystemMetrics` 都返回新分辨率 → 确认是改分辨率（缩放系数=1.0）
- 截图用当前桌面分辨率（800x600）即可，点击坐标 1:1 直接用
- 若还用物理大分辨率截，得到的是**拉伸 3.2 倍**的画面，坐标需除以拉伸倍数

## Verified / 实测验证记录

| 场景 | 缩放/分辨率 | 结果 |
|------|------------|------|
| 150% 缩放 | 逻辑 1707x1067 | 点击成功 ✅ |
| 250% 缩放 | 逻辑 1024x640 | 物理坐标点击失败、逻辑坐标点击成功 ✅ |
| 200% 缩放 | 逻辑 1280x800 | 点击微信图标成功 ✅ |
| 800x600 分辨率 | 物理=逻辑 | 点击 WorkBuddy 菜单成功 ✅ |

## Known Dead Ends / 已验证的死路

- `computer_use_tool` (plane="cu") 截屏在关闭虚拟显示器时全黑，不可用于观察真实桌面
- 把截图物理坐标直接灌进 `SetCursorPos`，缩放 >100% 时必然点偏（250% 下实测偏移 2.5 倍）

## Relation to precision-desktop / 与同类项目的关系

GitHub 上 [precision-desktop](https://github.com/ikoskela/precision-desktop) 解决同一问题域，但实现路径不同：

| 维度 | precision-desktop | 本项目 |
|------|------------------|--------|
| 形态 | Python MCP server（需安装 MCP SDK） | Skill + PowerShell 脚本（零依赖） |
| 元素定位 | UI Automation 按名称查找 | 截图视觉定位（对 Electron 应用也有效） |
| 校准 | 人工提供参考点 + 持久化 | 每次自动检测缩放系数 |
| 点击坐标 | 面向 DPI-aware 工具（物理坐标） | 面向非 DPI-aware PowerShell（逻辑坐标） |

两者结论看似矛盾（点击用物理 vs 逻辑坐标），实际前提不同：坐标行为取决于**进程是否 DPI-aware**。

## License

[MIT](LICENSE)
