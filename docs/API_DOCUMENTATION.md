# DevGuard AI Copilot - API Documentation

## Overview

This document provides comprehensive API documentation for the DevGuard AI Copilot application. The API is built on Supabase backend infrastructure, providing real-time capabilities, PostgreSQL database, and integrated authentication. The API follows RESTful principles and includes comprehensive error handling with Row-Level Security (RLS) policies.

## Table of Contents

1. [Authentication](#authentication)
2. [User Management API](#user-management-api)
3. [Task Management API](#task-management-api)
4. [Repository API](#repository-api)
5. [WebSocket API](#websocket-api)
6. [DevOps Integration API](#devops-integration-api)
7. [Security Monitoring API](#security-monitoring-api)
8. [Error Handling](#error-handling)
9. [Rate Limiting](#rate-limiting)
10. [API Versioning](#api-versioning)

## Authentication

All API endpoints require authentication using Supabase Auth JWT tokens. The application leverages Supabase's built-in authentication system with Row-Level Security (RLS) policies for data access control. The application supports multiple authentication methods:

### Authentication Methods

#### 1. Email/Password Authentication (Supabase Auth)

```dart
// Using Supabase Flutter SDK
final response = await supabase.auth.signInWithPassword(
  email: 'user@example.com',
  password: 'SecurePassword123!',
);
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "refresh_token_here",
  "user": {
    "id": "user-123",
    "email": "user@example.com",
    "user_metadata": {
      "name": "John Doe",
      "role": "developer"
    }
  },
  "expires_at": 1640995200
}
```

#### 2. GitHub OAuth Authentication (Supabase Auth)

```dart
// Using Supabase Flutter SDK
final response = await supabase.auth.signInWithOAuth(
  Provider.github,
  redirectTo: 'your-app://callback',
);
```

#### 3. Token Refresh (Automatic with Supabase)

```dart
// Supabase handles token refresh automatically
// Manual refresh if needed:
final response = await supabase.auth.refreshSession();
```

### Token Validation

```http
GET /api/v1/auth/validate
Authorization: Bearer <jwt_token>
```

### Logout

```dart
await supabase.auth.signOut();
```

### Real-time Authentication State

```dart
// Listen to authentication state changes
supabase.auth.onAuthStateChange.listen((data) {
  final AuthChangeEvent event = data.event;
  final Session? session = data.session;
  
  switch (event) {
    case AuthChangeEvent.signedIn:
      // User signed in
      break;
    case AuthChangeEvent.signedOut:
      // User signed out
      break;
    case AuthChangeEvent.tokenRefreshed:
      // Token refreshed
      break;
  }
});
```

### Row-Level Security (RLS)

All database operations are protected by RLS policies that automatically filter data based on the authenticated user's role and permissions. The following roles are supported:

- **admin**: Full access to all data
- **lead_developer**: Access to team-related data and assigned projects
- **developer**: Access to assigned tasks and public data
- **viewer**: Read-only access to public data

## User Management API

### Create User (Admin Only)

```http
POST /api/v1/users
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "name": "Jane Developer",
  "email": "jane@example.com",
  "role": "developer",
  "password": "SecurePassword123!",
  "permissions": ["code_access", "task_execution"]
}
```

**Response:**
```json
{
  "success": true,
  "user": {
    "id": "user-456",
    "name": "Jane Developer",
    "email": "jane@example.com",
    "role": "developer",
    "permissions": ["code_access", "task_execution"],
    "createdAt": "2024-01-15T10:30:00Z",
    "isActive": true
  }
}
```

### Get Users

```http
GET /api/v1/users
Authorization: Bearer <token>
```

**Query Parameters:**
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 20)
- `role` (optional): Filter by role
- `search` (optional): Search by name or email

### Get User by ID

```http
GET /api/v1/users/{userId}
Authorization: Bearer <token>
```

### Update User

```http
PUT /api/v1/users/{userId}
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "name": "Jane Senior Developer",
  "role": "lead_developer",
  "permissions": ["code_access", "task_execution", "task_assignment"]
}
```

### Delete User

```http
DELETE /api/v1/users/{userId}
Authorization: Bearer <admin_token>
```

### Update User Role

```http
PATCH /api/v1/users/{userId}/role
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "role": "lead_developer",
  "permissions": ["code_access", "task_execution", "task_assignment", "code_review"]
}
```

## Task Management API

### Create Task

```http
POST /api/v1/tasks
Authorization: Bearer <token>
Content-Type: application/json

{
  "title": "Implement user authentication",
  "description": "Build comprehensive user authentication system with JWT tokens",
  "type": "feature",
  "priority": "high",
  "confidentialityLevel": "team",
  "estimatedHours": 40,
  "dueDate": "2024-02-15T23:59:59Z",
  "tags": ["authentication", "security", "backend"]
}
```

**Response:**
```json
{
  "success": true,
  "task": {
    "id": "task-789",
    "title": "Implement user authentication",
    "description": "Build comprehensive user authentication system with JWT tokens",
    "type": "feature",
    "priority": "high",
    "status": "pending",
    "confidentialityLevel": "team",
    "createdBy": "user-123",
    "estimatedHours": 40,
    "actualHours": 0,
    "dueDate": "2024-02-15T23:59:59Z",
    "tags": ["authentication", "security", "backend"],
    "createdAt": "2024-01-15T10:30:00Z",
    "updatedAt": "2024-01-15T10:30:00Z"
  }
}
```

### Get Tasks

```http
GET /api/v1/tasks
Authorization: Bearer <token>
```

**Query Parameters:**
- `page` (optional): Page number
- `limit` (optional): Items per page
- `status` (optional): Filter by status
- `type` (optional): Filter by type
- `priority` (optional): Filter by priority
- `assignee` (optional): Filter by assignee ID
- `confidentialityLevel` (optional): Filter by confidentiality level
- `search` (optional): Search in title and description

### Get Task by ID

```http
GET /api/v1/tasks/{taskId}
Authorization: Bearer <token>
```

### Update Task

```http
PUT /api/v1/tasks/{taskId}
Authorization: Bearer <token>
Content-Type: application/json

{
  "title": "Implement enhanced user authentication",
  "description": "Build comprehensive user authentication system with JWT tokens and 2FA",
  "priority": "critical",
  "estimatedHours": 50
}
```

### Update Task Status

```http
PATCH /api/v1/tasks/{taskId}/status
Authorization: Bearer <token>
Content-Type: application/json

{
  "status": "in_progress",
  "comment": "Started working on authentication service implementation"
}
```

### Assign Task

```http
PATCH /api/v1/tasks/{taskId}/assign
Authorization: Bearer <token>
Content-Type: application/json

{
  "assigneeId": "user-456",
  "comment": "Assigning to Jane for her expertise in authentication systems"
}
```

### Add Task Comment

```http
POST /api/v1/tasks/{taskId}/comments
Authorization: Bearer <token>
Content-Type: application/json

{
  "comment": "Completed the JWT token service implementation. Ready for review.",
  "type": "progress_update"
}
```

### Get Task Comments

```http
GET /api/v1/tasks/{taskId}/comments
Authorization: Bearer <token>
```

### Link Task to Repository

```http
POST /api/v1/tasks/{taskId}/repositories
Authorization: Bearer <token>
Content-Type: application/json

{
  "repositoryId": "repo-123",
  "linkType": "implementation"
}
```

### Get Task Audit Log

```http
GET /api/v1/tasks/{taskId}/audit
Authorization: Bearer <token>
```

## Repository API

### Create Repository

```http
POST /api/v1/repositories
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "user-authentication-service",
  "description": "Microservice for user authentication and authorization",
  "visibility": "private",
  "language": "dart",
  "framework": "flutter",
  "gitUrl": "https://github.com/company/user-auth-service.git"
}
```

**Response:**
```json
{
  "success": true,
  "repository": {
    "id": "repo-123",
    "name": "user-authentication-service",
    "description": "Microservice for user authentication and authorization",
    "visibility": "private",
    "language": "dart",
    "framework": "flutter",
    "gitUrl": "https://github.com/company/user-auth-service.git",
    "localPath": "/repositories/user-authentication-service",
    "ownerId": "user-123",
    "createdAt": "2024-01-15T10:30:00Z",
    "updatedAt": "2024-01-15T10:30:00Z"
  }
}
```

### Get Repositories

```http
GET /api/v1/repositories
Authorization: Bearer <token>
```

**Query Parameters:**
- `page` (optional): Page number
- `limit` (optional): Items per page
- `visibility` (optional): Filter by visibility
- `language` (optional): Filter by programming language
- `owner` (optional): Filter by owner ID

### Get Repository by ID

```http
GET /api/v1/repositories/{repositoryId}
Authorization: Bearer <token>
```

### Update Repository

```http
PUT /api/v1/repositories/{repositoryId}
Authorization: Bearer <token>
Content-Type: application/json

{
  "description": "Enhanced microservice for user authentication, authorization, and session management",
  "visibility": "team"
}
```

### Add Collaborator

```http
POST /api/v1/repositories/{repositoryId}/collaborators
Authorization: Bearer <token>
Content-Type: application/json

{
  "userId": "user-456",
  "accessLevel": "write",
  "permissions": ["read", "write", "commit"]
}
```

### Get Repository Structure

```http
GET /api/v1/repositories/{repositoryId}/structure
Authorization: Bearer <token>
```

**Query Parameters:**
- `path` (optional): Specific path to browse
- `maxDepth` (optional): Maximum directory depth

### Create File

```http
POST /api/v1/repositories/{repositoryId}/files
Authorization: Bearer <token>
Content-Type: application/json

{
  "filePath": "lib/services/auth_service.dart",
  "content": "import 'package:flutter/material.dart';\n\nclass AuthService {\n  // Implementation\n}",
  "commitMessage": "Add authentication service implementation",
  "branch": "feature/auth-service"
}
```

### Get File Content

```http
GET /api/v1/repositories/{repositoryId}/files/{filePath}
Authorization: Bearer <token>
```

**Query Parameters:**
- `branch` (optional): Specific branch
- `commit` (optional): Specific commit hash

### Update File

```http
PUT /api/v1/repositories/{repositoryId}/files/{filePath}
Authorization: Bearer <token>
Content-Type: application/json

{
  "content": "Updated file content",
  "commitMessage": "Update authentication service with new features",
  "branch": "feature/auth-service"
}
```

### Delete File

```http
DELETE /api/v1/repositories/{repositoryId}/files/{filePath}
Authorization: Bearer <token>
Content-Type: application/json

{
  "commitMessage": "Remove deprecated authentication method",
  "branch": "feature/auth-service"
}
```

### Create Branch

```http
POST /api/v1/repositories/{repositoryId}/branches
Authorization: Bearer <token>
Content-Type: application/json

{
  "branchName": "feature/enhanced-auth",
  "fromBranch": "main"
}
```

### Merge Branch

```http
POST /api/v1/repositories/{repositoryId}/merge
Authorization: Bearer <token>
Content-Type: application/json

{
  "sourceBranch": "feature/enhanced-auth",
  "targetBranch": "main",
  "mergeMessage": "Merge enhanced authentication features"
}
```

## WebSocket API

### Connection

Connect to WebSocket endpoint with authentication:

```javascript
const ws = new WebSocket('ws://localhost:8080/ws');

// Send authentication after connection
ws.onopen = function() {
  ws.send(JSON.stringify({
    type: 'auth',
    token: 'your_jwt_token_here'
  }));
};
```

### Message Types

#### Task Assignment Notification

```json
{
  "type": "task_assigned",
  "data": {
    "taskId": "task-789",
    "assigneeId": "user-456",
    "assignedBy": "user-123",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

#### Task Status Update

```json
{
  "type": "task_status_updated",
  "data": {
    "taskId": "task-789",
    "oldStatus": "pending",
    "newStatus": "in_progress",
    "updatedBy": "user-456",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

#### File Change Notification

```json
{
  "type": "file_changed",
  "data": {
    "repositoryId": "repo-123",
    "filePath": "lib/services/auth_service.dart",
    "changeType": "modified",
    "changedBy": "user-456",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

#### Security Alert

```json
{
  "type": "security_alert",
  "data": {
    "alertId": "alert-456",
    "severity": "high",
    "message": "Suspicious API key access detected",
    "affectedUsers": ["user-123", "user-456"],
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

#### Deployment Status

```json
{
  "type": "deployment_status",
  "data": {
    "deploymentId": "deploy-789",
    "status": "completed",
    "environment": "staging",
    "repositoryId": "repo-123",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

### Subscribing to Channels

```json
{
  "type": "subscribe",
  "channels": ["tasks", "repositories", "security", "deployments"]
}
```

### Unsubscribing from Channels

```json
{
  "type": "unsubscribe",
  "channels": ["deployments"]
}
```

## DevOps Integration API

### Create Deployment

```http
POST /api/v1/deployments
Authorization: Bearer <token>
Content-Type: application/json

{
  "repositoryId": "repo-123",
  "environment": "staging",
  "version": "1.2.0",
  "branch": "main",
  "deploymentType": "automated",
  "configuration": {
    "buildCommand": "flutter build web",
    "testCommand": "flutter test",
    "deployCommand": "docker deploy"
  }
}
```

### Get Deployments

```http
GET /api/v1/deployments
Authorization: Bearer <token>
```

**Query Parameters:**
- `repositoryId` (optional): Filter by repository
- `environment` (optional): Filter by environment
- `status` (optional): Filter by status

### Get Deployment by ID

```http
GET /api/v1/deployments/{deploymentId}
Authorization: Bearer <token>
```

### Trigger Deployment

```http
POST /api/v1/deployments/{deploymentId}/trigger
Authorization: Bearer <token>
```

### Rollback Deployment

```http
POST /api/v1/deployments/{deploymentId}/rollback
Authorization: Bearer <token>
Content-Type: application/json

{
  "targetVersion": "1.1.0",
  "reason": "Critical bug found in version 1.2.0"
}
```

### Get Deployment Logs

```http
GET /api/v1/deployments/{deploymentId}/logs
Authorization: Bearer <token>
```

**Query Parameters:**
- `tail` (optional): Number of recent log lines
- `follow` (optional): Stream logs in real-time

## Security Monitoring API

### Get Security Status

```http
GET /api/v1/security/status
Authorization: Bearer <token>
```

**Response:**
```json
{
  "success": true,
  "status": {
    "isMonitoring": true,
    "honeytokensDeployed": 15,
    "activeAlerts": 2,
    "lastScanTime": "2024-01-15T10:30:00Z",
    "threatLevel": "medium"
  }
}
```

### Get Security Alerts

```http
GET /api/v1/security/alerts
Authorization: Bearer <token>
```

**Query Parameters:**
- `severity` (optional): Filter by severity
- `status` (optional): Filter by status
- `limit` (optional): Number of alerts to return

### Get Alert by ID

```http
GET /api/v1/security/alerts/{alertId}
Authorization: Bearer <token>
```

### Update Alert Status

```http
PATCH /api/v1/security/alerts/{alertId}/status
Authorization: Bearer <token>
Content-Type: application/json

{
  "status": "investigating",
  "assignedTo": "user-123",
  "notes": "Investigating potential API key compromise"
}
```

### Deploy Honeytokens

```http
POST /api/v1/security/honeytokens
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "type": "api_key",
  "context": "user_profile_service",
  "description": "Honeytoken for user profile API monitoring"
}
```

## Error Handling

All API endpoints return consistent error responses:

### Error Response Format

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input parameters",
    "details": {
      "field": "email",
      "reason": "Invalid email format"
    },
    "timestamp": "2024-01-15T10:30:00Z",
    "requestId": "req-123456"
  }
}
```

### Common Error Codes

- `AUTHENTICATION_REQUIRED` (401): Missing or invalid authentication token
- `INSUFFICIENT_PERMISSIONS` (403): User lacks required permissions
- `RESOURCE_NOT_FOUND` (404): Requested resource does not exist
- `VALIDATION_ERROR` (400): Invalid input parameters
- `RATE_LIMIT_EXCEEDED` (429): Too many requests
- `INTERNAL_SERVER_ERROR` (500): Server-side error
- `SERVICE_UNAVAILABLE` (503): Service temporarily unavailable

## Rate Limiting

API endpoints are rate-limited to ensure fair usage:

### Rate Limit Headers

All responses include rate limit information:

```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1642248000
```

### Rate Limits by Endpoint Type

- **Authentication**: 10 requests per minute
- **User Management**: 100 requests per hour
- **Task Operations**: 500 requests per hour
- **Repository Operations**: 200 requests per hour
- **File Operations**: 1000 requests per hour
- **WebSocket Messages**: 100 messages per minute

## API Versioning

The API uses URL-based versioning:

- Current version: `v1`
- Base URL: `/api/v1/`
- Deprecated versions are supported for 6 months after new version release

### Version Headers

Include version information in requests:

```http
Accept: application/vnd.devguard.v1+json
```

## SDK and Client Libraries

### Dart/Flutter SDK

```dart
import 'package:devguard_api_client/devguard_api_client.dart';

final client = DevGuardApiClient(
  baseUrl: 'https://api.devguard.com',
  apiKey: 'your_api_key',
);

// Authenticate
final authResult = await client.auth.login(
  email: 'user@example.com',
  password: 'password',
);

// Create task
final task = await client.tasks.create(
  title: 'New Feature',
  description: 'Implement new feature',
  type: TaskType.feature,
);
```

### JavaScript SDK

```javascript
import { DevGuardClient } from '@devguard/api-client';

const client = new DevGuardClient({
  baseUrl: 'https://api.devguard.com',
  apiKey: 'your_api_key'
});

// Authenticate
const authResult = await client.auth.login({
  email: 'user@example.com',
  password: 'password'
});

// Create task
const task = await client.tasks.create({
  title: 'New Feature',
  description: 'Implement new feature',
  type: 'feature'
});
```

## Testing and Development

### API Testing

Use the provided test endpoints for development:

```http
GET /api/v1/health
```

**Response:**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "timestamp": "2024-01-15T10:30:00Z",
  "services": {
    "database": "healthy",
    "websocket": "healthy",
    "security": "healthy"
  }
}
```

### Mock Data

Development environment includes mock data endpoints:

```http
GET /api/v1/mock/users
GET /api/v1/mock/tasks
GET /api/v1/mock/repositories
```

## Support and Documentation

- **API Documentation**: [https://docs.devguard.com/api](https://docs.devguard.com/api)
- **SDK Documentation**: [https://docs.devguard.com/sdk](https://docs.devguard.com/sdk)
- **Support**: [support@devguard.com](mailto:support@devguard.com)
- **GitHub Issues**: [https://github.com/devguard/api/issues](https://github.com/devguard/api/issues)

---

**Last Updated**: January 15, 2024  
**API Version**: v1.0.0