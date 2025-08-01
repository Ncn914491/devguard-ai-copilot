-- DevGuard AI Copilot Database Schema v1.0
-- This file contains the complete database schema for the application

-- Team Members table
-- Satisfies Requirements: 5.1, 5.2, 5.5 (Team management and assignment tracking)
CREATE TABLE IF NOT EXISTS team_members (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('developer', 'admin', 'security_reviewer')),
    status TEXT NOT NULL CHECK (status IN ('active', 'bench', 'offline')),
    assignments TEXT, -- Comma-separated list of task IDs
    expertise TEXT,   -- Comma-separated list of expertise areas
    workload INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

-- Tasks table
-- Satisfies Requirements: 5.4 (Git issues/tasks sync and progress tracking)
CREATE TABLE IF NOT EXISTS tasks (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('feature', 'bug', 'security', 'deployment')),
    priority TEXT NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    status TEXT NOT NULL CHECK (status IN ('pending', 'in_progress', 'review', 'completed', 'blocked')),
    assignee_id TEXT NOT NULL,
    estimated_hours INTEGER NOT NULL DEFAULT 0,
    actual_hours INTEGER NOT NULL DEFAULT 0,
    related_commits TEXT, -- Comma-separated list of commit hashes
    dependencies TEXT,    -- Comma-separated list of task IDs
    created_at INTEGER NOT NULL,
    due_date INTEGER NOT NULL,
    completed_at INTEGER,
    FOREIGN KEY (assignee_id) REFERENCES team_members (id)
);

-- Security Alerts table
-- Satisfies Requirements: 3.2, 3.5, 4.5 (Database breach detection, anomaly alerts)
CREATE TABLE IF NOT EXISTS security_alerts (
    id TEXT PRIMARY KEY,
    type TEXT NOT NULL CHECK (type IN ('database_breach', 'system_anomaly', 'network_anomaly', 'auth_flood')),
    severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    ai_explanation TEXT NOT NULL,
    trigger_data TEXT,
    status TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'investigating', 'resolved', 'false_positive')),
    assigned_to TEXT,
    detected_at INTEGER NOT NULL,
    resolved_at INTEGER,
    rollback_suggested INTEGER NOT NULL DEFAULT 0,
    evidence TEXT
);

-- Audit Logs table
-- Satisfies Requirements: 9.1, 9.2, 9.4, 9.5 (Complete audit logging and transparency)
CREATE TABLE IF NOT EXISTS audit_logs (
    id TEXT PRIMARY KEY,
    action_type TEXT NOT NULL,
    description TEXT NOT NULL,
    ai_reasoning TEXT,
    context_data TEXT,
    user_id TEXT,
    timestamp INTEGER NOT NULL,
    requires_approval INTEGER NOT NULL DEFAULT 0,
    approved INTEGER DEFAULT 0,
    approved_by TEXT,
    approved_at INTEGER
);

-- Deployments table
-- Satisfies Requirements: 7.1, 7.4 (Deployment tracking and rollback management)
CREATE TABLE IF NOT EXISTS deployments (
    id TEXT PRIMARY KEY,
    environment TEXT NOT NULL CHECK (environment IN ('development', 'staging', 'production')),
    version TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'in_progress', 'success', 'failed', 'rolled_back')),
    pipeline_config TEXT,
    snapshot_id TEXT,
    deployed_by TEXT NOT NULL,
    deployed_at INTEGER NOT NULL,
    rollback_available INTEGER NOT NULL DEFAULT 1,
    health_checks TEXT,
    logs TEXT
);

-- Snapshots table
-- Satisfies Requirements: 7.1, 7.2, 7.4 (Rollback snapshots and system integrity)
CREATE TABLE IF NOT EXISTS snapshots (
    id TEXT PRIMARY KEY,
    environment TEXT NOT NULL,
    git_commit TEXT NOT NULL,
    database_backup TEXT,
    config_files TEXT, -- Comma-separated list of config file paths
    created_at INTEGER NOT NULL,
    verified INTEGER NOT NULL DEFAULT 0
);

-- Honeytokens table
-- Satisfies Requirements: 3.1, 3.2 (Database breach detection)
CREATE TABLE IF NOT EXISTS honeytokens (
    id TEXT PRIMARY KEY,
    token_type TEXT NOT NULL,
    token_value TEXT NOT NULL,
    table_name TEXT NOT NULL,
    column_name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    accessed_at INTEGER,
    access_count INTEGER NOT NULL DEFAULT 0
);

-- Configuration monitoring table
-- Satisfies Requirements: 4.1 (System file and configuration monitoring)
CREATE TABLE IF NOT EXISTS config_monitoring (
    id TEXT PRIMARY KEY,
    file_path TEXT NOT NULL,
    file_hash TEXT NOT NULL,
    last_modified INTEGER NOT NULL,
    monitored_since INTEGER NOT NULL,
    change_detected_at INTEGER
);

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_team_members_status ON team_members(status);
CREATE INDEX IF NOT EXISTS idx_team_members_role ON team_members(role);
CREATE INDEX IF NOT EXISTS idx_tasks_assignee ON tasks(assignee_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority);
CREATE INDEX IF NOT EXISTS idx_tasks_type ON tasks(type);
CREATE INDEX IF NOT EXISTS idx_security_alerts_severity ON security_alerts(severity);
CREATE INDEX IF NOT EXISTS idx_security_alerts_status ON security_alerts(status);
CREATE INDEX IF NOT EXISTS idx_security_alerts_type ON security_alerts(type);
CREATE INDEX IF NOT EXISTS idx_security_alerts_detected_at ON security_alerts(detected_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action_type ON audit_logs(action_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_deployments_environment ON deployments(environment);
CREATE INDEX IF NOT EXISTS idx_deployments_status ON deployments(status);
CREATE INDEX IF NOT EXISTS idx_deployments_deployed_at ON deployments(deployed_at);
CREATE INDEX IF NOT EXISTS idx_snapshots_environment ON snapshots(environment);
CREATE INDEX IF NOT EXISTS idx_snapshots_verified ON snapshots(verified);
CREATE INDEX IF NOT EXISTS idx_snapshots_created_at ON snapshots(created_at);
CREATE INDEX IF NOT EXISTS idx_honeytokens_accessed_at ON honeytokens(accessed_at);
CREATE INDEX IF NOT EXISTS idx_config_monitoring_file_path ON config_monitoring(file_path);