# Windows 一鍵安裝：R 套件（mcptools + btw）並驗證 run_r 可啟用
# 用法（PowerShell）：./scripts/install.ps1
# 前置：先用 winget 裝好 R（見 README §1）

$ErrorActionPreference = "Stop"

# 找 Rscript
$rscript = (Get-Command Rscript -ErrorAction SilentlyContinue).Source
if (-not $rscript) {
  $cand = Get-ChildItem "C:\Program Files\R" -Directory -ErrorAction SilentlyContinue |
          Sort-Object Name -Descending | Select-Object -First 1
  if ($cand) { $rscript = Join-Path $cand.FullName "bin\Rscript.exe" }
}
if (-not $rscript -or -not (Test-Path $rscript)) {
  Write-Error "找不到 Rscript，請先安裝 R：winget install --id RProject.R"
}
Write-Host "使用 Rscript：$rscript"

# 裝到個人套件庫（免管理員）
& $rscript -e "userlib <- Sys.getenv('R_LIBS_USER'); dir.create(userlib, recursive=TRUE, showWarnings=FALSE); install.packages(c('mcptools','btw'), repos='https://cloud.r-project.org', lib=userlib)"

# 驗證 run_r 可啟用
& $rscript -e "options(btw.run_r.enabled=TRUE); ts <- btw::btw_tools(); cat('工具數:', length(ts), '| 含 run_r:', 'btw_tool_run_r' %in% vapply(ts, function(t) t@name, ''), '\n')"

Write-Host "`n下一步：用 README §4 把 server 註冊給你的 Agent。"
Write-Host "Claude Code 範例："
Write-Host "claude mcp add r-stats --scope user -- `"$rscript`" -e `"options(btw.run_r.enabled=TRUE); mcptools::mcp_server(tools = btw::btw_tools())`""
