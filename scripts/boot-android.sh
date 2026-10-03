#!/usr/bin/env bash
# 拉起 docker-android 容器并等它开机完成。
set -euo pipefail

ANDROID_VERSION="${ANDROID_VERSION:-13.0}"
DEVICE="${DEVICE:-Samsung Galaxy S10}"
APK_URL="${APK_URL:-}"
IMAGE="budtmo/docker-android:emulator_${ANDROID_VERSION}"
CONTAINER=android-container
BOOT_TIMEOUT=${BOOT_TIMEOUT:-900}

hr() { printf '%s\n' "------------------------------------------------------------"; }

hr
echo "镜像 : $IMAGE"
echo "机型 : $DEVICE"

hr
echo "[1/3] 拉取镜像（体积较大，首次约 3 - 8 分钟）"
for i in 1 2 3; do
  if docker pull "$IMAGE"; then break; fi
  echo "拉取失败，第 $i 次重试…"
  sleep 10
done

hr
echo "[2/3] 启动容器"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker run -d \
  --name "$CONTAINER" \
  --device /dev/kvm \
  --shm-size 2g \
  -p 6080:6080 \
  -e "EMULATOR_DEVICE=${DEVICE}" \
  -e "WEB_VNC=true" \
  -v android-data:/home/androidusr \
  "$IMAGE"

hr
echo "[3/3] 等待 Android 开机（最多 ${BOOT_TIMEOUT}s）"
deadline=$((SECONDS + BOOT_TIMEOUT))
ready=0
while [ "$SECONDS" -lt "$deadline" ]; do
  status=$(docker exec "$CONTAINER" cat device_status 2>/dev/null || echo "")
  if curl -fsS -o /dev/null -m 5 http://127.0.0.1:6080/ 2>/dev/null; then
    if echo "$status" | grep -qiE "ready|running|booted"; then
      ready=1
      echo "✓ Android 已就绪：$status"
      break
    fi
  fi
  printf '.'
  sleep 10
done
echo

if [ "$ready" -ne 1 ]; then
  echo "✗ 开机超时，最后一段容器日志："
  docker logs --tail 200 "$CONTAINER" || true
  docker exec "$CONTAINER" cat device_status 2>/dev/null || true
  exit 1
fi

if [ -n "$APK_URL" ]; then
  hr
  echo "安装 APK：$APK_URL"
  apk=/tmp/app.apk
  if curl -fsSL -m 300 -o "$apk" "$APK_URL"; then
    docker cp "$apk" "$CONTAINER":/tmp/app.apk
    docker exec "$CONTAINER" bash -lc \
      'export PATH="$HOME/android-sdk/platform-tools:$PATH"; adb install -r /tmp/app.apk' \
      || echo "⚠ APK 安装失败（不影响手机本身，可连上后手动装）"
  else
    echo "⚠ APK 下载失败，跳过"
  fi
fi

hr
echo "✓ 云手机已启动，noVNC 监听在 127.0.0.1:6080"
