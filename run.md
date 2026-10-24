# Run Guide: Next-Gen Cross-Platform Chat Application

This guide contains all execution commands for running the **Flutter Frontend**, **Spring Boot Backend**, **Neon PostgreSQL Database**, and deploying to **Vercel**.

---

## 📋 Prerequisites

- **Java & Maven**: **Pre-bundled inside the project** (`backend/.jdk` and `mvnw`). No external JDK installation or `JAVA_HOME` configuration required!
- **Flutter**: 3.22+ (`flutter --version`) for running the frontend.
- **Node.js**: 20+ (`node -v`) *(Optional, for Vercel deployment CLI)*.

---

## 1. 🚀 Quick Start (Local Development)

### ⚡ One-Click Activate & Run All Services:
Launch both the **Spring Boot Backend** and **Flutter Frontend** simultaneously in separate windows:

- **Windows Batch (Command Prompt or double-click)**:
  ```cmd
  run.bat
  ```
- **Windows PowerShell**:
  ```powershell
  .\run.ps1
  ```
*(Or launch individually via `run-backend.bat` and `run-frontend.bat`)*

---

### A. Run Spring Boot Backend (Port 8085)

The project includes an embedded project-local JDK and Maven Wrapper, so **no external `JAVA_HOME` configuration or system variables are required**.

#### 1. Active One-Line Command (Windows CMD):
```cmd
cd backend && mvnw.cmd spring-boot:run
```

#### 2. Active One-Line Command (Windows PowerShell):
```powershell
cd backend; .\mvnw spring-boot:run
```

#### 3. Standard Command (macOS / Linux):
```bash
cd backend && ./mvnw spring-boot:run
```

#### 4. Active Profile Activation (e.g. dev, prod):
To activate a specific Spring Boot profile:
```bash
cd backend && .\mvnw spring-boot:run -Dspring-boot.run.profiles=prod
```
Or override custom port and active profile simultaneously:
```bash
cd backend && .\mvnw spring-boot:run -Dspring-boot.run.arguments="--spring.profiles.active=dev --server.port=8085"
```

#### 5. Run as Standalone JAR (Production Mode):
```bash
cd backend
mvn clean package -DskipTests
java -jar target/chat-backend-1.0.0.jar
```

#### 6. Verify Backend is Running:
- **Live Render Cloud Backend**: [https://two6-11-3-chat.onrender.com/api/system/branding](https://two6-11-3-chat.onrender.com/api/system/branding)
- **Local Dev Server**: [http://localhost:8085/api/auth/users](http://localhost:8085/api/auth/users)
- **cURL / Bash (Live Cloud)**:
  ```bash
  curl https://two6-11-3-chat.onrender.com/api/system/branding
  ```

> **Database Connection**: Strictly connects to the cloud **Neon PostgreSQL** database configured in `application.yml` and environment variables. Local database has been completely removed.

---

### B. Run Flutter Client (Web / Chrome)

#### 1. Active One-Line Command (Web - Chrome):
```bash
cd frontend && flutter run -d chrome --dart-define-from-file=.env
```
> *(Or double-click `run-frontend.bat` or run `cd frontend && flutter run -d chrome`)*

### C. Run Flutter Client (Windows Desktop)

#### 1. Active One-Line Command (Windows Desktop):
```bash
cd frontend && flutter run -d windows --dart-define-from-file=.env
```

---

## 🔐 Real-Time User Authentication, Calling & Media

The application is completely dynamic with **credential persistence**, **voice/video calls**, **controlled image picking**, and **username-only search**:

### 1. Persistent Login & Sign In:
- Open the application in your browser or desktop.
- Switch to the **Create Account** tab to register or **Sign In** with your existing credentials.
- The **"Remember my login on this device"** option saves session state securely locally in `SharedPreferences`. Returning to the app keeps you logged in automatically, and credentials auto-fill on the sign-in form.
- Tap **Sign In to Chat** to enter.

### 2. Username-Only Search & Dynamic Conversations:
- **Starting a Chat**: Click the **`+` (Add Conversation)** button in the top right of the Messages pane.
- Use the **Search username** bar (e.g. `@alice` or `bob`). It searches **strictly by username**, ignoring display names.
- Selecting a user automatically checks if a chat already exists; if found, it selects and opens the existing conversation dynamically without duplicating.
- **Filtering Messages**: The search bar at the top of the conversation list also searches strictly by `@username`.

### 3. Image Picker (Without Auto-Uploading):
- Tap the **Image icon** (`📷`) or select **"Choose Image from Device"** from the attach menu.
- Pick any image from your computer. The image is **not uploaded automatically**.
- An **image preview banner** appears directly above the text input showing the thumbnail, filename, file size, and a **`[X]` discard button**.
- Add an optional text caption and tap **Send**. The image is uploaded only at that moment and sent to the conversation.

### 4. Avatar Upload & Instant Device Preview:
- Navigate to **Identity Settings** (`🎨` icon in the navigation rail).
- Click **"Upload from Device"** or **"Change Avatar"** to select an avatar directly from your local storage.
- Supports **JPG**, **PNG**, and **WEBP** formats.
- Provides instant preview in the circular avatar with real-time feedback and dynamic upload to the backend.
- Tap **"Remove"** to clear the custom avatar and revert to initials badge.
- All preset/demo avatar photos have been removed.

### 5. Real Voice Recording & Voice Messaging:
- In any chat, tap the **Microphone icon** (`🎤`) next to the message composer.
- The app requests browser microphone permissions and opens the active recording bar with:
  - Pulsing **🔴 REC** indicator and live elapsed timer (`00:00`).
  - Dynamic audio waveform animation.
  - **Discard** (`🗑️`) button to cancel and release the microphone.
  - **"Stop & Review"** button to finalize the recording.
- Once stopped, an audio preview bar appears:
  - Play / Pause preview with progress slider and file size badge.
  - **`[X]` Discard** button to delete before sending.
- Tap **Send** (`➤`) to upload the recorded audio bytes and send an interactive voice message bubble into the chat.
- In-chat voice bubbles feature an interactive player with play/pause, live audio progress bar, and duration timestamp.

### 6. Phone & Video Call Services:
- In any chat, tap the **Phone icon** (`📞`) for an audio call or the **Video icon** (`📹`) for a video call.
- The call begins with a **"Calling / Ringing..."** connecting state, then transitions into an active call with live duration timer and **WebRTC Encrypted HD** badge.
- Includes in-call controls: **Mute Microphone**, **Toggle Camera**, **Speakerphone**, **Share Screen**, and **End Call**.
- When ended, a call duration summary is automatically logged as a system message in the chat history (e.g. `📞 Voice call ended • 01:23`).

### 7. Dynamic Software & Home Icon Customization:
- Navigate to **Identity Settings** (`🎨` icon in the navigation rail).
- Under **Approved Launcher Icon Choices**, choose any icon style:
  - **Neon Pulse** (`⚡`, Cyan)
  - **Cyber Shield** (`🛡️`, Emerald)
  - **Cosmic Night** (`🌙`, Violet)
  - **Solar Flare** (`🔥`, Amber)
- The chosen icon immediately transforms the **Home App Logo** at the top of the Navigation Rail, the active **Home/Chats** navigation tab, the **Messages Header**, and the central placeholder across the entire software.
- The icon preference is persisted locally in `SharedPreferences` and synchronized to the user's backend profile.

### 8. PlayTogether In-Chat Games (Single Live Card & Username Turn Enforcement):
- **Cloud-Hosted Game Image Assets**: All game banners, interactive dice faces (1-6), and game launcher preview posters are dynamically loaded from high-speed cloud CDNs (Unsplash & Wikimedia Commons CDN) via `GameCloudAssets` and `CloudGameImage`, delivering high-definition visuals with graceful fallback.
- **Single Live Game Card in Chat**: All moves and dice rolls no longer flood the conversation with duplicate turn bubbles. The chat timeline cleanly displays regular conversation messages alongside a **single, live game card** that updates dynamically in place.
- **Real-Time Live Status**: The game card clearly displays the game type, current score or move, winner announcements, and which user is currently up to play.
- **Strict Username Turn Enforcement**:
  - Each player is mapped strictly to their system `@username` (e.g. `@alice` as RED / Player 1, `@bob` as GREEN / Player 2).
  - Only the user whose turn it actually is (`isMyTurn`) can roll the dice or move pieces on the board.
  - When it is the opponent's turn, the roll button is disabled with a clear `"Wait (@opponent)"` label, preventing out-of-turn actions.

### 9. Signing Out:
- Click the **Logout icon** at the bottom of the navigation rail to clear the active session and return to the login screen.

---

## 2. 🚢 Deploy to Vercel

The Flutter web app is pre-configured with `vercel.json` for single-page routing and caching.

### Step 1: Build the Flutter Web Release Bundle
```bash
cd frontend
flutter build web --release
cd ..
```

### Step 2: Deploy to Vercel via CLI
```bash
# Deploy preview build
npx vercel

# Deploy directly to production
npx vercel --prod
```

### Step 3 (Alternative): Deploy via GitHub / Vercel Web Dashboard
1. Push your repository to GitHub:
   ```bash
   git push origin main
   ```
2. In the [Vercel Dashboard](https://vercel.com/new), select **Import Git Repository**.
3. Set the **Output Directory** to:
   ```
   frontend/build/web
   ```
4. Click **Deploy**.

---

## 3. 🌐 Separate Environment Variables

The project uses dedicated `.env` configuration files located directly inside each subproject:

### A. Backend (`backend/.env` & `backend/.env.example`)
Configures Spring Boot, Neon PostgreSQL, Cloudinary, and Security:
```properties
# Neon PostgreSQL Database
DATABASE_URL=postgresql://neondb_owner:npg_75prOHxhoDCa@ep-morning-hall-a7zmmwgk-pooler.ap-southeast-2.aws.neon.tech/neondb?sslmode=require&channel_binding=require
NEON_DB_URL=jdbc:postgresql://ep-morning-hall-a7zmmwgk-pooler.ap-southeast-2.aws.neon.tech:5432/neondb?sslmode=require
DB_USER=neondb_owner
DB_PASSWORD=npg_75prOHxhoDCa
DB_DRIVER=org.postgresql.Driver

# Cloudinary Cloud Storage (Images, Voice Recordings, Videos, Documents)
CLOUDINARY_CLOUD_NAME=dltpal1gr
CLOUDINARY_API_KEY=868572831331282
CLOUDINARY_API_SECRET=Fjv2tA2TvigvvNRbPNX1BDGiXrU
CLOUDINARY_URL=cloudinary://868572831331282:Fjv2tA2TvigvvNRbPNX1BDGiXrU@dltpal1gr

# Server & Security
PORT=8085
JWT_SECRET=NextGenChatSuperSecretKey2026SecureTokenGeneratorForProductionDeployment98765
CORS_ORIGINS=https://*.vercel.app,http://localhost:3000,http://localhost:8080,http://localhost:8085
```

> **Data Separation Architecture**:
> - **Neon Cloud PostgreSQL**: Sole database. Stores user credentials, message records, group membership, timestamps, and the Cloudinary HTTPS URLs.
> - **Cloudinary**: Sole media & file storage. All image, audio, video, and document binary payloads are uploaded directly to Cloudinary and served via Cloudinary's global CDN.

### B. Frontend (`frontend/.env` & `frontend/.env.example`)
Configures the Flutter client endpoints and feature toggles:
```properties
# Spring Boot Backend API endpoint (Render Cloud Host)
API_BASE_URL=https://two6-11-3-chat.onrender.com/api

# WebSocket STOMP endpoint
WEBSOCKET_URL=https://two6-11-3-chat.onrender.com/ws

# App Settings
APP_NAME=ChatGen Next-Gen
APP_ENV=production
ENABLE_SAFETY_GUARDIAN=true
ENABLE_PLAY_TOGETHER=true
```

---

## 4. 🗄️ Database Setup (Neon Serverless PostgreSQL)

Your Neon cloud database is active, pre-configured, and already migrated with the schema:
```bash
# Neon Connection URI:
DATABASE_URL=postgresql://neondb_owner:npg_75prOHxhoDCa@ep-morning-hall-a7zmmwgk-pooler.ap-southeast-2.aws.neon.tech/neondb?sslmode=require&channel_binding=require

# Or JDBC Format:
NEON_DB_URL=jdbc:postgresql://ep-morning-hall-a7zmmwgk-pooler.ap-southeast-2.aws.neon.tech:5432/neondb?sslmode=require
DB_USER=neondb_owner
DB_PASSWORD=npg_75prOHxhoDCa
```

To view or re-apply the full DDL table structure manually, refer to:
```
database/schema.sql
```

---

## 5. ☁️ Cloudinary Configuration

Set your Cloudinary credentials as environment variables or in `application.yml`:
```bash
export CLOUDINARY_CLOUD_NAME=your_cloud_name
export CLOUDINARY_API_KEY=your_api_key
export CLOUDINARY_API_SECRET=your_api_secret
```

---

## 6. 🧪 Running Tests

### Backend Unit & Integration Tests:
```bash
cd backend
mvnw.cmd clean test
# or in PowerShell: .\mvnw clean test
```

### Flutter Frontend Tests:
```bash
cd frontend
flutter test
```

### Flutter Code Analysis:
```bash
cd frontend
flutter analyze
```
