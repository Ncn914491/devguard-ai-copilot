-- DevGuard AI Copilot - Initial Supabase Schema Migration
-- This migration creates all the necessary tables for the Supabase migration

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create custom types
CREATE TYPE user_role AS ENUM ('admin', 'lead_developer', 'developer', 'viewer');
CREATE TYPE user_status AS ENUM ('active', 'inactive', 'pending');
CREATE TYPE task_type AS ENUM ('feature', 'bug', 'enhancement', 'maintenance', 'security');
CREATE TYPE task_priority AS ENUM ('low', 'medium', 'high', 'critical');
CREATE TYPE task_status AS ENUM ('todo', 'in_progress', 'review', 'testing', 'done', 'blocked');
CREATE TYPE alert_severity AS ENUM ('low', 'medium', 'high', 'critical');
CREATE TYPE alert_status AS ENUM ('new', 'investigating', 'resolved', 'false_positive');
CREATE TYPE deployment_status AS ENUM ('pending', 'in_progress', 'success', 'failed', 'rolled_back');
CREATE TYPE confidentiality_level AS ENUM ('public', 'team', 'confidential', 'restricted');

-- Users table (replaces auth logic and integrates with Supabase Auth)
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  role user_role NOT NULL DEFAULT 'developer',
  status user_status NOT NULL DEFAULT 'active',
  github_username TEXT,
  avatar_url TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT users_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
  CONSTRAINT users_name_length CHECK (length(name) >= 2 AND length(name) <= 100)
);

-- Create indexes for users table
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_github_username ON users(github_username);
CREATE INDEX idx_users_created_at ON users(created_at);

-- Team members table (enhanced with UUID references)
CREATE TABLE team_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  role TEXT NOT NULL,
  status TEXT NOT NULL,
  assignments TEXT[] DEFAULT '{}',
  expertise TEXT[] DEFAULT '{}',
  workload INTEGER DEFAULT 0 CHECK (workload >= 0 AND workload <= 100),
  availability_hours INTEGER DEFAULT 40 CHECK (availability_hours >= 0 AND availability_hours <= 168),
  timezone TEXT DEFAULT 'UTC',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT team_members_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
  CONSTRAINT team_members_name_length CHECK (length(name) >= 2 AND length(name) <= 100),
  CONSTRAINT team_members_unique_user_email UNIQUE(user_id, email)
);

-- Create indexes for team_members table
CREATE INDEX idx_team_members_user_id ON team_members(user_id);
CREATE INDEX idx_team_members_email ON team_members(email);
CREATE INDEX idx_team_members_role ON team_members(role);
CREATE INDEX idx_team_members_status ON team_members(status);
CREATE INDEX idx_team_members_workload ON team_members(workload);
CREATE INDEX idx_team_members_created_at ON team_members(created_at);

-- Tasks table (enhanced with improved relationships and JSONB fields)
CREATE TABLE tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  type task_type NOT NULL DEFAULT 'feature',
  priority task_priority NOT NULL DEFAULT 'medium',
  status task_status NOT NULL DEFAULT 'todo',
  assignee_id UUID REFERENCES team_members(id) ON DELETE SET NULL,
  reporter_id UUID REFERENCES users(id) ON DELETE SET NULL,
  estimated_hours INTEGER DEFAULT 0 CHECK (estimated_hours >= 0),
  actual_hours INTEGER DEFAULT 0 CHECK (actual_hours >= 0),
  progress_percentage INTEGER DEFAULT 0 CHECK (progress_percentage >= 0 AND progress_percentage <= 100),
  related_commits TEXT[] DEFAULT '{}',
  related_pull_requests TEXT[] DEFAULT '{}',
  dependencies UUID[] DEFAULT '{}',
  blocked_by UUID[] DEFAULT '{}',
  tags TEXT[] DEFAULT '{}',
  custom_fields JSONB DEFAULT '{}',
  confidentiality_level confidentiality_level DEFAULT 'team',
  authorized_users UUID[] DEFAULT '{}',
  authorized_roles TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  due_date TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT tasks_title_length CHECK (length(title) >= 3 AND length(title) <= 200),
  CONSTRAINT tasks_description_length CHECK (length(description) >= 10),
  CONSTRAINT tasks_dates_logical CHECK (
    (started_at IS NULL OR started_at >= created_at) AND
    (completed_at IS NULL OR (started_at IS NOT NULL AND completed_at >= started_at)) AND
    (due_date IS NULL OR due_date >= created_at)
  )
);

-- Create indexes for tasks table
CREATE INDEX idx_tasks_assignee_id ON tasks(assignee_id);
CREATE INDEX idx_tasks_reporter_id ON tasks(reporter_id);
CREATE INDEX idx_tasks_type ON tasks(type);
CREATE INDEX idx_tasks_priority ON tasks(priority);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_confidentiality_level ON tasks(confidentiality_level);
CREATE INDEX idx_tasks_due_date ON tasks(due_date);
CREATE INDEX idx_tasks_created_at ON tasks(created_at);
CREATE INDEX idx_tasks_updated_at ON tasks(updated_at);
CREATE INDEX idx_tasks_dependencies ON tasks USING GIN(dependencies);
CREATE INDEX idx_tasks_authorized_users ON tasks USING GIN(authorized_users);
CREATE INDEX idx_tasks_tags ON tasks USING GIN(tags);

-- Security alerts table (enhanced)
CREATE TABLE security_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL,
  severity alert_severity NOT NULL DEFAULT 'medium',
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  ai_explanation TEXT NOT NULL,
  trigger_data JSONB DEFAULT '{}',
  status alert_status DEFAULT 'new',
  assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
  detected_at TIMESTAMPTZ DEFAULT NOW(),
  acknowledged_at TIMESTAMPTZ,
  resolved_at TIMESTAMPTZ,
  rollback_suggested BOOLEAN DEFAULT FALSE,
  evidence JSONB DEFAULT '{}',
  remediation_steps TEXT[],
  affected_systems TEXT[],
  risk_score INTEGER CHECK (risk_score >= 0 AND risk_score <= 100),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT security_alerts_title_length CHECK (length(title) >= 5 AND length(title) <= 200),
  CONSTRAINT security_alerts_description_length CHECK (length(description) >= 10),
  CONSTRAINT security_alerts_dates_logical CHECK (
    (acknowledged_at IS NULL OR acknowledged_at >= detected_at) AND
    (resolved_at IS NULL OR resolved_at >= detected_at)
  )
);

-- Create indexes for security_alerts table
CREATE INDEX idx_security_alerts_type ON security_alerts(type);
CREATE INDEX idx_security_alerts_severity ON security_alerts(severity);
CREATE INDEX idx_security_alerts_status ON security_alerts(status);
CREATE INDEX idx_security_alerts_assigned_to ON security_alerts(assigned_to);
CREATE INDEX idx_security_alerts_detected_at ON security_alerts(detected_at);
CREATE INDEX idx_security_alerts_risk_score ON security_alerts(risk_score);
CREATE INDEX idx_security_alerts_trigger_data ON security_alerts USING GIN(trigger_data);
CREATE INDEX idx_security_alerts_evidence ON security_alerts USING GIN(evidence);

-- Audit logs table (enhanced)
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action_type TEXT NOT NULL,
  description TEXT NOT NULL,
  ai_reasoning TEXT,
  context_data JSONB DEFAULT '{}',
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  affected_resource_type TEXT,
  affected_resource_id UUID,
  ip_address INET,
  user_agent TEXT,
  session_id TEXT,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  requires_approval BOOLEAN DEFAULT FALSE,
  approved BOOLEAN DEFAULT FALSE,
  approved_by UUID REFERENCES users(id) ON DELETE SET NULL,
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT audit_logs_action_type_length CHECK (length(action_type) >= 3 AND length(action_type) <= 100),
  CONSTRAINT audit_logs_description_length CHECK (length(description) >= 5),
  CONSTRAINT audit_logs_approval_logic CHECK (
    (requires_approval = FALSE) OR 
    (requires_approval = TRUE AND approved IS NOT NULL)
  ),
  CONSTRAINT audit_logs_approval_dates CHECK (
    (approved_at IS NULL) OR 
    (approved = TRUE AND approved_at >= timestamp)
  )
);

-- Create indexes for audit_logs table
CREATE INDEX idx_audit_logs_action_type ON audit_logs(action_type);
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp);
CREATE INDEX idx_audit_logs_requires_approval ON audit_logs(requires_approval);
CREATE INDEX idx_audit_logs_approved ON audit_logs(approved);
CREATE INDEX idx_audit_logs_approved_by ON audit_logs(approved_by);
CREATE INDEX idx_audit_logs_affected_resource ON audit_logs(affected_resource_type, affected_resource_id);
CREATE INDEX idx_audit_logs_context_data ON audit_logs USING GIN(context_data);

-- Deployments table
CREATE TABLE deployments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  environment TEXT NOT NULL,
  version TEXT NOT NULL,
  status deployment_status NOT NULL DEFAULT 'pending',
  initiated_by UUID REFERENCES users(id) ON DELETE SET NULL,
  commit_hash TEXT NOT NULL,
  branch TEXT NOT NULL DEFAULT 'main',
  deployment_config JSONB DEFAULT '{}',
  build_logs TEXT,
  deployment_logs TEXT,
  rollback_version TEXT,
  health_check_url TEXT,
  health_check_status TEXT,
  performance_metrics JSONB DEFAULT '{}',
  started_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  duration_seconds INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT deployments_environment_valid CHECK (environment IN ('development', 'staging', 'production')),
  CONSTRAINT deployments_version_format CHECK (version ~ '^v?\d+\.\d+\.\d+'),
  CONSTRAINT deployments_commit_hash_format CHECK (length(commit_hash) = 40),
  CONSTRAINT deployments_dates_logical CHECK (
    (completed_at IS NULL OR completed_at >= started_at)
  ),
  CONSTRAINT deployments_duration_positive CHECK (
    (duration_seconds IS NULL OR duration_seconds >= 0)
  )
);

-- Create indexes for deployments table
CREATE INDEX idx_deployments_environment ON deployments(environment);
CREATE INDEX idx_deployments_status ON deployments(status);
CREATE INDEX idx_deployments_initiated_by ON deployments(initiated_by);
CREATE INDEX idx_deployments_commit_hash ON deployments(commit_hash);
CREATE INDEX idx_deployments_branch ON deployments(branch);
CREATE INDEX idx_deployments_started_at ON deployments(started_at);
CREATE INDEX idx_deployments_version ON deployments(version);

-- Snapshots table
CREATE TABLE snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  commit_hash TEXT NOT NULL,
  branch TEXT NOT NULL DEFAULT 'main',
  author_id UUID REFERENCES users(id) ON DELETE SET NULL,
  file_changes JSONB DEFAULT '{}',
  metadata JSONB DEFAULT '{}',
  tags TEXT[] DEFAULT '{}',
  is_automated BOOLEAN DEFAULT FALSE,
  parent_snapshot_id UUID REFERENCES snapshots(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT snapshots_name_length CHECK (length(name) >= 3 AND length(name) <= 200),
  CONSTRAINT snapshots_commit_hash_format CHECK (length(commit_hash) = 40),
  CONSTRAINT snapshots_no_self_reference CHECK (id != parent_snapshot_id)
);

-- Create indexes for snapshots table
CREATE INDEX idx_snapshots_name ON snapshots(name);
CREATE INDEX idx_snapshots_commit_hash ON snapshots(commit_hash);
CREATE INDEX idx_snapshots_branch ON snapshots(branch);
CREATE INDEX idx_snapshots_author_id ON snapshots(author_id);
CREATE INDEX idx_snapshots_parent_snapshot_id ON snapshots(parent_snapshot_id);
CREATE INDEX idx_snapshots_created_at ON snapshots(created_at);
CREATE INDEX idx_snapshots_tags ON snapshots USING GIN(tags);
CREATE INDEX idx_snapshots_is_automated ON snapshots(is_automated);

-- Specifications table
CREATE TABLE specifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  content TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'feature',
  status TEXT NOT NULL DEFAULT 'draft',
  priority task_priority NOT NULL DEFAULT 'medium',
  author_id UUID REFERENCES users(id) ON DELETE SET NULL,
  assignee_id UUID REFERENCES users(id) ON DELETE SET NULL,
  reviewer_ids UUID[] DEFAULT '{}',
  approved_by UUID[] DEFAULT '{}',
  rejected_by UUID[] DEFAULT '{}',
  approval_required_count INTEGER DEFAULT 1 CHECK (approval_required_count >= 1),
  tags TEXT[] DEFAULT '{}',
  related_tasks UUID[] DEFAULT '{}',
  related_commits TEXT[] DEFAULT '{}',
  attachments JSONB DEFAULT '{}',
  version INTEGER DEFAULT 1 CHECK (version >= 1),
  parent_spec_id UUID REFERENCES specifications(id) ON DELETE SET NULL,
  confidentiality_level confidentiality_level DEFAULT 'team',
  estimated_effort_hours INTEGER CHECK (estimated_effort_hours >= 0),
  actual_effort_hours INTEGER CHECK (actual_effort_hours >= 0),
  due_date TIMESTAMPTZ,
  approved_at TIMESTAMPTZ,
  rejected_at TIMESTAMPTZ,
  implemented_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT specifications_title_length CHECK (length(title) >= 5 AND length(title) <= 200),
  CONSTRAINT specifications_description_length CHECK (length(description) >= 10),
  CONSTRAINT specifications_content_length CHECK (length(content) >= 50),
  CONSTRAINT specifications_status_valid CHECK (status IN ('draft', 'review', 'approved', 'rejected', 'implemented', 'archived')),
  CONSTRAINT specifications_no_self_reference CHECK (id != parent_spec_id),
  CONSTRAINT specifications_dates_logical CHECK (
    (approved_at IS NULL OR approved_at >= created_at) AND
    (rejected_at IS NULL OR rejected_at >= created_at) AND
    (implemented_at IS NULL OR implemented_at >= created_at) AND
    (due_date IS NULL OR due_date >= created_at)
  )
);

-- Create indexes for specifications table
CREATE INDEX idx_specifications_title ON specifications(title);
CREATE INDEX idx_specifications_type ON specifications(type);
CREATE INDEX idx_specifications_status ON specifications(status);
CREATE INDEX idx_specifications_priority ON specifications(priority);
CREATE INDEX idx_specifications_author_id ON specifications(author_id);
CREATE INDEX idx_specifications_assignee_id ON specifications(assignee_id);
CREATE INDEX idx_specifications_confidentiality_level ON specifications(confidentiality_level);
CREATE INDEX idx_specifications_due_date ON specifications(due_date);
CREATE INDEX idx_specifications_created_at ON specifications(created_at);
CREATE INDEX idx_specifications_updated_at ON specifications(updated_at);
CREATE INDEX idx_specifications_version ON specifications(version);
CREATE INDEX idx_specifications_parent_spec_id ON specifications(parent_spec_id);
CREATE INDEX idx_specifications_tags ON specifications USING GIN(tags);
CREATE INDEX idx_specifications_reviewer_ids ON specifications USING GIN(reviewer_ids);
CREATE INDEX idx_specifications_approved_by ON specifications USING GIN(approved_by);
CREATE INDEX idx_specifications_related_tasks ON specifications USING GIN(related_tasks);

-- Create updated_at triggers for all tables
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at triggers
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_team_members_updated_at BEFORE UPDATE ON team_members FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_tasks_updated_at BEFORE UPDATE ON tasks FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_security_alerts_updated_at BEFORE UPDATE ON security_alerts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_deployments_updated_at BEFORE UPDATE ON deployments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_specifications_updated_at BEFORE UPDATE ON specifications FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE security_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE deployments ENABLE ROW LEVEL SECURITY;
ALTER TABLE snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE specifications ENABLE ROW LEVEL SECURITY;