-- Migration v4: Security Workflow Integration Tables
-- Satisfies Requirements: 9.1, 9.2, 9.3, 9.4, 9.5 (Security workflow integration database schema)

-- Table for linking security alerts to tasks
CREATE TABLE IF NOT EXISTS alert_task_links (
    id TEXT PRIMARY KEY,
    alert_id TEXT NOT NULL,
    task_id TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (alert_id) REFERENCES security_alerts(id),
    FOREIGN KEY (task_id) REFERENCES tasks(id)
);

-- Table for security approval workflows
CREATE TABLE IF NOT EXISTS security_approval_workflows (
    id TEXT PRIMARY KEY,
    task_id TEXT NOT NULL,
    operation_type TEXT NOT NULL, -- 'git_operation', 'privilege_escalation', 'sensitive_data_access'
    requester_id TEXT NOT NULL,
    required_approvers TEXT NOT NULL, -- comma-separated list
    operation_details TEXT NOT NULL, -- JSON
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
    approved_by TEXT,
    approval_comments TEXT,
    created_at INTEGER NOT NULL,
    approved_at INTEGER,
    FOREIGN KEY (task_id) REFERENCES tasks(id)
);

-- Table for security policy violations
CREATE TABLE IF NOT EXISTS security_policy_violations (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    user_role TEXT NOT NULL,
    operation_type TEXT NOT NULL,
    violation_type TEXT NOT NULL,
    description TEXT NOT NULL,
    severity TEXT NOT NULL, -- 'low', 'medium', 'high', 'critical'
    context_data TEXT, -- JSON
    detected_at INTEGER NOT NULL,
    resolved_at INTEGER,
    resolution_notes TEXT
);

-- Table for git security checks
CREATE TABLE IF NOT EXISTS git_security_checks (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    user_role TEXT NOT NULL,
    operation_type TEXT NOT NULL, -- 'commit', 'push', 'merge', 'branch_create'
    files_affected TEXT, -- comma-separated list
    violations_count INTEGER NOT NULL DEFAULT 0,
    warnings_count INTEGER NOT NULL DEFAULT 0,
    allowed BOOLEAN NOT NULL,
    requires_approval BOOLEAN NOT NULL DEFAULT FALSE,
    check_details TEXT, -- JSON
    performed_at INTEGER NOT NULL
);

-- Table for security incident contexts
CREATE TABLE IF NOT EXISTS security_incident_contexts (
    id TEXT PRIMARY KEY,
    alert_id TEXT NOT NULL,
    incident_time INTEGER NOT NULL,
    context_data TEXT NOT NULL, -- JSON with code changes, user activities, system state
    risk_assessment TEXT, -- JSON
    recommended_actions TEXT, -- JSON array
    created_at INTEGER NOT NULL,
    FOREIGN KEY (alert_id) REFERENCES security_alerts(id)
);

-- Table for security audit reports
CREATE TABLE IF NOT EXISTS security_audit_reports (
    id TEXT PRIMARY KEY,
    report_type TEXT NOT NULL, -- 'comprehensive', 'compliance', 'incident_timeline'
    start_date INTEGER NOT NULL,
    end_date INTEGER NOT NULL,
    report_data TEXT NOT NULL, -- JSON
    metrics TEXT, -- JSON
    recommendations TEXT, -- JSON array
    generated_at INTEGER NOT NULL,
    generated_by TEXT
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_alert_task_links_alert_id ON alert_task_links(alert_id);
CREATE INDEX IF NOT EXISTS idx_alert_task_links_task_id ON alert_task_links(task_id);
CREATE INDEX IF NOT EXISTS idx_security_approval_workflows_status ON security_approval_workflows(status);
CREATE INDEX IF NOT EXISTS idx_security_approval_workflows_requester ON security_approval_workflows(requester_id);
CREATE INDEX IF NOT EXISTS idx_security_policy_violations_user ON security_policy_violations(user_id);
CREATE INDEX IF NOT EXISTS idx_security_policy_violations_detected ON security_policy_violations(detected_at);
CREATE INDEX IF NOT EXISTS idx_git_security_checks_user ON git_security_checks(user_id);
CREATE INDEX IF NOT EXISTS idx_git_security_checks_performed ON git_security_checks(performed_at);
CREATE INDEX IF NOT EXISTS idx_security_incident_contexts_alert ON security_incident_contexts(alert_id);
CREATE INDEX IF NOT EXISTS idx_security_audit_reports_type ON security_audit_reports(report_type);
CREATE INDEX IF NOT EXISTS idx_security_audit_reports_generated ON security_audit_reports(generated_at);