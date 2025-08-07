# Supabase Integration

This directory contains the core Supabase integration for the DevGuard AI Copilot application.

## Files

- `supabase_service.dart` - Main service for Supabase client initialization and management
- `supabase_config.dart` - Configuration management for Supabase environment variables
- `supabase_error_handler.dart` - Comprehensive error handling for Supabase operations

## Setup

1. **Environment Variables**: Ensure the following variables are set in your `.env` file:
   ```
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key
   SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
   ```

2. **Initialization**: The Supabase service is automatically initialized in `main.dart`:
   ```dart
   await SupabaseService.instance.initialize();
   ```

3. **Usage**: Access the Supabase client anywhere in your app:
   ```dart
   final client = SupabaseService.instance.client;
   ```

## Features

- ✅ Automatic environment configuration loading
- ✅ Connection validation and testing
- ✅ Comprehensive error handling
- ✅ Debug logging and configuration summary
- ✅ Singleton pattern for global access

## Error Handling

The `SupabaseErrorHandler` provides user-friendly error messages for:
- Database errors (PostgrestException)
- Authentication errors (AuthException)
- Storage errors (StorageException)
- Real-time errors (RealtimeException)

## Testing

Run the setup tests to verify configuration:
```bash
flutter test test/supabase_setup_test.dart
```

## Next Steps

After completing Task 1, the next tasks will involve:
- Creating authentication services
- Implementing database services
- Setting up real-time subscriptions
- Migrating existing data models