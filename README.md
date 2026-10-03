# ☁️ actions-cloud-phone

[English](./README.en.md) · 简体中文

用 **GitHub Actions 的免费算力**开一台**临时 Android 云手机**：选好 Android 版本和机型 → 点一下按钮 → 浏览器里出现一台可以触摸操作的安卓手机。

> 本项目是 [codespaces-remote-desktop](https://github.com/navaga78/codespaces-remote-desktop)（云电脑）的姊妹篇。
> **为什么云电脑能用 Codespaces、云手机却不行？** 因为 Android 必须要宿主机的 KVM 硬件虚拟化，而 Codespaces 是容器、没有 `/dev/kvm`。
> GitHub 官方只在 **Actions 的 Linux runner** 上承诺支持 Android 硬件加速，所以云手机只能走 Actions。

* * *

## ⚠️ 先说清楚定位（重要）

GitHub 附加产品条款里关于 Actions 的原文：

> You may only access and use GitHub Actions to develop and test your application(s).
>
> If using GitHub-hosted runners, any other activity unrelated to the production, testing, deployment, or publication of the software project…

违规后果写得很直白：**终止 job、限制 Actions 能力、禁用仓库、甚至封号**。

所以请把这台机器当 **「CI 上的临时测试机 / 远程调试机」** 用，随开随弃：
✅ 跑自动化 UI 测试、验证 APK 在你没有的机型上的表现、临时抓个只能在手机上打开的页面
❌ 当成 7×24 在线的第二台手机、挂机、批量注册、爬数据

**Actions 单 job 最长 6 小时，到点强杀，数据全没** —— 这在技术上就注定了它做不了长期云手机。
如果你要的是长期在线的云手机，别跟 GitHub 较劲，一台低配 VPS + [ReDroid](https://github.com/remote-android/redroid-doc) 是正解。

* * *

## 🚀 三步开始

### 第 1 步：Fork 本仓库，并确认它是 **Public**

> **必须公开仓库。** 私有仓库的 Linux runner 只有 2 核 8G，而且要吃你每月 2000 分钟的免费额度；
> 公共仓库是 **4 核 16G、分钟数不限**。

### 第 2 步：跑一次 workflow

`Actions` → `Cloud Phone` → `Run workflow`，填参数：

| 参数 | 说明 | 默认 |
|---|---|---|
| `android` | Android 版本，免费镜像支持 9.0~14.0 | `13.0` |
| `device` | 机型（Galaxy S10 / S9 / … / Nexus 5 / Pixel C） | `Samsung Galaxy S10` |
| `duration` | 在线分钟数，上限 350 | `300` |
| `tunnel` | `cloudflared` / `tailscale` / `ngrok` | `cloudflared` |
| `apk_url` | 可选，开机后自动安装的 APK 直链 | 空 |

也可以命令行：

```bash
gh workflow run cloud-phone.yml -f android=13.0 -f device="Samsung Galaxy S10" -f duration=300
```

### 第 3 步：拿地址

首次要拉一个较大的 Docker 镜像 + 等 Android 开机，**大约 5~10 分钟**。
就绪后地址会打印在日志里，也会出现在 **Job Summary** 页面顶部，点开就是手机屏幕。

* * *

## 🔌 三种穿透方式怎么选

| 方式 | 要不要注册 | 地址形态 | 安全性 | 适合 |
|---|---|---|---|---|
| `cloudflared` | 不需要 | `https://随机.trycloudflare.com` | 随机域名，知道地址就能操作 | 临时用、图省事 |
| `tailscale` | 需要（免费） | `http://100.x.y.z:6080` | 只有你自己的 tailnet 能访问 | **推荐**，长期用 |
| `ngrok` | 需要（免费） | `https://随机.ngrok-*.app` | 同 cloudflared | 已经有 ngrok 账号 |

用 tailscale 的话，在仓库 `Settings → Secrets and variables → Actions` 里加一个 `TAILSCALE_AUTHKEY`
（在 Tailscale 后台生成，**记得勾 reusable / ephemeral**）。

* * *

## 🧰 能用它干什么

- 浏览器里直接**触摸操作**安卓（noVNC 支持鼠标模拟触摸和滑动）
- `apk_url` 传直链自动装 APK；也可以连上后用容器里的 adb 手动装
- 想跑自动化测试：把 Appium / Espresso 脚本塞进 workflow 的 `保持在线` 步骤之前即可

进阶：容器里 `adb` 在 `$HOME/android-sdk/platform-tools`，可以
`docker exec android-container bash -lc 'adb shell ...'` 直接下命令。

* * *

## ❓ 常见问题

**Q：为什么必须是公共仓库？**
GitHub 给公共仓库的 Linux runner 是 4 核 16G 且不计时；私有仓库是 2 核 8G 且消耗额度。Android 模拟器吃资源，2 核会非常卡。

**Q：6 小时到了怎么办？**
没法续。只能重新 `Run workflow`，但**上一次的所有数据都没了**（runner 销毁）。所以重要东西别留在手机里。

**Q：能不能指定机房 / 出口 IP 国家？**
不能。Actions runner 的机房由 GitHub 分配，不像 Codespaces 可以选 `WestUs2` / `WestEurope`。需要特定国家的出口 IP 只能在云手机里挂代理。

**Q：能不能跑 Android 15 / 16？**
免费镜像 `budtmo/docker-android` 只到 **14.0**。15 及以上是作者的付费 PRO 版（需 GitHub Sponsors）。

**Q：启动失败，日志里说 KVM 相关？**
`环境自检` 那一步会检查 `/dev/kvm`。macOS runner **不支持嵌套虚拟化**，别选；只用 `ubuntu-latest`。

**Q：磁盘不够？**
`preflight.sh` 会删掉 runner 预装的 Android SDK / .NET / GHC 等大件腾空间。如果还报 No space left on device，把 Android 版本调低（11.0 镜像比 14.0 小）。

**Q：开机一直转圈？**
`docker exec android-container cat device_status` 看状态，`docker logs android-container` 看日志。冷启动首次开机慢是正常的。

* * *

## 🧩 工作原理

```
浏览器 ──HTTPS──> cloudflared / tailscale ──> noVNC(6080)
                                                  │
                                    docker-android 容器
                                    （Android 模拟器 + KVM）
                                    runs-on: ubuntu-latest（Actions）
```

- `.github/workflows/cloud-phone.yml`：参数化的 `workflow_dispatch`，单 job 上限 360 分钟
- `scripts/preflight.sh`：检查 `/dev/kvm`、清理预装工具链腾磁盘
- `scripts/boot-android.sh`：拉镜像 → `--device /dev/kvm` 起容器 → 轮询 `device_status` 等开机 → 可选装 APK
- `scripts/tunnel.sh`：三种穿透，把地址写进日志和 Job Summary
- `scripts/keepalive.sh`：每分钟巡检，掉线自动补拉，到点收工
- `scripts/teardown.sh`：收尾

## 📄 License

MIT。
