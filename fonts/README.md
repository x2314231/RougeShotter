# UI 字型（繁體中文／CJK）

- **NotoSansTC-wght.ttf**：Google [Noto Sans TC](https://fonts.google.com/noto/specimen/Noto+Sans+TC) 變體字型，用於 Web/HTML5 匯出，避免瀏覽器無系統中文字型時出現「豆腐字」。
- 授權見 **NotoSansTC-OFL.txt**（SIL Open Font License 1.1）。

`GameUI.gd` 會在執行時載入此字型，並對各 `Label`／`Button` 使用 `add_theme_font_override`（`CanvasLayer` 本身無法掛 `Theme`）。
