---
title: KonadoScript 編輯器
order: 5
---

# Godot 內建 KonadoScript 編輯器

啟用 Konado 外掛後，在檔案系統面板中雙擊 `.ks` 檔案，即可在底部的 `KonadoEdit` 面板中開啟。編輯器會直接修改原始 KonadoScript 檔案，儲存後自動要求 Godot 重新匯入。

## 編輯功能

- 使用分頁同時編輯多個 `.ks` 檔案，並分別保留游標與未儲存狀態
- 自動儲存復原草稿；編輯器或外掛意外中止後可在再次開啟時復原
- 偵測外部程式修改；沒有本機修改時自動重新載入，有衝突時交由使用者選擇
- 支援尋找、取代、跳至指定行及本機分支符號導覽
- 從陳述式目錄插入目前所有支援的 KonadoScript 指令

## 高亮與補全

`KND_KsHighlighter` 以 Godot 的 `SyntaxHighlighter` 實作。高亮、程式碼補全與陳述式範本共同讀取 `KS_LanguageCatalog`，合法關鍵字則以解析器的 `KS_Token.KEYWORDS` 為準。自動化測試會在新增或移除指令時檢查兩者是否一致。

高亮規則只會在首次使用時編譯，每一行也只記錄顏色改變的位置，避免編輯或捲動時重複編譯正規表示式，或為每個字元建立字典項目。

預設高亮資源位於：

```text
res://addons/konado/editor/ks_editor/highlighter.tres
```

自訂編輯器也可以直接建立高亮器：

```gdscript
set_syntax_highlighter(KND_KsHighlighter.new())
```

## 即時診斷

停止輸入片刻後，編輯器會執行詞法、語法與語意分析，但不會產生執行階段 `KND_Shot` 資源。錯誤與警告會同時顯示在：

- 程式碼行的診斷標記與背景色
- 編輯器下方的問題清單

點選問題或其行號槽標記即可跳至相關位置。儲存時仍會執行正常的 Godot 匯入，因此即時診斷不會取代正式匯入結果。

## 快速鍵

| 功能 | Windows / Linux | macOS |
| --- | --- | --- |
| 儲存 | `Ctrl+S` | `Command+S` |
| 關閉目前分頁 | `Ctrl+W` | `Command+W` |
| 尋找 | `Ctrl+F` | `Command+F` |
| 尋找與取代 | `Ctrl+H` | `Command+Option+F` |
| 跳至指定行 | `Ctrl+L` | `Command+L` |
