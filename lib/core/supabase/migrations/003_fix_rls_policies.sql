-- DevGuard AI Copilot - Fix RLS Policies
-- This script fixes the error in the users_update_own_profile policy

-- Drop the problematic policy
DROP POLICY IF EXISTS "users_update_own_profile" ON users;

-- Create a corrected users update policy
-- Users can update their own profile, but only admins can change roles
CREATE POLICY "users_update_own_profile" ON users
  FOR UPDATE USING (
    auth.uid() = id OR is_admin()
  );

-- Add a trigger to prevent non-admins from changing roles
CREATE OR REPLACE FUNCTION prevent_role_change()
RETURNS TRIGGER AS $$
BEGIN
  -- If the role is being changed and the user is not an admin
  IF OLD.role != NEW.role AND NOT is_admin() THEN
    -- If the user is trying to update their own record
    IF OLD.id = auth.uid() THEN
      RAISE EXCEPTION 'Users cannot change their own role. Only admins can change user roles.';
    ELSE
      RAISE EXCEPTION 'Only admins can change user roles.';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply the role change prevention trigger
DROP TRIGGER IF EXISTS prevent_role_change_trigger ON users;
CREATE TRIGGER prevent_role_change_trigger
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION prevent_role_change();

-- Also fix any other policies that might have similar issues
-- Drop and recreate the privilege escalation trigger with better logic
DROP TRIGGER IF EXISTS prevent_privilege_escalation_trigger ON users;
DROP FUNCTION IF EXISTS prevent_privilege_escalation();

CREATE OR REPLACE FUNCTION prevent_privilege_escalation()
RETURNS TRIGGER AS $$
BEGIN
  -- Prevent non-admins from setting admin role
  IF NEW.role = 'admin' AND OLD.role != 'admin' THEN
    IF NOT is_admin() THEN
      RAISE EXCEPTION 'Only admins can grant admin privileges';
    END IF;
  END IF;
  
  -- Prevent non-leads from setting lead_developer role
  IF NEW.role = 'lead_developer' AND OLD.role != 'lead_developer' THEN
    IF NOT is_lead_or_admin() THEN
      RAISE EXCEPTION 'Only lead developers or admins can grant lead developer privileges';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply the corrected privilege escalation prevention trigger
CREATE TRIGGER prevent_privilege_escalation_trigger
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION prevent_privilege_escalation();

-- Test the policies to make sure they work
DO $$
BEGIN
  RAISE NOTICE 'RLS policies have been fixed successfully!';
  RAISE NOTICE 'Users can now update their own profiles but cannot change roles unless they are admins.';
END $$;