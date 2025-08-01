class Specification {
  final String id;
  final String rawInput;
  final String aiInterpretation;
  final String suggestedBranchName;
  final String suggestedCommitMessage;
  final String? placeholderDiff;
  final String status; // 'draft', 'approved', 'in_progress', 'completed'
  final String? assignedTo;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? approvedBy;

  Specification({
    required this.id,
    required this.rawInput,
    required this.aiInterpretation,
    required this.suggestedBranchName,
    required this.suggestedCommitMessage,
    this.placeholderDiff,
    required this.status,
    this.assignedTo,
    required this.createdAt,
    this.approvedAt,
    this.approvedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'raw_input': rawInput,
      'ai_interpretation': aiInterpretation,
      'suggested_branch_name': suggestedBranchName,
      'suggested_commit_message': suggestedCommitMessage,
      'placeholder_diff': placeholderDiff,
      'status': status,
      'assigned_to': assignedTo,
      'created_at': createdAt.millisecondsSinceEpoch,
      'approved_at': approvedAt?.millisecondsSinceEpoch,
      'approved_by': approvedBy,
    };
  }

  factory Specification.fromMap(Map<String, dynamic> map) {
    return Specification(
      id: map['id'] ?? '',
      rawInput: map['raw_input'] ?? '',
      aiInterpretation: map['ai_interpretation'] ?? '',
      suggestedBranchName: map['suggested_branch_name'] ?? '',
      suggestedCommitMessage: map['suggested_commit_message'] ?? '',
      placeholderDiff: map['placeholder_diff'],
      status: map['status'] ?? 'draft',
      assignedTo: map['assigned_to'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
      approvedAt: map['approved_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['approved_at']) 
          : null,
      approvedBy: map['approved_by'],
    );
  }

  Specification copyWith({
    String? id,
    String? rawInput,
    String? aiInterpretation,
    String? suggestedBranchName,
    String? suggestedCommitMessage,
    String? placeholderDiff,
    String? status,
    String? assignedTo,
    DateTime? createdAt,
    DateTime? approvedAt,
    String? approvedBy,
  }) {
    return Specification(
      id: id ?? this.id,
      rawInput: rawInput ?? this.rawInput,
      aiInterpretation: aiInterpretation ?? this.aiInterpretation,
      suggestedBranchName: suggestedBranchName ?? this.suggestedBranchName,
      suggestedCommitMessage: suggestedCommitMessage ?? this.suggestedCommitMessage,
      placeholderDiff: placeholderDiff ?? this.placeholderDiff,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
    );
  }
}