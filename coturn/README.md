# Self-Hosted STUN/TURN Infrastructure Guide for Whisper Chat

This directory provides the production-ready self-hosted **coturn** STUN/TURN server configuration for Whisper Chat's WebRTC audio and video calling system.

---

## 1. Architecture & Security Overview

- **STUN (Session Traversal Utilities for NAT):** Discovers each client's public IP and port to establish direct peer-to-peer media paths.
- **TURN (Traversal Using Relays around NAT):** Securely relays encrypted RTP/RTCP media streams when direct P2P connections are blocked by symmetric NATs or corporate firewalls.
- **Ephemeral Credentials (HMAC-SHA1):** In accordance with the standard TURN REST API (RFC 7635), Whisper Chat never exposes permanent TURN passwords to clients. The Spring Boot backend dynamically computes an expiring username (`<expiry_timestamp>:<user_id>`) and HMAC-SHA1 signature using the shared secret (`COTURN_SECRET`).

---

## 2. Firewall & Port Requirements

Ensure the following firewall / security group rules are open on your server:

| Port | Protocol | Purpose | Direction |
|------|----------|---------|-----------|
| **3478** | UDP & TCP | Standard STUN / TURN signaling | Inbound |
| **5349** | UDP & TCP | Secure TLS/DTLS STUN / TURN | Inbound |
| **49152 - 65535** | UDP | Media relay ports (RTP/RTCP audio & video) | Inbound |

---

## 3. Quickstart Deployment with Docker

### Step 1: Set Environment Variables
In your `.env` file (or host environment):
```bash
COTURN_HOST=turn.yourdomain.com
COTURN_PORT=3478
COTURN_TLS_PORT=5349
COTURN_REALM=whisper.chat
COTURN_SECRET=your_production_random_secret_string_here_32chars
```

### Step 2: Configure External IP
If your coturn server is hosted behind NAT (e.g. AWS EC2, GCP, Azure, or DigitalOcean VPC), edit `turnserver.conf`:
```conf
external-ip=YOUR_PUBLIC_IPV4_ADDRESS
```

### Step 3: Start the Coturn Container
```bash
cd coturn
docker compose -f docker-compose.coturn.yml up -d
```

### Step 4: Verify Coturn Logs
```bash
docker logs -f whisper-coturn
```

---

## 4. Connecting Backend with Coturn

Configure your Whisper Chat Spring Boot backend environment:
```bash
COTURN_HOST=turn.yourdomain.com
COTURN_PORT=3478
COTURN_SECRET=your_production_random_secret_string_here_32chars
```

The Spring Boot backend endpoint `GET /api/calls/turn-credentials` will dynamically issue valid, time-limited TURN configurations to authorized Whisper Chat users.

---

## 5. Testing Your TURN Server

You can test connectivity using the WebRTC Trickle ICE test tool:
1. Open [WebRTC Trickle ICE](https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/) in your browser.
2. Under **STUN or TURN URI**, enter:
   `turn:your-server-ip:3478?transport=udp`
3. Generate a temporary username and password from the Whisper backend or via CLI:
   ```bash
   # Timestamp (e.g. current unix time + 3600)
   TIMESTAMP=$(( $(date +%s) + 3600 ))
   USER="${TIMESTAMP}:testuser"
   PASS=$(echo -n "${USER}" | openssl dgst -sha1 -hmac "whisper_turn_secret_secure_key_2026" -binary | base64)
   echo "Username: $USER"
   echo "Password: $PASS"
   ```
4. Enter the generated username and credential, click **Add Server**, and click **Gather candidates**.
5. Verify that candidate type `relay` is successfully discovered.
