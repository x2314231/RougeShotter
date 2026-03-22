---
name: rougeshotter
description: >-
  Godot 4 專案 RougeShotter（類 Rogue 射擊）：場景結構、MobileControls／雙搖桿、GameUI 繁中字型、Web 匯出與觸控修正。
  Use when editing this repository, Godot GDScript in RougeShotter, web/HTML5 export,
  GitHub Pages (docs/), touch joysticks, or Chinese UI fonts.
---

# RougeShotter（Godot 4）

## 專案定位
- **引擎**：Godot 4.x，主場景 `res://Main.tscn`。
- **類型**：2D 射擊／類 Rogue，玩家 `Player`、關卡與波次 `LevelManager`、UI `GameUI`。

## 目錄與職責
| 路徑 | 說明 |
|------|------|
| `Main.tscn` | 根場景：地形、Player、WorldBounds、**GameUI**（layer 100）、**TouchJoystick**、LevelManager、Camera2D |
| `scripts/Player.gd` | 移動、瞄準、射擊；讀取 `MobileControls` |
| `scripts/LevelManager.gd` | 敵人波次、升級、分數等 |
| `scripts/GameUI.gd` | 動態建立 HUD／升級／暫停／結束；**內嵌 CJK 字型**（`add_theme_font_override`） |
| `scripts/MobileControls.gd` | **Autoload**：`move_*` InputMap、左搖桿向量、右**開火**搖桿向量、觸控瞄準（空白處） |
| `scripts/TouchJoystick.gd` | 虛擬搖桿；`Role`: **MOVE**（左下）／**FIRE**（右下） |
| `scenes/TouchJoystick.tscn` | `CanvasLayer` layer 8；子節點 `MoveJoystick`、`FireJoystick` |
| `fonts/` | `NotoSansTC-wght.ttf` 等；Web 需內嵌否則中文方塊 |
| `export_presets.cfg` | Web 匯出；**`html/head_include`** 含觸控 CSS/JS |
| `docs/` | 部署用 HTML（如 GitHub Pages）；含 `WEB_TOUCH_FIX.md` |

## 必守慣例
- **CanvasLayer 無 `theme` 屬性**：UI 字型用 `Control.add_theme_font_override("font", …)`（見 `GameUI.gd`）。
- **開火搖桿**：`MobileControls.fire_joystick_vector` 非零時，`Player` 以此為瞄準並持續射擊（冷卻仍生效）。
- **觸控排除**：`MobileControls._input` 會略過左／右搖桿矩形與對應 `finger_index`，避免與「空白瞄準」衝突。
- **Web 中文**：務必包含 `fonts/` 資源；匯出 filter 需含字型（預設 `all_resources` 即可）。

## Web／手機觸控
- 瀏覽器可能吃掉 `touchmove`：依賴 **`html/head_include`**（`touch-action: none`、`passive: false` + `preventDefault`）及 `docs/*.html` 同步更新。
- 詳見 `docs/WEB_TOUCH_FIX.md`。

## 修改 UI 或新 Label／Button
1. 沿用 `GameUI.gd` 的 `_get_or_create_label` / `_get_or_create_button`（已套 `_ui_font`），或自行對控制項呼叫 `_apply_font_to_control` 同等邏輯。
2. 勿在 `CanvasLayer` 上設 `theme`（無效）。

## 新增輸入或搖桿
- 鍵盤：在 `MobileControls._setup_input_map()` 擴充 `InputMap`，並在 `Player` 用 `Input.get_vector(...)` 或 `Input.is_action_*`。
- 新觸控區：複製 `TouchJoystick` 模式，於 `MobileControls` 新增 rect／vector／finger index，並在 `_input` 排除該矩形。

## 匯出 Web（檢查清單）
- [ ] `project.godot` 含 `MobileControls` autoload
- [ ] `export_presets.cfg` 的 `html/head_include` 仍存在（觸控）
- [ ] 部署目錄若手動覆蓋 HTML，需與編輯器產物或 `docs/` 對齊

## 相關檔案（快速開啟）
- 玩家：`scripts/Player.gd`
- 觸控集中：`scripts/MobileControls.gd`、`scripts/TouchJoystick.gd`
- UI：`scripts/GameUI.gd`、`scenes/GameUI.tscn`
