# Next-Gen Cross-Platform Chat Application

A high-performance communication platform implementing the full Product Requirements Document (PRD), built with **Flutter**, **Spring Boot**, **Supabase (PostgreSQL)**, **Cloudinary**, and configured for instantaneous deployment on **Vercel**.

---

## 🌟 Architecture & Differentiating Features

### 1. 🛡️ Smart Safety Guardian (PRD Section 3.1 & 4.5)
- **Live Malicious Link Interceptor**: Heuristic and regex analysis detecting homograph spoofing (`xn--`), brand impersonation (`paypa1`), IP literals, and risky TLDs (`.fake`, `.phish`, `.top`).
- **Safety Posture Gauge**: Calculates dynamic user safety score (0-100%).
- **Active Device Sessions & Remote Kill Switch**: Instantly revoke and terminate active sessions across devices.
- **Emergency Safety Check-In**: Instant broadcast to trusted contacts.
- **Transparent Security Timeline**: Activity history logging suspicious sign-ins, intercepted links, and session terminations.

### 2. 🎨 Dynamic App Identity (PRD Section 3.2 & 4.6)
- **Theme Switcher**: Instant switching between **Obsidian Neon**, **Royal Sapphire**, **Emerald Mint**, and **Minimalist Light**.
- **Launcher Icon Selector**: Approved collection of platform-compliant icons (**Neon Pulse**, **Stealth Slate**, **Emerald Spark**, **Royal Crest**).
- **In-App Identity Customizer**: Change in-app display name, status message, and chat styling with live preview.

### 3. ♟️🎲 PlayTogether In-Chat Games (PRD Section 3.3)
- **Chess**: Full 8x8 interactive chessboard, legal piece selection, turn rotation, captured piece tracking, and move history.
- **Ludo**: 4-quadrant board with rolling 3D-styled animated dice, token path progression, and victory banners.
- **Snakes & Ladders (Saanp-Seedi)**: 100-tile board with snake drops, ladder climbs, multiplayer dice rolling, and celebratory win states.

### 4. 💬 Core Messaging & Cloudinary CDN (PRD Section 4.2)
- One-to-one and group messaging.
- Media sharing backed by **Cloudinary CDN** (images, voice note waveforms, videos, documents).
- Delivery receipts (Sent, Delivered, Read checkmarks).
- In-chat game challenges and replies.

### 5. 📞 Voice & Video Calls (PRD Section 4.3)
- WebRTC end-to-end encrypted call simulation.
- Audio mute, camera toggle, screen-sharing simulation, and live latency indicator.

### 6. ⚙️ Admin & Moderation Console (PRD Section 4.7)
- Realtime system metrics (Users, Messages, Interceptions, Server health).
- Dynamic Feature Flags switchboard (Games, WebRTC Calls, Guardian, Cloudinary).
- User verification and moderation controls.

---

## 📁 Repository Structure

```
├── .env.example              # Environment variables template
├── docker-compose.yml        # Docker orchestrator for Spring Boot & PostgreSQL
├── vercel.json               # Root Vercel deployment configuration
├── prd.md                    # Original Product Requirements Document
├── backend/                  # Spring Boot 3.3 (Java 21/25) Backend
│   ├── pom.xml
│   ├── Dockerfile
│   └── src/main/java/com/chatgen/backend/
│       ├── config/           # WebSocket (STOMP), Cloudinary, Security & CORS
│       ├── controller/       # Auth, Chat, MediaUpload, Safety, Games, Admin
│       ├── model/            # JPA Entities (User, Conversation, Message, SafetyEvent, GameRoom)
│       ├── repository/       # Spring Data Repositories
│       └── service/          # CloudinaryService, SafetyAnalyzerService, GameEngineService
├── frontend/                 # Flutter 3.44 Web/Mobile/Desktop Client
│   ├── pubspec.yaml
│   ├── vercel.json           # Frontend Vercel configuration
│   ├── build/web/            # Pre-compiled production Web bundle ready for Vercel
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/           # Typed Dart models
│   │   ├── services/         # ApiService with live Spring Boot & offline fallback
│   │   ├── theme/            # Multi-mode Glassmorphic design system
│   │   ├── views/            # HomeScreen, ChatView, SafetyGuardian, Identity, Admin
│   │   │   └── games/        # Chess, Ludo, Snakes & Ladders
│   │   └── widgets/          # GlassContainer, AvatarBadge, MessageBubble, CallModal
│   └── test/                 # Test suite (all passing)
└── supabase/
    └── schema.sql            # Full PostgreSQL DDL, RLS policies, indexes, and seed data
```

---

## 🚀 Running Locally

### 1. Spring Boot Backend
```bash
cd backend
mvn clean spring-boot:run
```
The backend starts on `http://localhost:8080` with REST APIs, WebSocket STOMP at `/ws`, and in-memory H2 database (or Supabase PostgreSQL if configured).

### 2. Flutter Client
```bash
cd frontend
flutter run -d chrome
```

---

## ☁️ Supabase Setup
1. Create a project in [Supabase](https://supabase.com).
2. Navigate to the **SQL Editor**.
3. Paste and run the contents of [`supabase/schema.sql`](file:///c:/Users/ssbha/Desktop/CI_Projects/26_11_3_chat/supabase/schema.sql).
4. Copy your database connection string into `backend/src/main/resources/application.yml` or your `.env` file:
   ```env
   SUPABASE_DB_URL=jdbc:postgresql://db.<PROJECT_REF>.supabase.co:5432/postgres
   SUPABASE_DB_USER=postgres
   SUPABASE_DB_PASSWORD=<YOUR_PASSWORD>
   ```

---

## ☁️ Cloudinary Setup
1. Sign up for a free account at [Cloudinary](https://cloudinary.com).
2. Retrieve your **Cloud Name**, **API Key**, and **API Secret** from the dashboard.
3. Configure them in `application.yml` or set environment variables:
   ```env
   CLOUDINARY_CLOUD_NAME=your_cloud_name
   CLOUDINARY_API_KEY=your_api_key
   CLOUDINARY_API_SECRET=your_api_secret
   ```

---

## 🚢 Deploying to Vercel

The Flutter Web application is built into static HTML, JavaScript, and WebAssembly assets (`frontend/build/web/`), which deploy to Vercel in seconds.

### Deploying via Vercel CLI:
```bash
# 1. From the project root:
npx vercel --prod
```

### Deploying via GitHub / Git Integration:
1. Push this repository to GitHub.
2. In the [Vercel Dashboard](https://vercel.com/new), select **Import Git Repository**.
3. Set **Output Directory** to `frontend/build/web`.
4. Deploy!
