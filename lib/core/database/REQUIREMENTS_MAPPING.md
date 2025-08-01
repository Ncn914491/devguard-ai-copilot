# Database Models and Services - Requirements Mapping

This document maps each database entity and service method to the specific requirements they satisfy from the DevGuard AI Copilot specification.

## Data Models to Requirements Mapping

### TeamMember Model
**Requirements Satisfied:**
- **Req 5.1**: Team dashboard display with all team members, roles, active tasks, and status
- **Req 5.2**: AI-suggested assignments based on workload and expertise  
- **Req 5.5**: Bench status indication for availability

**Key Fields:**
- `role`: Supports 'developer', 'admin', 'security_reviewer' roles
- `status`: Tracks 'active', 'bench', 'offline' status for availability
- `assignments`: List of assigned task IDs for workload tracking
- `expertise`: Skills for AI-suggested assignment matching
- `workload`: Numeric workload for assignment optimization

### Task Model  
**Requirements Satisfied:**
- **Req 5.4**: Git issues/tasks sync with automatic progress tracking
- **Req 3.5, 4.5**: Security and system task categorization
- **Req 9.1**: Task changes tracked in audit logs

**Key Fields:**
- `type`: Categorizes as 'feature', 'bug', 'security', 'deployment'
- `status`: Tracks progress through 'pending', 'in_progress', 'review', 'completed', 'blocked'
- `relatedCommits`: Links tasks to git commits for traceability
- `assigneeId`: Foreign key to team_members for assignment tracking

### SecurityAlert Model
**Requirements Satisfied:**
- **Req 3.2**: Honeytoken access triggers immediate security alerts
- **Req 3.3**: Abnormal query volume flagging for data export detection
- **Req 3.4**: Privilege escalation attempt logging and alerting
- **Req 3.5**: AI-generated explanations with severity ratings
- **Req 4.5**: System anomaly detection with contextual explanations
- **Req 7.2**: Security anomaly rollback suggestions

**Key Fields:**
- `type`: Categorizes as 'database_breach', 'system_anomaly', 'network_anomaly', 'auth_flood'
- `severity`: AI-generated severity ratings ('low', 'medium', 'high', 'critical')
- `aiExplanation`: AI-generated contextual explanations for alerts
- `rollbackSuggested`: Boolean flag for automatic rollback recommendations
- `evidence`: JSON storage for supporting evidence and traces

### Deployment Model
**Requirements Satisfied:**
- **Req 7.1**: Automatic rollback snapshot creation before deployments
- **Req 7.4**: System integrity verification and status reporting
- **Req 2.4**: Deployment failure detection with automatic rollback suggestions

**Key Fields:**
- `environment`: Tracks 'development', 'staging', 'production' deployments
- `status`: Monitors deployment progress and outcomes
- `snapshotId`: Links to pre-deployment snapshots for rollback capability
- `rollbackAvailable`: Boolean flag indicating rollback option availability
- `healthChecks`: JSON storage for post-deployment health verification

### Snapshot Model
**Requirements Satisfied:**
- **Req 7.1**: Automatic rollback snapshot creation
- **Req 7.2**: Security anomaly rollback options
- **Req 7.4**: System integrity verification and status reporting
- **Req 7.5**: Alternative recovery options when rollback fails

**Key Fields:**
- `gitCommit`: Git commit hash for code state restoration
- `databaseBackup`: Path to database backup for data restoration
- `configFiles`: List of configuration files for complete system restoration
- `verified`: Boolean flag for snapshot integrity verification

### AuditLog Model
**Requirements Satisfied:**
- **Req 9.1**: Complete audit logging of all AI actions with context and reasoning
- **Req 9.2**: Version control tracking for all code and configuration changes
- **Req 9.3**: Detailed explanations and evidence for security alerts
- **Req 9.4**: Human approval requirement and recording for critical actions
- **Req 9.5**: Comprehensive audit trail access with filtering and search

**Key Fields:**
- `actionType`: Categorizes all system actions for audit trail organization
- `aiReasoning`: Stores AI decision-making context and explanations
- `contextData`: JSON storage for complete action context
- `requiresApproval`: Boolean flag for actions needing human oversight
- `approved`: Boolean flag tracking approval status
- `approvedBy`: User ID of approving authority

## Service Methods to Requirements Mapping

### TeamMemberService
- `createTeamMember()` → **Req 5.1**: Team member registration and role assignment
- `getTeamMembersByStatus('bench')` → **Req 5.5**: Bench status visibility
- `updateAssignments()` → **Req 5.2, 5.3**: AI-suggested assignments with human approval
- `getTeamMembersByExpertise()` → **Req 5.2**: Expertise-based assignment suggestions
- `getAvailableMembers()` → **Req 5.2**: Workload-based assignment optimization

### TaskService  
- `createTask()` → **Req 5.4**: Git issues/tasks sync and creation
- `updateTaskStatus()` → **Req 5.4**: Automatic progress tracking
- `addRelatedCommit()` → **Req 5.4**: Git commit linking for traceability
- `updateTaskAssignment()` → **Req 5.2, 5.3**: Assignment updates with approval
- `getTasksByType('security')` → **Req 3.5**: Security task categorization

### SecurityAlertService
- `createHoneytokenAlert()` → **Req 3.1, 3.2**: Honeytoken breach detection
- `createSecurityAlert()` → **Req 3.5**: AI-generated explanations with severity
- `getAlertsWithRollbackSuggestion()` → **Req 7.2**: Security-triggered rollback options
- `resolveAlert()` → **Req 3.5, 4.5**: Human oversight for alert resolution
- `getCriticalUnresolvedAlerts()` → **Req 3.5**: Critical alert prioritization

### DeploymentService
- `createDeployment()` → **Req 7.1**: Deployment tracking with snapshot linking
- `markDeploymentFailed()` → **Req 2.4**: Failure detection with rollback suggestions
- `updateDeploymentStatus()` → **Req 7.4**: Deployment status monitoring
- `getLatestSuccessfulDeployment()` → **Req 7.1**: Last known good state tracking
- `getDeploymentsWithRollback()` → **Req 7.1, 7.2**: Rollback option availability

### SnapshotService
- `createPreDeploymentSnapshot()` → **Req 2.3**: Automatic snapshot before deployments
- `verifySnapshot()` → **Req 7.4**: System integrity verification
- `getLatestVerifiedSnapshot()` → **Req 7.1, 7.2**: Last known good state for rollback
- `getRollbackOptions()` → **Req 7.2, 7.5**: Multiple rollback alternatives

### AuditLogService
- `logAction()` → **Req 9.1**: Universal audit logging for all system actions
- `getLogsRequiringApproval()` → **Req 9.4**: Human approval workflow tracking
- `approveAction()` → **Req 9.4**: Human approval recording
- `getAIActions()` → **Req 9.1**: AI action tracking with reasoning
- `searchAuditLogs()` → **Req 9.5**: Comprehensive audit trail search
- `getAuditStatistics()` → **Req 9.5**: Audit trail analysis and reporting

## Database Schema Features

### Referential Integrity
- Foreign key constraints ensure data consistency
- Cascade rules prevent orphaned records
- Check constraints enforce valid enum values

### Performance Optimization
- Strategic indexes on frequently queried columns
- Composite indexes for complex query patterns
- Timestamp indexes for chronological data access

### Audit Trail Completeness
- Every service method logs actions to audit_logs table
- Context data preserved as JSON for complete traceability
- AI reasoning captured for transparency and debugging

### Security Monitoring Integration
- Honeytoken table for breach detection
- Configuration monitoring for file drift detection
- Alert evidence storage for forensic analysis

This comprehensive mapping ensures that every requirement related to data persistence, team management, security monitoring, deployment tracking, and audit logging is properly addressed by the database layer implementation.