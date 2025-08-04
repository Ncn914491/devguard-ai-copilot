-- DevGuard AI Copilot Database Schema v3.0
-- Migration for task management with confidentiality controls

-- Add confidentiality fields to tasks table
-- Satisfies Requirements: 5.1, 5.2, 5.3, 5.4, 5.5 (Task management with confidentiality)
ALTER TABLE tasks ADD COLUMN confidentiality_level TEXT NOT NULL DEFAULT 'team' 
    CHECK (confidentiality_level IN ('public', 'team', 'restricted', 'confidential'));

ALTER TABLE tasks ADD COLUMN authorized_users TEXT; -- Comma-separated list of user IDs
ALTER TABLE tasks ADD COLUMN authorized_roles TEXT; -- Comma-separated list of roles
ALTER TABLE tasks ADD COLUMN reporter_id TEXT; -- User who created the task
ALTER TABLE tasks ADD COLUMN related_pull_requests TEXT; -- Comma-separated list of PR IDs
ALTER TABLE tasks ADD COLUMN blocked_by TEXT; -- Comma-separated list of blocking task IDs

-- Task Status History table for progress monitoring
-- Satisfies Requirements: 5.3, 5.4 (Task status tracking and progress monitoring)
CREATE TABLE IF NOT EXISTS task_status_history (
    id TEXT PRIMARY KEY,
    task_id TEXT NOT NULL,
    old_status TEXT NOT NULL,
    new_status TEXT NOT NULL,
    changed_by TEXT NOT NULL,
    changed_at INTEGER NOT NULL,
    notes TEXT,
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    FOREIGN KEY (changed_by) REFERENCES users (id)
);

-- Task Access Log table for audit logging
-- Satisfies Requirements: 5.4, 5.5 (Task audit logging for all operations and access attempts)
CREATE TABLE IF NOT EXISTS task_access_log (
    id TEXT PRIMARY KEY,
    task_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    action_type TEXT NOT NULL CHECK (action_type IN ('view', 'create', 'update', 'delete', 'assign', 'status_change', 'access_denied')),
    access_granted INTEGER NOT NULL DEFAULT 1,
    confidentiality_level TEXT NOT NULL,
    user_role TEXT NOT NULL,
    timestamp INTEGER NOT NULL,
    ip_address TEXT,
    user_agent TEXT,
    details TEXT, -- JSON string with additional context
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users (id)
);

-- Task Comments table for collaboration
-- Satisfies Requirements: 5.1, 5.2 (Task management with team collaboration)
CREATE TABLE IF NOT EXISTS task_comments (
    id TEXT PRIMARY KEY,
    task_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    comment TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER,
    is_internal INTEGER NOT NULL DEFAULT 0, -- Internal comments for restricted access
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users (id)
);

-- Task Dependencies table for better dependency management
-- Satisfies Requirements: 5.4 (Task progress tracking with dependencies)
CREATE TABLE IF NOT EXISTS task_dependencies (
    id TEXT PRIMARY KEY,
    task_id TEXT NOT NULL,
    depends_on_task_id TEXT NOT NULL,
    dependency_type TEXT NOT NULL DEFAULT 'blocks' CHECK (dependency_type IN ('blocks', 'relates_to', 'duplicates')),
    created_by TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    FOREIGN KEY (depends_on_task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users (id),
    UNIQUE(task_id, depends_on_task_id, dependency_type)
);

-- Task Assignments table for better assignment tracking
-- Satisfies Requirements: 5.2, 5.3 (Role-based assignment and visibility controls)
CREATE TABLE IF NOT EXISTS task_assignments (
    id TEXT PRIMARY KEY,
    task_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    assigned_by TEXT NOT NULL,
    assigned_at INTEGER NOT NULL,
    unassigned_at INTEGER,
    assignment_type TEXT NOT NULL DEFAULT 'primary' CHECK (assignment_type IN ('primary', 'reviewer', 'observer')),
    notes TEXT,
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users (id),
    FOREIGN KEY (assigned_by) REFERENCES users (id)
);

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_tasks_confidentiality_level ON tasks(confidentiality_level);
CREATE INDEX IF NOT EXISTS idx_tasks_reporter_id ON tasks(reporter_id);
CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON tasks(created_at);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date);

CREATE INDEX IF NOT EXISTS idx_task_status_history_task_id ON task_status_history(task_id);
CREATE INDEX IF NOT EXISTS idx_task_status_history_changed_by ON task_status_history(changed_by);
CREATE INDEX IF NOT EXISTS idx_task_status_history_changed_at ON task_status_history(changed_at);

CREATE INDEX IF NOT EXISTS idx_task_access_log_task_id ON task_access_log(task_id);
CREATE INDEX IF NOT EXISTS idx_task_access_log_user_id ON task_access_log(user_id);
CREATE INDEX IF NOT EXISTS idx_task_access_log_timestamp ON task_access_log(timestamp);
CREATE INDEX IF NOT EXISTS idx_task_access_log_action_type ON task_access_log(action_type);

CREATE INDEX IF NOT EXISTS idx_task_comments_task_id ON task_comments(task_id);
CREATE INDEX IF NOT EXISTS idx_task_comments_user_id ON task_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_task_comments_created_at ON task_comments(created_at);

CREATE INDEX IF NOT EXISTS idx_task_dependencies_task_id ON task_dependencies(task_id);
CREATE INDEX IF NOT EXISTS idx_task_dependencies_depends_on ON task_dependencies(depends_on_task_id);
CREATE INDEX IF NOT EXISTS idx_task_dependencies_type ON task_dependencies(dependency_type);

CREATE INDEX IF NOT EXISTS idx_task_assignments_task_id ON task_assignments(task_id);
CREATE INDEX IF NOT EXISTS idx_task_assignments_user_id ON task_assignments(user_id);
CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_by ON task_assignments(assigned_by);
CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_at ON task_assignments(assigned_at);