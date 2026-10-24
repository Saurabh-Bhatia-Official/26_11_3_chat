-- ====================================================================
-- POSTGRESQL SCHEMA FOR NEXT-GEN CHAT APPLICATION (NEON DATABASE)
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
    participant1_id UUID REFERENCES users(id) ON DELETE SET NULL,
    participant1_name VARCHAR(100),
    participant1_avatar TEXT,
    participant2_id UUID REFERENCES users(id) ON DELETE SET NULL,
    participant2_name VARCHAR(100),
    participant2_avatar TEXT,
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
    sender_name VARCHAR(100),
    sender_avatar_url TEXT,
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
    metadata_json TEXT DEFAULT '{}',
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
    state_json TEXT DEFAULT '{}',
    move_history_json TEXT DEFAULT '[]',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ====================================================================
-- INDEXES FOR MAXIMUM QUERY PERFORMANCE
-- ====================================================================
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_conv_members_user ON conversation_members(user_id);
CREATE INDEX IF NOT EXISTS idx_safety_events_user ON safety_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_game_rooms_conversation ON game_rooms(conversation_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_user ON user_sessions(user_id);

