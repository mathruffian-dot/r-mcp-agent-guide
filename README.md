# 用自然語言控制 R：MCP × R 統計環境安裝說明書

> 讓任何 AI Agent（Claude Code / ChatGPT Codex / Gemini CLI / OpenCode）透過 **MCP（Model Context Protocol）** 驅動本機的 **R** 統計引擎 —— 使用者只用自然語言下指令，Agent 就能跑迴歸、ANOVA、t 檢定、繪圖，全程不必碰 R 介面。

本說明書記錄了一套**已實際驗證可運作**的完整流程（驗證環境：Windows 11 + R 4.6.0 + Claude Code）。其他 Agent 讀到本文件時，可依此流程在自己的環境完成安裝並學會使用。

---

## 0. 這套方案在做什麼？（給 Agent 的心智模型）

```
使用者（自然語言）
      │  「幫我用 R 跑迴歸」
      ▼
   AI Agent ──呼叫 MCP 工具 btw_tool_run_r──►  R 引擎（mcptools server 程序）
      ▲                                              │
      └──────────  回傳統計結果 / 圖檔  ◄────────────┘
```

- **MCP server** = 一個常駐的 R 程序，由 `mcptools::mcp_server()` 啟動。
- **執行能力** = 由 `btw` 套件提供的 `btw_tool_run_r` 工具，能在該 R 程序裡執行任意 R 程式碼並回傳結果（含印出的值、文字、圖、警告、錯誤）。
- **關鍵**：`btw_tool_run_r` 預設**關閉**（因為能執行任意程式碼），必須明確啟用。
- 程式碼在 **server 程序內**執行，狀態跨呼叫保留，**不需要**另外開 RStudio。RStudio 是給人看的選配工具。

> 一句話：裝好 R → 裝 `mcptools` + `btw` → 啟用 `run_r` → 把 server 註冊給你的 Agent → 重啟 Agent → 開始用自然語言下指令。

---

## 1. 安裝 R（必裝）與 RStudio（選配）

能不能用，取決於 **R 是否裝好**，不是 RStudio。RStudio 只是圖形介面，給人看圖、管理變數用。

### Windows（已驗證）

```powershell
# R 本體（必裝）
winget install --id RProject.R -e --accept-source-agreements --accept-package-agreements

# RStudio（選配，給人用的 IDE）
winget install --id Posit.RStudio -e --accept-source-agreements --accept-package-agreements
```

- 預設安裝路徑：`C:\Program Files\R\R-<版本>\`，執行檔在 `...\bin\Rscript.exe`。
- ⚠️ **winget 不會更新「目前終端機 session」的 PATH**。裝完後新開的終端機才會有 `Rscript`；在同一個 session 內請用**完整路徑**呼叫。
- 把 R 加進使用者 PATH（之後任何終端機可直接用 `Rscript`）：

```powershell
$rbin = "C:\Program Files\R\R-4.6.0\bin"   # 換成你的實際版本
$u = [Environment]::GetEnvironmentVariable("Path","User")
if ($u -notlike "*$rbin*") { [Environment]::SetEnvironmentVariable("Path", ($u.TrimEnd(';')+";"+$rbin), "User") }
```

### macOS

```bash
brew install --cask r          # R 本體
brew install --cask rstudio    # RStudio（選配）
# Rscript 通常在 /usr/local/bin/Rscript 或 /Library/Frameworks/R.framework/Resources/bin/Rscript
```

### Linux（Debian/Ubuntu）

```bash
sudo apt update && sudo apt install -y r-base
# RStudio 至 https://posit.co/download/rstudio-desktop/ 下載對應套件
```

### 驗證安裝

```bash
Rscript -e "cat('R version:', R.version.string, '\n')"
```

> 找出 Rscript 完整路徑：macOS/Linux 用 `which Rscript`；Windows PowerShell 用 `(Get-Command Rscript).Source`，或直接到 `C:\Program Files\R\` 找。**這個路徑稍後設定 MCP 會用到，請記下來。**

---

## 2. 安裝 R 套件：mcptools + btw

需要三個套件：`mcptools`（MCP server）、`btw`（提供 `run_r` 等工具）、`evaluate`（`run_r` 的相依，多半已內建）。

```bash
Rscript -e "install.packages(c('mcptools','btw'), repos='https://cloud.r-project.org')"
```

### ⚠️ Windows 常見坑：套件庫不可寫

Windows 上 `C:\Program Files\R\...\library` 需要管理員權限，直接安裝會報 `'lib = ...' is not writable`。**解法：裝到「個人套件庫」**（R 標準做法，免管理員）：

```bash
Rscript -e "userlib <- Sys.getenv('R_LIBS_USER'); dir.create(userlib, recursive=TRUE, showWarnings=FALSE); install.packages(c('mcptools','btw'), repos='https://cloud.r-project.org', lib=userlib)"
```

個人套件庫路徑通常是 `C:\Users\<你>\AppData\Local\R\win-library\<版本>`。R 啟動時會自動把它加進 `.libPaths()`，所以之後 server 找得到。

### ⚠️ 另一個 Windows 坑：R 字串裡的 `\U`

若你想在 `-e` 字串中硬寫 Windows 路徑（如 `C:\Users\...`），反斜線 `\U` 會被 R 當成 Unicode 跳脫而報錯。**一律改用正斜線**：`C:/Users/...`。

### 驗證套件與「執行工具」可啟用

```bash
Rscript -e "options(btw.run_r.enabled=TRUE); ts <- btw::btw_tools(); cat('工具數:', length(ts), '| 含 run_r:', 'btw_tool_run_r' %in% vapply(ts, function(t) t@name, ''), '\n')"
```

預期輸出含 `含 run_r: TRUE`。若 `evaluate` 未裝，補裝：`Rscript -e "install.packages('evaluate', repos='https://cloud.r-project.org')"`。

---

## 3. 啟用 `btw_tool_run_r`（關鍵步驟）

`run_r` 預設關閉。啟用方式（擇一，**建議用 A**）：

- **A. 寫進啟動指令（最可靠，不依賴環境）**：在啟動 server 的指令中先設定 option。第 4 節的指令都已內含這招：
  ```r
  options(btw.run_r.enabled=TRUE); mcptools::mcp_server(tools = btw::btw_tools())
  ```
- **B. 環境變數**（讓所有 R 程序繼承）：
  ```bash
  # macOS/Linux：寫進 ~/.zshrc 或 ~/.bashrc
  export BTW_RUN_R_ENABLED=true
  ```
  ```powershell
  # Windows（使用者層級，持久）
  [Environment]::SetEnvironmentVariable("BTW_RUN_R_ENABLED","true","User")
  ```

> 啟用順序很重要：`btw::btw_tools()` 是在「被呼叫的當下」檢查是否啟用，所以 `options(...)` 必須**先**於 `btw_tools()` 執行。

---

## 4. 把 MCP server 註冊給你的 Agent（四種 Agent 最適化）

所有 Agent 都是啟動一個 stdio 子程序：`<RSCRIPT_PATH> -e "options(btw.run_r.enabled=TRUE); mcptools::mcp_server(tools = btw::btw_tools())"`。

差別只在**設定檔格式**。以下 `<RSCRIPT_PATH>` 請換成第 1 節記下的 Rscript 完整路徑（Windows 範例：`C:\Program Files\R\R-4.6.0\bin\Rscript.exe`）。

📁 各 Agent 的可直接複製設定檔放在 [`configs/`](configs/) 目錄。

### 4-1. Claude Code（已驗證）

最簡單，用內建 CLI 一行註冊（user scope = 所有專案通用）：

```bash
claude mcp add r-stats --scope user -- "<RSCRIPT_PATH>" -e "options(btw.run_r.enabled=TRUE); mcptools::mcp_server(tools = btw::btw_tools())"
```

驗證：`claude mcp list`（應顯示 `r-stats: ... ✓ Connected`）。
**之後必須重啟 Claude Code**，新工具才會載入。

### 4-2. ChatGPT Codex CLI

編輯 `~/.codex/config.toml`，新增（TOML 格式）：

```toml
[mcp_servers.r-stats]
command = "<RSCRIPT_PATH>"
args = ["-e", "options(btw.run_r.enabled=TRUE); mcptools::mcp_server(tools = btw::btw_tools())"]
```

或用 CLI：`codex mcp`（互動式新增）。Codex 以 stdio 啟動子程序，與上述一致。重啟 Codex 生效。

### 4-3. Gemini CLI

編輯 `~/.gemini/settings.json`（全域）或專案內 `.gemini/settings.json`，在 `mcpServers` 加入：

```json
{
  "mcpServers": {
    "r-stats": {
      "command": "<RSCRIPT_PATH>",
      "args": ["-e", "options(btw.run_r.enabled=TRUE); mcptools::mcp_server(tools = btw::btw_tools())"],
      "timeout": 30000
    }
  }
}
```

重啟 Gemini CLI；用 `/mcp` 可檢視已連線的 server 與工具。

### 4-4. OpenCode

編輯 `~/.config/opencode/opencode.json`（全域）或專案內 `opencode.json`，在 `mcp` 加入 `type: "local"`（注意 OpenCode 的 `command` 是**陣列**）：

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "r-stats": {
      "type": "local",
      "command": ["<RSCRIPT_PATH>", "-e", "options(btw.run_r.enabled=TRUE); mcptools::mcp_server(tools = btw::btw_tools())"],
      "enabled": true
    }
  }
}
```

或用 CLI：`opencode mcp add`。重啟 OpenCode 生效。

### 四種 Agent 對照表

| Agent | 設定檔 | 格式 | `command` 形態 | 重啟後檢視 |
|-------|--------|------|----------------|-----------|
| Claude Code | `~/.claude.json`（或 `claude mcp add`） | JSON | 字串 + args 陣列 | `claude mcp list` |
| ChatGPT Codex | `~/.codex/config.toml` | TOML | 字串 + args 陣列 | `codex mcp` |
| Gemini CLI | `~/.gemini/settings.json` | JSON | 字串 + args 陣列 | `/mcp` |
| OpenCode | `~/.config/opencode/opencode.json` | JSON | **整段陣列** | `opencode mcp list` |

> 共通注意事項：① 路徑含空白（如 `C:\Program Files\...`）在 JSON/TOML 中沒問題，但 shell 直接打要加引號。② 改完設定**一定要重啟 Agent**，MCP 工具是啟動時載入。③ Windows 路徑在 JSON 字串中可用 `C:\\Program Files\\...`（雙反斜線）或 `C:/Program Files/...`。

---

## 5. 如何用自然語言控制 R（使用方式）

設定完成、重啟 Agent 後，**直接用日常語言下指令**即可，Agent 會在背後把需求轉成 R 程式碼、透過 `btw_tool_run_r` 執行、回報結果。範例：

- 「用 R 讀這份 CSV：`D:/data/scores.csv`，做敘述統計」
- 「跑一個線性迴歸，依變數 score，自變數 hours 和 sleep，報告係數和 R²」
- 「對這三組做單因子 ANOVA，加 Tukey 事後檢定」
- 「幫我做獨立樣本 t 檢定比較兩組平均，並檢定變異數同質性」
- 「畫一張散佈圖加迴歸線，存成 PNG 到 `D:/out/plot.png`」

### 給 Agent 的執行守則（重要）

`btw_tool_run_r` 的設計規範，Agent 應遵守：

1. **小步前進**：一次工具呼叫只做一件明確的事。
2. **一次最多一張圖**：多張圖請分多次呼叫。
3. **解釋寫在訊息裡，不要塞進程式碼**：`run_r` 是用來跑程式，不是跟使用者對話。
4. **副作用要先說明**：寫檔、刪檔、網路請求、裝套件、執行 shell 等，**需先取得使用者同意並出示程式碼與目標路徑/網址**。預設工作目錄、options、環境變數會在每次呼叫間重置；暫存請用 `tempfile()`。
5. **錯誤最多修 2 次**：連續 2 次修不好就停下，總結嘗試與錯誤訊息，提出下一步但先不執行。
6. **回傳結構化物件**：讓最後一個運算式就是要顯示的物件（data.frame／list／scalar），少用 `print()`／`cat()`。

### 端到端驗證範例（Palmer Penguins）

這個案例最能體現便利性：R 原生從網路抓資料 → 清理 → 含類別變數的多元迴歸 → ANOVA + 事後檢定 → 出圖，全程自然語言驅動。完整腳本見 [`examples/penguins_demo.R`](examples/penguins_demo.R)，可用以下指令一鍵驗證環境：

```bash
Rscript examples/penguins_demo.R
```

預期重點結果：清理後 333 筆；體重~鰭長+物種迴歸 R²≈0.787；ANOVA F≈342（p<2.2e-16），Tukey 顯示 Gentoo 顯著重於另兩種、Adelie 與 Chinstrap 無顯著差異。

---

## 6. 疑難排解（本流程實際踩過的坑）

| 症狀 | 原因 | 解法 |
|------|------|------|
| `'lib = ...' is not writable` | Windows 寫入 Program Files 需管理員 | 裝到個人套件庫 `R_LIBS_USER`（見 §2） |
| `'\U' used without hex digits` | R 字串把 `\U`（Windows 路徑）當 Unicode 跳脫 | 路徑改用正斜線 `C:/...` |
| 透過 Bash 跑 R 出現 `Segmentation fault` | shell 跳脫把 R 程式碼弄壞 | 把程式寫成 `.R` 檔再執行，或用原生終端機（PowerShell） |
| Agent 看不到 R 的工具 | MCP 工具在 Agent **啟動時**載入 | 改完設定**重啟 Agent** |
| 工具裡只有 `list_r_sessions`/`select_r_session`，沒有 `run_r` | server 沒掛 `btw` 工具，或 `run_r` 未啟用 | 用 §4 的完整指令（含 `options(btw.run_r.enabled=TRUE)` 與 `tools = btw::btw_tools()`） |
| `run_r` 不在 `btw_tools()` 裡 | 預設關閉 | 啟用（§3）；並確認 `evaluate` 已裝 |
| 背景無頭 `mcp_session()` 連不上 | 非互動 Rscript 跑完就結束，沒有事件迴圈 | 本方案**不需要** session；直接用 server 掛工具即可（§4）。若真要 live session bridge，需在互動式 RStudio 執行 `mcptools::mcp_session()` |
| `Install the {gh} package...` 警告 | btw 的 GitHub 工具選配相依 | 無害可忽略；要消除可 `install.packages('gh')` |

---

## 7. 進階：連到「你正在用的 RStudio」（選配）

若你希望 Agent 接管你**開著的 RStudio session**（看得到你已載入的資料框、變數），這是 mcptools 的另一種模式：

1. server 端設定維持 §4（已含 `session_tools`）。
2. 在 RStudio 的 Console 執行：`mcptools::mcp_session()`（或 `btw::btw_mcp_session()`，兩者等價）。
3. 對 Agent 說「列出 R sessions」→ 它會用 `list_r_sessions` 看到你的 session，再 `select_r_session` 選定。

注意：此模式需要**互動式**的 R session（RStudio 會持續運轉事件迴圈）；用 `Rscript` 在背景無頭啟動會因程序結束而失敗。一般「請 Agent 幫我跑分析」用 §4 的 server 模式即可，最穩定。

---

## 參考來源

- mcptools（Posit 官方）：<https://github.com/posit-dev/mcptools>
- btw 套件：<https://posit-dev.github.io/btw/>
- Claude Code MCP：<https://docs.claude.com/en/docs/claude-code/mcp>
- OpenAI Codex MCP：<https://developers.openai.com/codex/mcp>
- Gemini CLI MCP：<https://google-gemini.github.io/gemini-cli/docs/tools/mcp-server.html>
- OpenCode MCP：<https://opencode.ai/docs/mcp-servers/>
- Palmer Penguins 資料：<https://github.com/allisonhorst/palmerpenguins>

---

*本說明書由實際安裝流程整理而成，驗證環境：Windows 11 Home + R 4.6.0 + Claude Code。歡迎依自身平台調整路徑與套件管理工具。*
