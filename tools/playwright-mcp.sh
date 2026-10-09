#!/usr/bin/env bash
# Starts Microsoft's Playwright MCP server (npm: @playwright/mcp) over stdio.
# Auto-detects the cloud container setup: the agent proxy, the preinstalled Chromium,
# and root (needs --no-sandbox). On a normal laptop none of the extras are added.
args=(--headless --isolated --browser chromium)
if [ -x /opt/pw-browsers/chromium ]; then args+=(--executable-path /opt/pw-browsers/chromium); fi
if [ -n "${HTTPS_PROXY:-}" ]; then
  px="${HTTPS_PROXY#*://}"; px="http://${px#*@}"      # drop any credentials from the URL
  args+=(--proxy-server "$px")
fi
if [ "$(id -u)" = "0" ]; then args+=(--no-sandbox); fi
exec npx -y @playwright/mcp@latest "${args[@]}" "$@"
