#!/usr/bin/env bash
# 把容器里的 noVNC(127.0.0.1:6080) 暴露到公网。
# Actions 没有 Codespaces 那种内置端口转发，这一步必须自己做。
set -euo pipefail

TUNNEL="${TUNNEL:-cloudflared}"
PORT=6080
URL_FILE=/tmp/phone-url
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"

hr() { printf '%s\n' "------------------------------------------------------------"; }

publish() {
  local url="$1" note="$2"
  echo "$url" > "$URL_FILE"
  hr
  echo "================ 云手机已就绪 ================"
  echo "  $url"
  echo "=============================================="
  echo "  $note"
  hr
  {
    echo "## 云手机地址"
    echo
    echo "**[$url]($url)**"
    echo
    echo "$note"
  } >> "$SUMMARY"
}

case "$TUNNEL" in
cloudflared)
  hr
  echo "启动 Cloudflare 快速隧道（无需注册账号）"
  curl -fsSL -o /tmp/cloudflared \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
  chmod +x /tmp/cloudflared
  setsid nohup /tmp/cloudflared tunnel \
    --url "http://127.0.0.1:${PORT}" \
    --no-autoupdate --protocol http2 \
    > /tmp/cloudflared.log 2>&1 &
  url=""
  for _ in $(seq 1 60); do
    url=$(grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' /tmp/cloudflared.log | head -1 || true)
    [ -n "$url" ] && break
    sleep 3
  done
  [ -n "$url" ] || { echo "✗ 隧道未拿到地址："; cat /tmp/cloudflared.log; exit 1; }
  publish "$url" "随机域名，别转发给别人；不想用了直接在 Actions 页面 Cancel workflow。"
  ;;

tailscale)
  hr
  echo "接入 Tailscale（私密，只有你自己的 tailnet 能访问）"
  if [ -z "${TAILSCALE_AUTHKEY:-}" ]; then
    echo "✗ 缺少 TAILSCALE_AUTHKEY。在仓库 Settings → Secrets and variables → Actions 里加一个。"
    exit 1
  fi
  curl -fsSL https://tailscale.com/install.sh | sh
  sudo tailscale up --authkey="$TAILSCALE_AUTHKEY" \
    --hostname="cloud-phone-${GITHUB_RUN_ID:-local}" \
    --advertise-exit-node=false --accept-routes=false
  ip=$(tailscale ip -4 | head -1)
  [ -n "$ip" ] || { echo "✗ 没拿到 Tailscale IP"; exit 1; }
  publish "http://${ip}:${PORT}" "仅你的 tailnet 内可见，比公网隧道安全。手机/电脑装了 Tailscale 就能直连。"
  ;;

ngrok)
  hr
  echo "启动 ngrok"
  if [ -z "${NGROK_TOKEN:-}" ]; then
    echo "✗ 缺少 NGROK_TOKEN。在仓库 Settings → Secrets 里加一个。"
    exit 1
  fi
  curl -fsSL -o /tmp/ngrok.tgz https://bin.ngrok-agent.com/v3/stable/ngrok-stable-linux-amd64.tgz
  sudo tar -C /usr/local/bin -xzf /tmp/ngrok.tgz ngrok
  ngrok config add-authtoken "$NGROK_TOKEN"
  setsid nohup ngrok http "$PORT" --log=stdout > /tmp/ngrok.log 2>&1 &
  url=""
  for _ in $(seq 1 40); do
    url=$(curl -fsS http://127.0.0.1:4040/api/tunnels \
      | grep -oE 'https://[a-zA-Z0-9.-]+\.ngrok[a-zA-Z0-9.-]*' | head -1 || true)
    [ -n "$url" ] && break
    sleep 3
  done
  [ -n "$url" ] || { echo "✗ ngrok 未拿到地址："; tail -50 /tmp/ngrok.log; exit 1; }
  publish "$url" "免费版每次重启域名都会变。"
  ;;

*)
  echo "✗ 未知穿透方式：$TUNNEL"
  exit 1
  ;;
esac
