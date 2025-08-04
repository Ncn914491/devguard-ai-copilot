import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../database_service.dart';
import '../../auth/auth_service.dart';
import 'audit_log_service.dart';

/// Database service for user management
class UserService {
  static final UserService _instance = UserService._internal();
  static UserService get instance => _instance;
  UserService._internal();

  final _uuid = const Uuid();
  final _auditService = AuditLogService.instance;

  Future<Database> get _db async => await DatabaseService.instance.database;

  /// Create a new user
  /// Satisfies Requirements: 2.4 (Automatic account generation upon approval)
  Future<String> createUser(User user) async {
    final db = await _db;
    final id = user.id.isEmpty ? _uuid.v4() : user.id;

    final userWithId = user.copyWith(
      id: id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await db.insert('users', _userToMap(userWithId));

    // Log the action for transparency
    await _auditService.logAction(
      actionType: 'user_created',
      description: 'New user account created: ${user.name} (${user.email})',
      aiReasoning:
          'User account created through approval process or manual addition',
      contextData: {
        'user_id': id,
        'name': user.name,
        'email': user.email,
        'role': user.role,
      },
    );

    return id;
  }

  /// Get user by ID
  /// Satisfies Requirements: 3.1 (User authentication and lookup)
  Future<User?> getUser(String id) async {
    final db = await _db;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return _userFromMap(maps.first);
    }
    return null;
  }

  /// Get user by email
  /// Satisfies Requirements: 3.1 (Email-based authentication)
  Future<User?> getUserByEmail(String email) async {
    final db = await _db;
    final maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );

    if (maps.isNotEmpty) {
      return _userFromMap(maps.first);
    }
    return null;
  }

  /// Get all users with optional role filter
  /// Satisfies Requirements: 6.1 (Admin dashboard with user management)
  Future<List<User>> getUsers({String? role, String? status}) async {
    final db = await _db;

    String? whereClause;
    List<dynamic>? whereArgs;

    if (role != null && status != null) {
      whereClause = 'role = ? AND status = ?';
      whereArgs = [role, status];
    } else if (role != null) {
      whereClause = 'role = ?';
      whereArgs = [role];
    } else if (status != null) {
      whereClause = 'status = ?';
      whereArgs = [status];
    }

    final maps = await db.query(
      'users',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => _userFromMap(map)).toList();
  }

  /// Update user
  /// Satisfies Requirements: 6.1 (User management and role updates)
  Future<void> updateUser(User user) async {
    final db = await _db;
    final updatedUser = user.copyWith(updatedAt: DateTime.now());

    await db.update(
      'users',
      _userToMap(updatedUser),
      where: 'id = ?',
      whereArgs: [user.id],
    );

    // Log the action for transparency
    await _auditService.logAction(
      actionType: 'user_updated',
      description: 'User account updated: ${user.name}',
      contextData: {
        'user_id': user.id,
        'role': user.role,
        'status': user.status,
      },
    );
  }

  /// Update user password
  /// Satisfies Requirements: 3.3 (Password reset functionality)
  Future<void> updateUserPassword(String userId, String newPassword) async {
    final user = await getUser(userId);
    if (user == null) {
      throw Exception('User not found');
    }

    final hashedPassword = _hashPassword(newPassword);
    final updatedUser = user.copyWith(
      passwordHash: hashedPassword,
      updatedAt: DateTime.now(),
    );

    await updateUser(updatedUser);

    // Log the action for security
    await _auditService.logAction(
      actionType: 'password_updated',
      description: 'User password updated: ${user.email}',
      aiReasoning: 'Password reset by admin or user password change',
      contextData: {'user_id': userId},
    );
  }

  /// Update user last login
  /// Satisfies Requirements: 3.4 (Session management and tracking)
  Future<void> updateLastLogin(String userId) async {
    final db = await _db;

    await db.update(
      'users',
      {'last_login': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Delete user
  /// Satisfies Requirements: 6.1 (User management)
  Future<void> deleteUser(String id) async {
    final db = await _db;
    final user = await getUser(id);

    await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Log the action for transparency
    await _auditService.logAction(
      actionType: 'user_deleted',
      description: 'User account deleted: ${user?.name ?? id}',
      contextData: {'user_id': id},
    );
  }

  /// Verify user credentials
  /// Satisfies Requirements: 3.1 (Secure authentication)
  Future<User?> verifyCredentials(String email, String password) async {
    final user = await getUserByEmail(email);
    if (user == null) return null;

    final hashedPassword = _hashPassword(password);
    if (user.passwordHash != hashedPassword) return null;

    // Update last login
    await updateLastLogin(user.id);

    return user;
  }

  /// Check if email exists
  /// Satisfies Requirements: 2.1 (Validation to prevent duplicate accounts)
  Future<bool> emailExists(String email) async {
    final user = await getUserByEmail(email);
    return user != null;
  }

  /// Get user statistics
  /// Satisfies Requirements: 6.1 (Admin dashboard analytics)
  Future<Map<String, int>> getUserStats() async {
    final db = await _db;

    final totalResult =
        await db.rawQuery('SELECT COUNT(*) as count FROM users');
    final activeResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM users WHERE status = ?', ['active']);
    final adminResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM users WHERE role = ?', ['admin']);
    final developerResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM users WHERE role = ?', ['developer']);

    return {
      'total': totalResult.first['count'] as int,
      'active': activeResult.first['count'] as int,
      'admins': adminResult.first['count'] as int,
      'developers': developerResult.first['count'] as int,
    };
  }

  /// Hash password using SHA-256
  String hashPassword(String password) {
    final bytes = utf8.encode('${password}devguard_salt');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Private hash method for internal use
  String _hashPassword(String password) => hashPassword(password);

  /// Convert User to database map
  Map<String, dynamic> _userToMap(User user) {
    return {
      'id': user.id,
      'email': user.email,
      'name': user.name,
      'role': user.role,
      'status': user.status,
      'password_hash': user.passwordHash,
      'github_username': user.githubUsername,
      'avatar_url': user.avatarUrl,
      'created_at': user.createdAt.millisecondsSinceEpoch,
      'updated_at': user.updatedAt.millisecondsSinceEpoch,
      'last_login': user.lastLogin?.millisecondsSinceEpoch,
    };
  }

  /// Convert database map to User
  User _userFromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      email: map['email'],
      name: map['name'],
      role: map['role'],
      status: map['status'],
      passwordHash: map['password_hash'],
      githubUsername: map['github_username'],
      avatarUrl: map['avatar_url'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
      lastLogin: map['last_login'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_login'])
          : null,
    );
  }
}

/// Extended User model with additional fields
extension UserExtension on User {
  User copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    String? status,
    String? passwordHash,
    String? githubUsername,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLogin,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      status: status ?? this.status,
      passwordHash: passwordHash ?? this.passwordHash,
      githubUsername: githubUsername ?? this.githubUsername,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}

/// Extended User model with lastLogin field
class User {
  final String id;
  final String email;
  final String name;
  final String role;
  final String status;
  final String passwordHash;
  final String? githubUsername;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLogin;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.status,
    required this.passwordHash,
    this.githubUsername,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
    this.lastLogin,
  });
}
