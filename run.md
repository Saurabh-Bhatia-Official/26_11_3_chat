# Run Guide: Next-Gen Cross-Platform Chat Application

This guide contains all execution commands for running the **Flutter Frontend**, **Spring Boot Backend**, **Supabase Database**, and deploying to **Vercel**.

---

## 📋 Prerequisites

Ensure you have installed:
- **Java**: 21+ (`java -version`)
- **Maven**: 3.9+ (`mvn -version`)
- **Flutter**: 3.22+ (`flutter --version`)
- **Node.js**: 20+ (`node -v`)

---

## 1. 🚀 Quick Start (Local Development)

### A. Run Spring Boot Backend (Port 8085)
Open a terminal in the root directory:
```bash
cd backend
mvn spring-boot:run
```
> **Note on Port**: Configured to port `8085` by default (avoiding conflicts with existing local web servers like Apache/HTTPD on port 8080). You can also run with custom port: `mvn spring-boot:run -Dspring-boot.run.arguments="--server.port=8085"`.
> 
> Starts automatically with an in-memory H2 database fallback (or Supabase PostgreSQL when credentials are provided in `.env`/`application.yml`). No hardcoded seed profiles are used—new accounts are registered purely on demand.

### B. Run Flutter Client (Web / Chrome)
Open a second terminal:
```bash
cd frontend
flutter run -d chrome
```

### C. Run Flutter Client (Windows Desktop)
```bash
cd frontend
flutter run -d windows
```

---

## 🔐 Real-Time User Authentication & Chatting

The application is completely dynamic with **no hardcoded data** and **equal access for all users**:

### 1. Sign Up & Sign In:
- Open the application in your browser or desktop.
- Switch to the **Create Account** tab and enter a unique **Username**, **Display Name**, and **Password**.
- Click **Create Account & Enter** to register dynamically in the database.

### 2. Starting Conversations with Other Registered Users:
- Click the **`+` (Add Conversation)** button in the top right of the Messages pane.
- A list of all currently registered users fetched from the backend will appear.
- Tap any user to start or resume a private conversation with them immediately.
- Type and send real-time text, voice notes, Cloudinary photos, or launch in-chat games (Chess, Ludo, Snakes & Ladders)!

### 3. Signing Out:
- Click the **Logout icon** at the bottom of the navigation rail to sign out. You can sign in as another user to test conversation exchange.

---

## 2. 🐳 Run via Docker Compose (PostgreSQL + Spring Boot)

To run the PostgreSQL database with the Supabase schema and the Spring Boot backend containerized together:

```bash
# Build and start all services in the background
docker-compose up --build -d

# View live logs
docker-compose logs -f backend

# Stop services
docker-compose down
```

---

## 3. 🚢 Deploy to Vercel

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

## 4. 🗄️ Supabase Database Setup

1. Log in to [Supabase](https://supabase.com) and create a new project.
2. Open the **SQL Editor** in the Supabase Dashboard.
3. Copy and run the SQL commands from:
   ```
   supabase/schema.sql
   ```
4. Add your connection credentials to `backend/src/main/resources/application.yml` or set environment variables:
   ```bash
   export SUPABASE_DB_URL=jdbc:postgresql://db.<PROJECT_REF>.supabase.co:5432/postgres
   export SUPABASE_DB_USER=postgres
   export SUPABASE_DB_PASSWORD=<YOUR_PASSWORD>
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
mvn clean test
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
