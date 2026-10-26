# windows-dpi-automation

**Fix Windows DPI coordinate scaling for desktop automation (PowerShell + .NET, zero dependencies).**

This is a solution to  the mismatch between screenshot and click coordinates in PowerShell/Windows API under Windows DPI scaling. Completely realized by PowerShell + .NET , do not need to install anything else.


## The Problem

Window has two coordinates when launching DPI scaling(e.g 125%/150%/200%/250%)

- **Phythical resolution**：the real pixels of the monitor（e.g 2560x1600）
- **Logical resolution**：resolution after scaling（e.g 2560÷2.5=1024, 1600÷2.5=640）

By default,PowerShell is not a DPI-aware process, which leads to two typical failures:

1. **The screenshots only show the top-left corner** — `PrimaryScreen.Bounds` return logical resolution, while `CopyFromScreen` captures the phythical resolution, which caused it can only capture the top-left corner.
2. **Click the wrong place** - via screenshots, we can only read the physical coordinates, however, the `SetCursorPos` accept logical coordinates,in a non-DPI-aware process ,so mixing the two directly will inevitably cause a mismatch.


## The Solution
```
Capture screenshots in physical coordinates.Click in logical coordinates.And divide by the scaling factor in between.
```

| step | Coordinate system | Explain |
|------|--------|------|
| detect | — | get logical resolution via`PrimaryScreen.Bounds` ,and caculate the scaling factor(physical resolution devide logical resolution) |
| capture | Physical | `CopyFromScreen` capture the full screen by physical coordinates |
| read the coordinates | Physical | read from the screenshot |
| convert | — | logical coordinates = physical coordinates / scaling factor |
| click | logical | `SetCursorPos` + `mouse_event` ,which use physical coordinates |

## Quick Start

```powershell
# 1. detect the scaling ratio
.\scripts\detect-dpi.ps1

# 2. capture full-screen by physical coordinates
.\scripts\screenshot.ps1 -OutputPath "screen.png"

# 3. click by logical coordinates(which caculated from physical coordinates and scaling factor)
.\scripts\click.ps1 -X 344 -Y 10
```

## Special Case

when the user change the **resolution**(e.g 2560x1600 -> 800x600) directly rather than scaling:

- `SetProcessDPIAware()` and `GetSystemMetrics` return new resolution -> confirm that its change the resolution(scaling factor = 1.0)
- its ok to capture the resolution in desktop directly , use the click coordinates
- if it used the bigger resolution to captured, it returns **stretch 3.2 times**, the coordinates need to be devided by scaling factor



## Verified--

| Scenario | Scaling/Resolution | Result |
|------|------------|------|
| 150% scaling | Logical 1707x1067 | Click succeeded |
| 250% scaling | Logical 1024x640 | Physical-coordinate click failed, logical-coordinate click succeeded |
| 200% scaling | Logical 1280x800 | Successfully clicked the WeChat icon |
| 800x600 resolution | Physical = Logical | Successfully clicked the WorkBuddy menu |

## Known Dead Ends

- `computer_use_tool` (plane="cu") screenshots come out completely black when the virtual display is off, so it cannot be used to observe the real desktop
- Feeding physical screenshot coordinates straight into `SetCursorPos` will always miss when scaling > 100% (measured a 2.5× offset at 250%)

## Relation to precision-desktop / Similar Projects

[precision-desktop](https://github.com/ikoskela/precision-desktop) on GitHub solves the same problem space, but takes a different implementation path:

| Dimension | precision-desktop | This project |
|------|------------------|--------|
| Form | Python MCP server (requires installing the MCP SDK) | Skill + PowerShell scripts (zero dependencies) |
| Element location | UI Automation lookup by name | Visual location from screenshots (also works for Electron apps) |
| Calibration | Manually provided reference points + persistence | Auto-detects the scaling factor each run |
| Click coordinates | For DPI-aware tools (physical coordinates) | For non-DPI-aware PowerShell (logical coordinates) |

The two conclusions look contradictory (physical vs logical coordinates for clicking), but the premises differ: the coordinate behavior depends on **whether the process is DPI-aware**.

## License

[MIT](LICENSE)
