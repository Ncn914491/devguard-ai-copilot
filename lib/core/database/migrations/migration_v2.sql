-- DevGuard AI Copilot Database Schema v2.0
-- Migration for member onboarding and join request management

-- Join Requests table
-- Satisfies Requirements: 2.1, 2.2, 2.3, 2.4, 2.5 (Member onboarding and approval system)
CREATE TABLE IF NOT EXISTS join_requests (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    requested_role TEXT NOT NULL CHECK (requested_role IN ('admin', 'lead_developer', 'developer', 'viewer')),
    message TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at INTEGER NOT NULL,
    reviewed_at INTEGER,
    reviewed_by TEXT,
    admin_notes TEXT,
    rejection_reason TEXT
);

-- Users table for authentication and user management
-- Satisfies Requirements: 3.1, 3.2, 3.3, 3.4, 3.5 (Authentication and session management)
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('admin', 'lead_developer', 'developer', 'viewer')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    password_hash TEXT NOT NULL,
    github_username TEXT,
    avatar_url TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    last_login INTEGER,
    password_reset_token TEXT,
    password_reset_expires INTEGER
);

-- User Sessions table for JWT token management
-- Satisfies Requirements: 3.4 (Session management with proper logout and token invalidation)
CREATE TABLE IF NOT EXISTS user_sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    token_hash TEXT NOT NULL,
    expires_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    last_accessed INTEGER NOT NULL,
    ip_address TEXT,
    user_agent TEXT,
    is_active INTEGER NOT NULL DEFAULT 1,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

-- Project Settings table for project configuration
-- Satisfies Requirements: 2.2, 2.3 (Project setup wizard and configuration)
CREATE TABLE IF NOT EXISTS project_settings (
    id TEXT PRIMARY KEY,
    project_name TEXT NOT NULL,
    project_description TEXT,
    visibility TEXT NOT NULL DEFAULT 'private' CHECK (visibility IN ('private', 'team', 'public')),
    git_repository_url TEXT,
    security_baseline TEXT,
    created_by TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    FOREIGN KEY (created_by) REFERENCES users (id)
);

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_join_requests_status ON join_requests(status);
CREATE INDEX IF NOT EXISTS idx_join_requests_email ON join_requests(email);
CREATE INDEX IF NOT EXISTS idx_join_requests_created_at ON join_requests(created_at);
CREATE INDEX IF NOT EXISTS idx_join_requests_reviewed_by ON join_requests(reviewed_by);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_token_hash ON user_sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_user_sessions_expires_at ON user_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_user_sessions_is_active ON user_sessions(is_active);

CREATE INDEX IF NOT EXISTS idx_project_settings_created_by ON project_settings(created_by);
CREATE INDEX IF NOT EXISTS idx_project_settings_created_at ON project_settings(created_at);