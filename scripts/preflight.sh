#!/usr/bin/env bash
# 环境自检：确认 KVM 可用、腾出磁盘空间。
set -euo pipefail

hr() { printf '%s\n' "------------------------------------------------------------"; }

hr
echo "[1/4] 机器规格"
echo "CPU      : $(nproc) 核 ($(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs))"
echo "内存     : $(free -h | awk '/^Mem:/{print $2}')"
echo "镜像     : ${IMAGE_OS:-unknown}  (${RUNNER_ARCH:-unknown})"
df -h / | tail -1

hr
echo "[2/4] 检查 KVM（没有它 Android 只能软模拟，慢到不可用）"
if [ -e /dev/kvm ]; then
  echo "✓ /dev/kvm 存在"
  sudo chmod 666 /dev/kvm || true
  ls -l /dev/kvm
  if command -v kvm-ok >/dev/null 2>&1; then
    kvm-ok || true
  fi
else
  echo "✗ 这台 runner 没有 /dev/kvm —— Android 起不来。"
  echo "  换 ubuntu-latest 重试；macOS runner 不支持嵌套虚拟化，别用。"
  exit 1
fi

hr
echo "[3/4] 清理预装工具链，给 Android 镜像腾磁盘"
before=$(df -P / | awk 'NR==2{print $4}')
for d in \
  /usr/local/lib/android \
  /usr/share/dotnet \
  /opt/ghc \
  /usr/local/share/powershell \
  /usr/share/swift \
  /usr/local/.ghcup \
  /opt/google/chrome \
  /usr/lib/x86_64-linux-gnu/libgegl-0.4.so.0 ; do
  [ -e "$d" ] && sudo rm -rf "$d" || true
done
sudo apt-get clean || true
sudo docker system prune -a -f || true
after=$(df -P / | awk 'NR==2{print $4}')
echo "可用磁盘：$((before/1024)) MB -> $((after/1024)) MB"

hr
echo "[4/4] Docker"
docker version --format '{{.Server.Version}}'
echo "✓ 自检完成"
