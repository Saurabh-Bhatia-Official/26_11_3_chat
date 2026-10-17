-- ====================================================================
-- SUPABASE POSTGRESQL SCHEMA FOR NEXT-GEN CHAT APPLICATION
-- Supports: Messaging, Safety Guardian, Dynamic Identity, PlayTogether Games
-- ====================================================================

-- 1. Enable UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. USERS TABLE
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(30) UNIQUE,
    avatar_url TEXT,
    bio TEXT,
    status_message VARCHAR(150) DEFAULT 'Available',
    safety_score INT DEFAULT 100,
    theme_preference VARCHAR(50) DEFAULT 'dark_neon',
    app_icon_preference VARCHAR(50) DEFAULT 'neon_pulse',
    is_admin BOOLEAN DEFAULT FALSE,
    is_verified BOOLEAN DEFAULT FALSE,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. USER SESSIONS (Safety Guardian & Multi-device tracking)
CREATE TABLE IF NOT EXISTS user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_name VARCHAR(100) NOT NULL,
    device_os VARCHAR(50) NOT NULL,
    client_type VARCHAR(50) DEFAULT 'Flutter Web',
    ip_address VARCHAR(45) NOT NULL,
    location_estimate VARCHAR(100) DEFAULT 'Unknown Location',
    is_current BOOLEAN DEFAULT FALSE,
    is_blocked BOOLEAN DEFAULT FALSE,
    last_active TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. CONVERSATIONS TABLE (1:1 and Group Chats)
CREATE TABLE IF NOT EXISTS conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(150),
    is_group BOOLEAN DEFAULT FALSE,
    avatar_url TEXT,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    last_message_preview TEXT,
    last_message_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. CONVERSATION MEMBERS TABLE
CREATE TABLE IF NOT EXISTS conversation_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'MEMBER', -- OWNER, ADMIN, MEMBER
    muted BOOLEAN DEFAULT FALSE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(conversation_id, user_id)
);

-- 6. MESSAGES TABLE
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    type VARCHAR(30) DEFAULT 'TEXT', -- TEXT, IMAGE, AUDIO, VIDEO, FILE, GAME_INVITE, SYSTEM
    media_url TEXT,
    media_public_id TEXT, -- Cloudinary public_id
    media_bytes BIGINT,
    reply_to_id UUID REFERENCES messages(id) ON DELETE SET NULL,
    is_edited BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE,
    safety_flagged BOOLEAN DEFAULT FALSE,
    delivery_status VARCHAR(20) DEFAULT 'DELIVERED', -- SENT, DELIVERED, READ
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 7. MESSAGE REACTIONS
CREATE TABLE IF NOT EXISTS message_reactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    emoji VARCHAR(20) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(message_id, user_id, emoji)
);

-- 8. SMART SAFETY GUARDIAN EVENTS
CREATE TABLE IF NOT EXISTS safety_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL, -- SUSPICIOUS_LOGIN, MALICIOUS_LINK, SESSION_TERMINATED, PERMISSION_ALERT, UNKNOWN_DEVICE
    severity VARCHAR(20) DEFAULT 'LOW', -- LOW, MEDIUM, HIGH, CRITICAL
    description TEXT NOT NULL,
    ip_address VARCHAR(45),
    metadata JSONB DEFAULT '{}',
    is_acknowledged BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 9. PLAYTOGETHER GAME ROOMS (Chess, Ludo, Snakes & Ladders)
CREATE TABLE IF NOT EXISTS game_rooms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    game_type VARCHAR(30) NOT NULL, -- CHESS, LUDO, SNAKES_AND_LADDERS
    status VARCHAR(20) DEFAULT 'ACTIVE', -- WAITING, ACTIVE, FINISHED, ABANDONED
    player_white_id UUID REFERENCES users(id) ON DELETE SET NULL, -- Player 1 / Host
    player_black_id UUID REFERENCES users(id) ON DELETE SET NULL, -- Player 2
    turn_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    winner_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    state_json JSONB NOT NULL DEFAULT '{}',
    move_history JSONB DEFAULT '[]',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 10. ADMIN AUDIT LOGS
CREATE TABLE IF NOT EXISTS admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action VARCHAR(100) NOT NULL,
    target_type VARCHAR(50) NOT NULL,
    target_id VARCHAR(100),
    details JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ====================================================================
-- INDEXES FOR MAXIMUM QUERY PERFORMANCE
-- ====================================================================
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_conv_members_user ON conversation_members(user_id);
CREATE INDEX IF NOT EXISTS idx_safety_events_user ON safety_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_game_rooms_conversation ON game_rooms(conversation_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_user ON user_sessions(user_id);

-- ====================================================================
-- SEED DATA FOR DEMO & TESTING
-- ====================================================================
INSERT INTO users (id, username, display_name, email, avatar_url, bio, status_message, safety_score, is_admin, is_verified)
VALUES
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'alex_rivers', 'Alex Rivers', 'alex@chatguard.io', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150', 'Cybersecurity advocate & chess grandmaster ♟️', 'Shields up! 🛡️', 98, TRUE, TRUE),
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'elena_rostova', 'Elena Rostova', 'elena@chatguard.io', 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150', 'Flutter & Spring Boot enthusiast ✨', 'Coding the future 💻', 94, FALSE, TRUE),
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', 'marcus_vance', 'Marcus Vance', 'marcus@chatguard.io', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150', 'Ludo king & board game strategist 🎲', 'Ready for a game! ⚔️', 89, FALSE, FALSE)
ON CONFLICT (username) DO NOTHING;

INSERT INTO conversations (id, title, is_group, created_by, last_message_preview)
VALUES
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44', 'Elena Rostova', FALSE, 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Check out the new Safety Guardian dashboard update!'),
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a55', 'Dev & Security Guild 🚀', TRUE, 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Who is up for a quick Chess match? ♟️')
ON CONFLICT (id) DO NOTHING;

INSERT INTO conversation_members (conversation_id, user_id, role)
VALUES
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'OWNER'),
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'MEMBER'),
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a55', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'OWNER'),
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a55', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'ADMIN'),
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a55', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', 'MEMBER')
ON CONFLICT DO NOTHING;

INSERT INTO messages (id, conversation_id, sender_id, content, type, delivery_status)
VALUES
    ('f0eebc99-9c0b-4ef8-bb6d-6bb9bd380a66', 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'Hey Alex, did you review the Supabase and Cloudinary integrations?', 'TEXT', 'READ'),
    ('f1eebc99-9c0b-4ef8-bb6d-6bb9bd380a77', 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Check out the new Safety Guardian dashboard update! Everything is protected and Cloudinary upload is live.', 'TEXT', 'READ')
ON CONFLICT DO NOTHING;

INSERT INTO safety_events (user_id, event_type, severity, description, ip_address)
VALUES
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'SUSPICIOUS_LOGIN', 'HIGH', 'Blocked suspicious login attempt from unusual geolocation (IP: 198.51.100.23, Riga, Latvia).', '198.51.100.23'),
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'MALICIOUS_LINK', 'MEDIUM', 'Link scanner flagged spoofed URL http://paypa1-security-check.fake with high risk score.', '127.0.0.1'),
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'SESSION_TERMINATED', 'LOW', 'Legacy session on Windows Chrome terminated via Remote Kill Switch.', '172.56.21.89')
ON CONFLICT DO NOTHING;
