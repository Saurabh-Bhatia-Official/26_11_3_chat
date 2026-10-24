# 🚀 ChatGuard CI/CD Pipeline & Release Architecture

This project is configured with an enterprise-grade **GitHub Actions CI/CD pipeline** designed to build, test, package, and release the application across **all major platforms** (macOS, iOS, Windows, Linux, Android, and Web) and deploy to **Vercel**.

---

## 🏗️ Pipeline Architecture Overview

The CI/CD system is organized into **two independent, modular workflow files** in [`.github/workflows/`](file:///c:/Users/ssbha/Desktop/CI_Projects/26_11_3_chat/.github/workflows):

```
.github/
└── workflows/
    ├── deploy-vercel.yml          # Web Frontend & Spring Boot Backend Deployment
    └── build-release-apps.yml     # Multi-Platform Builds (macOS, iOS, Windows, Linux, Android) & GitHub Releases
```

---

## 1. 🌐 Web & Backend Deployment (`deploy-vercel.yml`)

- **File**: [`.github/workflows/deploy-vercel.yml`](file:///c:/Users/ssbha/Desktop/CI_Projects/26_11_3_chat/.github/workflows/deploy-vercel.yml)
- **Triggers**: Automatically on every `push` to `main` impacting frontend or backend files, plus manual trigger (`workflow_dispatch`).
- **Separation**: Runs independently from the desktop and mobile release pipeline.

### Jobs:
1. **Frontend Deployment (`deploy-frontend-vercel`)**:
   - Sets up Flutter (stable) and Node.js 20 on `ubuntu-latest`.
   - Runs Flutter unit and widget tests (`flutter test`).
   - Builds Flutter web production bundle:
     `flutter build web --release`
   - Archives the production bundle as a downloadable GitHub Actions artifact (`frontend-web-production`).
   - Deploys the web bundle to Vercel production using the Vercel CLI.
   - Emits a Markdown deployment summary to `$GITHUB_STEP_SUMMARY`.

2. **Backend Deployment (`deploy-backend-vercel`)**:
   - Sets up Java 21 (Temurin) on `ubuntu-latest`.
   - Compiles and verifies the Spring Boot backend (`mvn test-compile`).
   - Packages the production executable JAR (`mvn package -DskipTests`).
   - Archives `backend/target/chat-backend-1.0.0.jar` as a downloadable GitHub Actions artifact (`backend-spring-boot-jar`).
   - Deploys backend configuration to Vercel using `VERCEL_PROJECT_ID_BACKEND`.
   - Emits a Markdown deployment summary to `$GITHUB_STEP_SUMMARY`.

---

## 2. 📱 Multi-Platform Desktop & Mobile Releases (`build-release-apps.yml`)

- **File**: [`.github/workflows/build-and-release-apps.yml`](file:///c:/Users/ssbha/Desktop/CI_Projects/26_11_3_chat/.github/workflows/build-and-release-apps.yml)
- **Triggers**: Automatically on `push` to `main`, plus manual trigger (`workflow_dispatch`) with custom version tag support.
- **Matrix**: Uses dedicated runners for native operating system compilers.

| Platform | Runner | Build Commands | Output Artifacts |
|:---|:---|:---|:---|
| 🤖 **Android** | `ubuntu-latest` | `flutter build apk --release`<br>`flutter build appbundle --release` | `chatguard-android-release.apk`<br>`chatguard-android-release.aab` |
| 🍎 **iOS** | `macos-14` (Apple Silicon) | `flutter build ios --release --no-codesign` | `chatguard-ios-release.ipa`<br>`chatguard-ios-bundle.zip` |
| 💻 **macOS** | `macos-14` (Apple Silicon) | `flutter config --enable-macos-desktop`<br>`flutter build macos --release` | `chatguard-macos-release.zip` |
| 🪟 **Windows** | `windows-latest` | `flutter config --enable-windows-desktop`<br>`flutter build windows --release`<br>`iscc frontend/windows/installer/inno_setup.iss` | `chatguard-windows-setup.exe` *(Next > Next Setup Wizard)*<br>`chatguard-windows-x64-release.zip` *(Portable)* |
| 🐧 **Linux** | `ubuntu-latest` | `flutter config --enable-linux-desktop`<br>`flutter build linux --release` | `chatguard-linux-x64-release.tar.gz` |

### Consolidated GitHub Release Job (`publish-release`):
- Runs after all 5 platform builds succeed.
- Downloads all artifacts from the 5 parallel runners into a unified directory.
- Calculates cryptographic **SHA-256 checksums** (`SHA256SUMS.txt`) for integrity verification.
- Automatically generates release metadata (`vYYYY.MM.DD-build.<run_number>`).
- Creates an official **GitHub Release** attaching all 5 OS packages and the checksum file.
- Formats a comprehensive Step Summary in the GitHub Actions dashboard.

---

## 🔐 Required Secrets and Environment Variables

Configure these in **GitHub Repository Settings ➔ Secrets and variables ➔ Actions**:

| Secret Name | Purpose | Required / Fallback |
|:---|:---|:---|
| `VERCEL_TOKEN` | Vercel Deployment Authentication Token | Optional (Pipeline archives artifacts if omitted) |
| `VERCEL_ORG_ID` | Vercel Organization / Team ID | Optional |
| `VERCEL_PROJECT_ID_FRONTEND` | Vercel Project ID for the Flutter Web App | Optional |
| `VERCEL_PROJECT_ID_BACKEND` | Vercel Project ID for the Backend | Optional |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded release `.jks` file | Optional (Builds unsigned release APK if omitted) |
| `ANDROID_KEYSTORE_PASSWORD` | Password for the release keystore | Optional |
| `ANDROID_KEY_ALIAS` | Key alias in the keystore | Optional |
| `ANDROID_KEY_PASSWORD` | Key password | Optional |

> [!NOTE]
> All build jobs include safe fallbacks: if custom signing secrets or Vercel tokens are not yet provided, the workflow will **not fail**. It will build standard release binaries, archive them as downloadable artifacts, and notify you clearly in the job summary.

---

## 📊 Error Handling & Failure Reporting

Both workflows include automated failure isolation and reporting:
1. **Concurrency Control**: Automatically cancels outdated runs on subsequent pushes to conserve runner minutes.
2. **Step Summaries (`$GITHUB_STEP_SUMMARY`)**: Every job generates an in-browser Markdown table summarizing build status, commit hash, output file sizes, and deployment URLs.
3. **Artifact Retention**: All compiled packages are retained for 14 days under GitHub Actions artifacts even if a subsequent step encounters an error.
