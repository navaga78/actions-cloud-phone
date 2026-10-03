# ☁️ actions-cloud-phone

[简体中文](./README.md) · English

Spin up a **temporary Android cloud phone** on **GitHub Actions' free compute**. Pick an Android version and a device profile, click one button, and a touch-operable Android phone appears in your browser.

> Sibling project to [codespaces-remote-desktop](https://github.com/navaga78/codespaces-remote-desktop) (cloud PC).
> **Why can the cloud PC run on Codespaces but the cloud phone can't?** Android requires host-level KVM hardware virtualization, and Codespaces is a container with no `/dev/kvm`.
> GitHub only guarantees Android hardware acceleration on **Actions Linux runners**, so a cloud phone has to live on Actions.

* * *

## ⚠️ Read this first (important)

Straight from GitHub's Terms for Additional Products, on Actions:

> You may only access and use GitHub Actions to develop and test your application(s).
>
> If using GitHub-hosted runners, any other activity unrelated to the production, testing, deployment, or publication of the software project…

The stated consequences are blunt: **job termination, throttled Actions access, disabled repositories, or account suspension.**

Treat this box as a **throwaway test device on CI**:
✅ UI automation, verifying your APK on a device profile you don't own, opening a mobile-only page
❌ A 24/7 second phone, idle farming, bulk sign-ups, scraping

**A single Actions job caps out at 6 hours and is then killed, with all data gone** — technically it can never be a long-lived cloud phone.
If you want an always-on cloud phone, stop fighting GitHub: a cheap VPS + [ReDroid](https://github.com/remote-android/redroid-doc) is the real answer.

* * *

## 🚀 Three steps

### 1. Fork this repo and make sure it is **Public**

> **Public is required.** Private repos get a 2-core/8GB Linux runner and burn your 2,000 free minutes/month.
> Public repos get **4 cores / 16GB with unlimited minutes**.

### 2. Run the workflow

`Actions` → `Cloud Phone` → `Run workflow`:

| Input | Meaning | Default |
|---|---|---|
| `android` | Android version; free images cover 9.0–14.0 | `13.0` |
| `device` | Device profile (Galaxy S10 / S9 / … / Nexus 5 / Pixel C) | `Samsung Galaxy S10` |
| `duration` | Minutes online, max 350 | `300` |
| `tunnel` | `cloudflared` / `tailscale` / `ngrok` | `cloudflared` |
| `apk_url` | Optional direct APK URL to install after boot | empty |

Or from the CLI:

```bash
gh workflow run cloud-phone.yml -f android=13.0 -f device="Samsung Galaxy S10" -f duration=300
```

### 3. Grab the URL

The first run pulls a large Docker image and boots Android — **expect 5–10 minutes**.
The URL is printed in the job log and pinned at the top of the **Job Summary**. Open it and you have a phone.

* * *

## 🔌 Choosing a tunnel

| Mode | Sign-up | URL shape | Security | Good for |
|---|---|---|---|---|
| `cloudflared` | none | `https://random.trycloudflare.com` | anyone with the URL can drive it | quick one-offs |
| `tailscale` | free account | `http://100.x.y.z:6080` | only your own tailnet | **recommended** |
| `ngrok` | free account | `https://random.ngrok-*.app` | same as cloudflared | existing ngrok users |

For Tailscale, add a `TAILSCALE_AUTHKEY` secret under `Settings → Secrets and variables → Actions`
(generate it in the Tailscale admin console; mark it **reusable / ephemeral**).

* * *

## ❓ FAQ

**Why must the repo be public?**
Public repos get 4 cores / 16GB with no minute billing; private repos get 2 cores / 8GB against your quota. Android emulators are hungry — 2 cores is painful.

**What happens after 6 hours?**
There is no extension. Re-run the workflow, but **everything from the previous run is gone** (the runner VM is destroyed). Don't leave anything important on the phone.

**Can I pick a region / exit-IP country?**
No. Actions assigns the region; unlike Codespaces there is no `WestUs2` / `WestEurope` choice. Use a proxy inside the phone if you need a specific country.

**Android 15 / 16?**
The free `budtmo/docker-android` images stop at **14.0**. Newer versions are the author's paid PRO tier (GitHub Sponsors).

**KVM error on startup?**
The preflight step checks `/dev/kvm`. macOS runners do **not** support nested virtualization — stick to `ubuntu-latest`.

**Out of disk?**
`preflight.sh` removes the preinstalled Android SDK, .NET and GHC to free space. If it still fails, drop to a lower Android version (the 11.0 image is smaller than 14.0).

**Stuck booting?**
Run `docker exec android-container cat device_status` and `docker logs android-container`. Slow first boot is normal.

* * *

## 🧩 How it works

```
browser ──HTTPS──> cloudflared / tailscale ──> noVNC(6080)
                                                  │
                                    docker-android container
                                    (Android emulator + KVM)
                                    runs-on: ubuntu-latest (Actions)
```

## 📄 License

MIT.
