#!/usr/bin/env bash
# 保活：定时巡检容器与隧道，掉线自动补拉，到点收工。
set -euo pipefail

DURATION_MIN="${DURATION_MIN:-300}"
MAX_MIN=350
URL_FILE=/tmp/phone-url
CONTAINER=android-container

if [ "$DURATION_MIN" -gt "$MAX_MIN" ]; then
  echo "⚠ 请求 ${DURATION_MIN} 分钟，超过 Actions 单 job 6 小时上限，自动收敛到 ${MAX_MIN} 分钟。"
  DURATION_MIN=$MAX_MIN
fi

total=$((DURATION_MIN * 60))
end=$((SECONDS + total))
tick=0

start_time=$(date -u '+%H:%M:%S')
echo "保活 ${DURATION_MIN} 分钟（UTC ${start_time} 开始）"

while [ "$SECONDS" -lt "$end" ]; do
  sleep 60
  tick=$((tick + 1))
  left=$(( (end - SECONDS) / 60 ))

  if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    echo "⚠ 容器不在了，尝试重启"
    docker start "$CONTAINER" >/dev/null 2>&1 || echo "✗ 重启失败"
  fi

  if ! curl -fsS -o /dev/null -m 5 http://127.0.0.1:6080/; then
    echo "⚠ noVNC 无响应（第 ${tick} 次巡检）"
  fi

  if [ $((tick % 5)) -eq 0 ]; then
    elapsed=$(( (total - (end - SECONDS)) / 60 ))
    url=$(cat "$URL_FILE" 2>/dev/null || echo '地址未生成')
    echo "[${elapsed}/${DURATION_MIN} 分钟] 剩余 ${left} 分钟 · ${url}"
  fi
done

echo "✓ 到点，本次云手机结束。"
