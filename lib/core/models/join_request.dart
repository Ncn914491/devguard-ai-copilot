/// Join request model for new member onboarding
class JoinRequest {
  final String id;
  final String name;
  final String email;
  final String requestedRole;
  final String? message;
  final JoinRequestStatus status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? adminNotes;
  final String? rejectionReason;

  JoinRequest({
    required this.id,
    required this.name,
    required this.email,
    required this.requestedRole,
    this.message,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.adminNotes,
    this.rejectionReason,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    return JoinRequest(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      requestedRole: json['requested_role'],
      message: json['message'],
      status: JoinRequestStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
      ),
      createdAt: DateTime.parse(json['created_at']),
      reviewedAt: json['reviewed_at'] != null ? DateTime.parse(json['reviewed_at']) : null,
      reviewedBy: json['reviewed_by'],
      adminNotes: json['admin_notes'],
      rejectionReason: json['rejection_reason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'requested_role': requestedRole,
      'message': message,
      'status': status.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'reviewed_by': reviewedBy,
      'admin_notes': adminNotes,
      'rejection_reason': rejectionReason,
    };
  }

  JoinRequest copyWith({
    String? id,
    String? name,
    String? email,
    String? requestedRole,
    String? message,
    JoinRequestStatus? status,
    DateTime? createdAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? adminNotes,
    String? rejectionReason,
  }) {
    return JoinRequest(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      requestedRole: requestedRole ?? this.requestedRole,
      message: message ?? this.message,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      adminNotes: adminNotes ?? this.adminNotes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}

enum JoinRequestStatus {
  pending,
  approved,
  rejected,
}

/// Request submission result
class RequestResult {
  final bool success;
  final String message;
  final String? requestId;

  RequestResult({
    required this.success,
    required this.message,
    this.requestId,
  });
}

/// Request status tracking
class RequestStatus {
  final String requestId;
  final JoinRequestStatus status;
  final String? message;
  final DateTime lastUpdated;

  RequestStatus({
    required this.requestId,
    required this.status,
    this.message,
    required this.lastUpdated,
  });
}