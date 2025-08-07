-- DevGuard AI Copilot - Row-Level Security Policies (Fixed)
-- This migration creates comprehensive RLS policies for role-based access control

-- Helper function to get current user's role
CREATE OR REPLACE FUNCTION get_user_role(user_uuid UUID DEFAULT auth.uid())
RETURNS TEXT AS $$
BEGIN
  RETURN (SELECT role FROM users WHERE id = user_uuid);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if user is admin
CREATE OR REPLACE FUNCTION is_admin(user_uuid UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (SELECT role FROM users WHERE id = user_uuid) = 'admin';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if user is lead developer or admin
CREATE OR REPLACE FUNCTION is_lead_or_admin(user_uuid UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (SELECT role FROM users WHERE id = user_uuid) IN ('admin', 'lead_developer');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if user has developer privileges or higher
CREATE OR REPLACE FUNCTION has_developer_access(user_uuid UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (SELECT role FROM users WHERE id = user_uuid) IN ('admin', 'lead_developer', 'developer');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check confidentiality access
CREATE OR REPLACE FUNCTION can_access_confidential_data(
  confidentiality confidentiality_level,
  authorized_users UUID[] DEFAULT '{}',
  authorized_roles TEXT[] DEFAULT '{}',
  user_uuid UUID DEFAULT auth.uid()
)
RETURNS BOOLEAN AS $$
DECLARE
  user_role TEXT;
BEGIN
  user_role := get_user_role(user_uuid);
  
  -- Admin can access everything
  IF user_role = 'admin' THEN
    RETURN TRUE;
  END IF;
  
  -- Check confidentiality level
  CASE confidentiality
    WHEN 'public' THEN
      RETURN TRUE;
    WHEN 'team' THEN
      RETURN user_role IN ('lead_developer', 'developer');
    WHEN 'confidential' THEN
      RETURN user_role IN ('lead_developer') OR 
             user_uuid = ANY(authorized_users) OR
             user_role = ANY(authorized_roles);
    WHEN 'restricted' THEN
      RETURN user_uuid = ANY(authorized_users) OR
             user_role = ANY(authorized_roles);
    ELSE
      RETURN FALSE;
  END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- USERS TABLE RLS POLICIES
-- =============================================================================

-- Users can read their own data and admins can read all
CREATE POLICY "users_select_policy" ON users
  FOR SELECT USING (
    auth.uid() = id OR 
    is_admin()
  );

-- Users can update their own profile, admins can update everything
CREATE POLICY "users_update_policy" ON users
  FOR UPDATE USING (
    auth.uid() = id OR is_admin()
  );

-- Only admins can insert new users
CREATE POLICY "users_insert_admin_only" ON users
  FOR INSERT WITH CHECK (is_admin());

-- Only admins can delete users
CREATE POLICY "users_delete_admin_only" ON users
  FOR DELETE USING (is_admin());

-- =============================================================================
-- TEAM_MEMBERS TABLE RLS POLICIES
-- =============================================================================

-- Team members can be read by developers and above
CREATE POLICY "team_members_select_policy" ON team_members
  FOR SELECT USING (
    has_developer_access() OR
    user_id = auth.uid() -- Users can always see their own team member record
  );

-- Lead developers and admins can insert team members
CREATE POLICY "team_members_insert_policy" ON team_members
  FOR INSERT WITH CHECK (is_lead_or_admin());

-- Lead developers and admins can update team members, users can update their own
CREATE POLICY "team_members_update_policy" ON team_members
  FOR UPDATE USING (
    is_lead_or_admin() OR
    user_id = auth.uid() -- Users can update their own team member record
  );

-- Only admins can delete team members
CREATE POLICY "team_members_delete_policy" ON team_members
  FOR DELETE USING (is_admin());

-- =============================================================================
-- TASKS TABLE RLS POLICIES
-- =============================================================================

-- Task access based on confidentiality level and authorization
CREATE POLICY "tasks_select_policy" ON tasks
  FOR SELECT USING (
    can_access_confidential_data(
      confidentiality_level, 
      authorized_users, 
      authorized_roles
    ) OR
    assignee_id IN (SELECT id FROM team_members WHERE user_id = auth.uid()) OR
    reporter_id = auth.uid()
  );

-- Developers and above can insert tasks
CREATE POLICY "tasks_insert_policy" ON tasks
  FOR INSERT WITH CHECK (
    has_developer_access() AND
    (reporter_id = auth.uid() OR is_lead_or_admin())
  );

-- Task updates: assignees, reporters, and leads can update
CREATE POLICY "tasks_update_policy" ON tasks
  FOR UPDATE USING (
    is_lead_or_admin() OR
    assignee_id IN (SELECT id FROM team_members WHERE user_id = auth.uid()) OR
    reporter_id = auth.uid()
  );

-- Only lead developers and admins can delete tasks
CREATE POLICY "tasks_delete_policy" ON tasks
  FOR DELETE USING (is_lead_or_admin());

-- =============================================================================
-- SECURITY_ALERTS TABLE RLS POLICIES
-- =============================================================================

-- Security alerts can be read by developers and above
CREATE POLICY "security_alerts_select_policy" ON security_alerts
  FOR SELECT USING (
    has_developer_access() OR
    assigned_to = auth.uid()
  );

-- Only lead developers and admins can insert security alerts
CREATE POLICY "security_alerts_insert_policy" ON security_alerts
  FOR INSERT WITH CHECK (is_lead_or_admin());

-- Assigned users and leads can update security alerts
CREATE POLICY "security_alerts_update_policy" ON security_alerts
  FOR UPDATE USING (
    is_lead_or_admin() OR
    assigned_to = auth.uid()
  );

-- Only admins can delete security alerts
CREATE POLICY "security_alerts_delete_policy" ON security_alerts
  FOR DELETE USING (is_admin());

-- =============================================================================
-- AUDIT_LOGS TABLE RLS POLICIES
-- =============================================================================

-- Audit logs can be read by lead developers and admins
CREATE POLICY "audit_logs_select_policy" ON audit_logs
  FOR SELECT USING (
    is_lead_or_admin() OR
    user_id = auth.uid() -- Users can see their own audit logs
  );

-- System can insert audit logs (no user restriction for logging)
CREATE POLICY "audit_logs_insert_policy" ON audit_logs
  FOR INSERT WITH CHECK (true);

-- Only admins can update audit logs (for approval workflow)
CREATE POLICY "audit_logs_update_policy" ON audit_logs
  FOR UPDATE USING (is_admin());

-- Only admins can delete audit logs
CREATE POLICY "audit_logs_delete_policy" ON audit_logs
  FOR DELETE USING (is_admin());

-- =============================================================================
-- DEPLOYMENTS TABLE RLS POLICIES
-- =============================================================================

-- Deployments can be read by developers and above
CREATE POLICY "deployments_select_policy" ON deployments
  FOR SELECT USING (
    has_developer_access() OR
    initiated_by = auth.uid()
  );

-- Lead developers and admins can insert deployments
CREATE POLICY "deployments_insert_policy" ON deployments
  FOR INSERT WITH CHECK (
    is_lead_or_admin() AND
    (initiated_by = auth.uid() OR is_admin())
  );

-- Deployment initiators and leads can update deployments
CREATE POLICY "deployments_update_policy" ON deployments
  FOR UPDATE USING (
    is_lead_or_admin() OR
    initiated_by = auth.uid()
  );

-- Only admins can delete deployments
CREATE POLICY "deployments_delete_policy" ON deployments
  FOR DELETE USING (is_admin());

-- =============================================================================
-- SNAPSHOTS TABLE RLS POLICIES
-- =============================================================================

-- Snapshots can be read by developers and above
CREATE POLICY "snapshots_select_policy" ON snapshots
  FOR SELECT USING (
    has_developer_access() OR
    author_id = auth.uid()
  );

-- Developers and above can insert snapshots
CREATE POLICY "snapshots_insert_policy" ON snapshots
  FOR INSERT WITH CHECK (
    has_developer_access() AND
    (author_id = auth.uid() OR is_lead_or_admin())
  );

-- Snapshot authors and leads can update snapshots
CREATE POLICY "snapshots_update_policy" ON snapshots
  FOR UPDATE USING (
    is_lead_or_admin() OR
    author_id = auth.uid()
  );

-- Lead developers and admins can delete snapshots
CREATE POLICY "snapshots_delete_policy" ON snapshots
  FOR DELETE USING (is_lead_or_admin());

-- =============================================================================
-- SPECIFICATIONS TABLE RLS POLICIES
-- =============================================================================

-- Specifications access based on confidentiality level
CREATE POLICY "specifications_select_policy" ON specifications
  FOR SELECT USING (
    can_access_confidential_data(confidentiality_level, '{}', '{}') OR
    author_id = auth.uid() OR
    assignee_id = auth.uid() OR
    auth.uid() = ANY(reviewer_ids) OR
    auth.uid() = ANY(approved_by)
  );

-- Developers and above can insert specifications
CREATE POLICY "specifications_insert_policy" ON specifications
  FOR INSERT WITH CHECK (
    has_developer_access() AND
    (author_id = auth.uid() OR is_lead_or_admin())
  );

-- Specification authors, assignees, reviewers, and leads can update
CREATE POLICY "specifications_update_policy" ON specifications
  FOR UPDATE USING (
    is_lead_or_admin() OR
    author_id = auth.uid() OR
    assignee_id = auth.uid() OR
    auth.uid() = ANY(reviewer_ids)
  );

-- Lead developers and admins can delete specifications
CREATE POLICY "specifications_delete_policy" ON specifications
  FOR DELETE USING (is_lead_or_admin());

-- =============================================================================
-- VIEWER ROLE SPECIFIC POLICIES
-- =============================================================================

-- Create additional policies for viewer role (read-only access)
CREATE POLICY "viewer_read_only_tasks" ON tasks
  FOR SELECT USING (
    get_user_role() = 'viewer' AND 
    confidentiality_level = 'public'
  );

CREATE POLICY "viewer_read_only_team_members" ON team_members
  FOR SELECT USING (
    get_user_role() = 'viewer'
  );

CREATE POLICY "viewer_read_only_deployments" ON deployments
  FOR SELECT USING (
    get_user_role() = 'viewer' AND
    environment IN ('staging', 'production') -- Viewers can only see non-dev deployments
  );

-- =============================================================================
-- POLICY DOCUMENTATION
-- =============================================================================

COMMENT ON FUNCTION get_user_role IS 'Helper function to get the current user role for RLS policies';
COMMENT ON FUNCTION is_admin IS 'Helper function to check if current user is admin';
COMMENT ON FUNCTION is_lead_or_admin IS 'Helper function to check if current user is lead developer or admin';
COMMENT ON FUNCTION has_developer_access IS 'Helper function to check if current user has developer privileges or higher';
COMMENT ON FUNCTION can_access_confidential_data IS 'Helper function to check confidentiality-based access control';

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_user_role TO authenticated;
GRANT EXECUTE ON FUNCTION is_admin TO authenticated;
GRANT EXECUTE ON FUNCTION is_lead_or_admin TO authenticated;
GRANT EXECUTE ON FUNCTION has_developer_access TO authenticated;
GRANT EXECUTE ON FUNCTION can_access_confidential_data TO authenticated;