# Claude Code — r-stats MCP 設定

把 `<RSCRIPT_PATH>` 換成你的 Rscript 完整路徑。

## 方式 A：CLI 一行（推薦）

```bash
claude mcp add r-stats --scope user -- "<RSCRIPT_PATH>" -e "options(btw.run_r.enabled=TRUE); mcptools::mcp_server(tools = btw::btw_tools())"
```

Windows 實例：

```powershell
claude mcp add r-stats --scope user -- "C:\Program Files\R\R-4.6.0\bin\Rscript.exe" -e "options(btw.run_r.enabled=TRUE); mcptools::mcp_server(tools = btw::btw_tools())"
```

## 方式 B：手動編輯 ~/.claude.json

```json
{
  "mcpServers": {
    "r-stats": {
      "command": "C:/Program Files/R/R-4.6.0/bin/Rscript.exe",
      "args": ["-e", "options(btw.run_r.enabled=TRUE); mcptools::mcp_server(tools = btw::btw_tools())"]
    }
  }
}
```

## 驗證

```bash
claude mcp list      # 應顯示 r-stats: ... ✓ Connected
```

設定後**重啟 Claude Code**，`btw_tool_run_r` 等工具才會載入。
