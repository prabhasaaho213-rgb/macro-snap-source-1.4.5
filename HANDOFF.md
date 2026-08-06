# MacroSnap — Laptop Handoff Checklist

> **Purpose:** everything needed to continue development on a *new* laptop, with
> the exact source paths from this machine. Last updated: Aug 6, 2026 (v1.4.44+57).

---

## 0. Quick summary of where things stand

| Item | Status |
|---|---|
| Git repo | ✅ Pushed to GitHub, clean working tree |
| Latest release | ✅ **v1.4.44** (APK + AAB) on GitHub |
| Google Sign-In fix | ✅ Play deployment cert (`9b999d83…`) registered in Firebase |
| Cloud backup | ✅ Phase-3 Firestore migration live (no Railway needed) |
| Master backup ZIP | `C:\Users\DELL\Desktop\MacroSnap-FULL-BACKUP.zip` (1.0 GB, 714 files) |

**The only things that do NOT live in git** are the three files in Section 2 —
copy them manually. Everything else the new laptop gets by cloning the repo.

---

## 1. What's already on GitHub (nothing to copy)

Repo: `https://github.com/prabhasaaho213-rgb/macro-snap-source-1.4.5.git`

```bash
git clone https://github.com/prabhasaaho213-rgb/macro-snap-source-1.4.5.git
cd macro-snap-source-1.4.5
git pull          # get latest (currently master is in sync)
```

This includes the app source, `firestore.rules`, `firebase.json`,
`google-services.json` (with the Sign-In fix), tests, and the v1.4.43 release
assets (APK + AAB) at `https://github.com/prabhasaaho213-rgb/macro-snap-source-1.4.5/releases`.

---

## 2. ⚠️ Machine-only files — MUST copy manually

These are **excluded from git on purpose** (secrets + machine paths). Copy them
to the **same paths** on the new laptop.

### 2a. Android signing keystore (critical — cannot build without it)

| From (this laptop) | To (new laptop) |
|---|---|
| `C:\DSP\macro-snap-source-1.4.5\macro-snap-source-1.4.5\android\upload-keystore.jks` | `…\android\upload-keystore.jks` (same repo path) |
| `C:\DSP\macro-snap-source-1.4.5\macro-snap-source-1.4.5\android\key.properties` | `…\android\key.properties` (same repo path) |

`key.properties` points at the keystore — keep both files together in
`android/` and the relative path stays valid. **The keystore password is inside
`key.properties`; do not share it in chats or commits.**

> ⚠️ This keystore signs with SHA-1 `07edf911…`, which is registered in Firebase.
> If you lose it, you can still ship via Play (Play App Signing), but direct APK
> sideloads would break sign-in. Keep a copy in the master backup ZIP.

> 🚀 **Automate the copy:** run `copy-handoff.bat` in the repo root — it detects
> your USB drive and copies all three files (keystore, `key.properties`, service
> account) into a `MacroSnap-Handoff\` folder with size verification.

### 2b. Firebase admin service account (needed for `firebase deploy` / admin ops)

| From (this laptop) | To (new laptop) |
|---|---|
| `C:\Users\DELL\Downloads\macrosnap-cfde3-firebase-adminsdk-fbsvc-3d8eacef5f.json` | anywhere safe (e.g. `Downloads` or `C:\src\`) |

It is also **inside the backup ZIP** (`Downloads/macrosnap-cfde3-firebase-adminsdk-fbsvc-…json`).

### 2c. Play Console signing certificates (reference only, optional)

From: `C:\Users\DELL\Downloads\certificates (1).zip`
(contains `deployment_cert.der`, `hybrid_classical_cert.der`, `hybrid_pqc_cert.der`).
You can always re-download these from Play Console → **App integrity → App signing**.

---

## 3. Toolchain to install on the new laptop

The exact versions/tools used on this machine:

| Tool | Version | This machine's path |
|---|---|---|
| Flutter SDK | 3.44.8 stable | `C:\src\flutter` |
| Dart (bundled with Flutter) | — | `C:\src\flutter\bin\dart` |
| Android SDK | (with build-tools + platform-tools) | `C:\Users\DELL\AppData\Local\Android\Sdk` |
| Java (JDK) | bundled with Android Studio | `C:\Program Files\Android\Android Studio\jbr` |
| Node.js (only for `firebase` CLI) | v24.19.0 | `C:\src\node-v24.19.0-win-x64` |
| Pub cache (pre-downloaded packages) | — | `C:\src\.pub-cache` |

**Fastest path:** copy `C:\src\flutter` and `C:\src\.pub-cache` from this laptop
via USB/network instead of re-downloading (~2 GB). Then install **Android Studio**
(on Windows: `flutter doctor` needs its bundled JBR + SDK).

Environment variables used in every build here:

```bash
export ANDROID_HOME='C:/Users/DELL/AppData/Local/Android/Sdk'
export JAVA_HOME='/c/Program Files/Android/Android Studio/jbr'
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
export PUB_CACHE=/c/src/.pub-cache
```

> First-time build on a fresh SDK: accept Android licenses once —
> `flutter doctor --android-licenses`.

---

## 4. Rebuild commands (exact, from this machine)

```bash
cd <repo>/macro-snap-source-1.4.5   # nested project folder
flutter pub get

# Release APK (sideload users)
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk

# Release AAB (Play Console upload)
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

**Version bumps** happen in `pubspec.yaml`:
`version: 1.4.43+56` → bump both (name + code). **Version codes must increase**
on every Play upload — 55 and 56 are used; next is **57**.

**Firestore rules deploy** (from repo root, where `firebase.json` lives):

```bash
# with Node + firebase-tools, logged in via: firebase login
firebase deploy --only firestore:rules --project macrosnap-cfde3
# or using the service account JSON:
#   GOOGLE_APPLICATION_CREDENTIALS=<path-to-service-account.json> firebase deploy --only firestore:rules
```

---

## 5. Post-setup verification checklist

- [ ] `flutter doctor` → all green (Android toolchain + licenses accepted)
- [ ] `git status` clean, `git pull` up to date
- [ ] `android/key.properties` + `android/upload-keystore.jks` present
- [ ] Build `flutter build apk --release` succeeds
- [ ] Google Sign-In works on a fresh install (Play-delivered build)
- [ ] `firebase deploy --only firestore:rules` succeeds

---

## 6. Security notes

- The master ZIP (`MacroSnap-FULL-BACKUP.zip`) contains **signing keys + admin
  credentials** — treat it as a master secret; store offline.
- Never paste `key.properties` passwords, the service-account JSON, or the
  keystore into chats, commits, or public gists.
- If the old laptop is decommissioned, consider rotating the service account
  key in Google Cloud Console (IAM → Service accounts) afterwards.
