#!/usr/bin/env bash
# 收尾：停掉容器和隧道进程。job 结束 runner 会被销毁，这里只是让日志干净一点。
set +e

echo "停止 Android 容器…"
docker stop android-container >/dev/null 2>&1

echo "停止隧道进程…"
pkill -f cloudflared 2>/dev/null
pkill -f ngrok 2>/dev/null

echo "✓ 已清理。注意：本次运行的所有数据随 runner 一起销毁，不会保留。"
