# Web 觸控被瀏覽器吃掉（只能射擊／無法移動）的處理

## 原因簡述
手機瀏覽器會把觸控用於**捲動、縮放、下拉重新整理**等。若未關閉預設行為，常見現象是：
- 只有「一個指標」像滑鼠一樣進遊戲 → 容易變成**只能開火**（右搖桿／射擊邏輯吃到事件）；
- 或 `touchmove` 被當成頁面捲動，`passive: true` 時無法 `preventDefault`。

## 本專案已做的修正
1. **CSS**：`html` / `body` / `#canvas` 設 `touch-action: none`、`overscroll-behavior: none` 等。
2. **JS**：對 `#canvas` 與 `document.body` 的 `touchmove` 使用 `{ passive: false }` 並 `preventDefault()`，避免捲動搶走手勢。
3. **viewport**：加上 `maximum-scale=1` 等，減少雙指縮放與部分系統手勢干擾。
4. **Godot 匯出**：`export_presets.cfg` 的 **`html/head_include`** 已寫入同一段 **style + script**，之後用編輯器 **Web 匯出** 會自動帶入。

## 你若手動覆蓋 HTML
若 GitHub Pages 仍使用舊的 `index.html` / `RougeShotter.html`，請把 **`docs/`** 裡已更新的版本同步到線上，或從編輯器重新匯出後整包上傳。

## 仍異常時可再檢查
- 是否被包在 **iframe** 裡（上層頁面可能還要設 `touch-action`）。
- iOS Safari：可嘗試「加入主畫面」全螢幕執行。
- 確認線上檔案已更新（快取：強制重新整理或改版本號）。
