#!/usr/bin/env bash
# macOS/Linux 一鍵安裝：R 套件（mcptools + btw）並驗證 run_r 可啟用
# 用法：bash scripts/install.sh
# 前置：先裝好 R（macOS: brew install --cask r；Debian/Ubuntu: sudo apt install -y r-base）
set -euo pipefail

if ! command -v Rscript >/dev/null 2>&1; then
  echo "找不到 Rscript，請先安裝 R。" >&2
  exit 1
fi
echo "使用 Rscript：$(command -v Rscript)"

Rscript -e "install.packages(c('mcptools','btw'), repos='https://cloud.r-project.org')"
Rscript -e "options(btw.run_r.enabled=TRUE); ts <- btw::btw_tools(); cat('工具數:', length(ts), '| 含 run_r:', 'btw_tool_run_r' %in% vapply(ts, function(t) t@name, ''), '\n')"

cat <<'EOF'

下一步：用 README §4 把 server 註冊給你的 Agent。
Claude Code 範例：
  claude mcp add r-stats --scope user -- "$(command -v Rscript)" -e "options(btw.run_r.enabled=TRUE); mcptools::mcp_server(tools = btw::btw_tools())"
EOF
