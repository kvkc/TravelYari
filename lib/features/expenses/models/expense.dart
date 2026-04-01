import 'package:uuid/uuid.dart';

enum SplitType {
  equal,
  unequal,
  percentage,
}

class ExpenseShare {
  final String participantId;
  final double amount;
  final double? percentage;
  final bool isIncluded;

  const ExpenseShare({
    required this.participantId,
    required this.amount,
    this.percentage,
    this.isIncluded = true,
  });

  ExpenseShare copyWith({
    String? participantId,
    double? amount,
    double? percentage,
    bool? isIncluded,
  }) {
    return ExpenseShare(
      participantId: participantId ?? this.participantId,
      amount: amount ?? this.amount,
      percentage: percentage ?? this.percentage,
      isIncluded: isIncluded ?? this.isIncluded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'participantId': participantId,
      'amount': amount,
      'percentage': percentage,
      'isIncluded': isIncluded,
    };
  }

  factory ExpenseShare.fromJson(Map<String, dynamic> json) {
    return ExpenseShare(
      participantId: json['participantId'] as String,
      amount: (json['amount'] as num).toDouble(),
      percentage: json['percentage'] != null
          ? (json['percentage'] as num).toDouble()
          : null,
      isIncluded: json['isIncluded'] as bool? ?? true,
    );
  }
}

class Expense {
  final String id;
  final String tripId;
  final String description;
  final String category;
  final double amount;
  final String currencyCode;
  final String paidByParticipantId;
  final SplitType splitType;
  final List<ExpenseShare> shares;
  final DateTime expenseDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdByUserId;
  final String? receiptImagePath;
  final String? notes;

  Expense({
    String? id,
    required this.tripId,
    required this.description,
    required this.category,
    required this.amount,
    required this.currencyCode,
    required this.paidByParticipantId,
    this.splitType = SplitType.equal,
    List<ExpenseShare>? shares,
    DateTime? expenseDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.createdByUserId,
    this.receiptImagePath,
    this.notes,
  })  : id = id ?? const Uuid().v4(),
        shares = shares ?? [],
        expenseDate = expenseDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Expense copyWith({
    String? id,
    String? tripId,
    String? description,
    String? category,
    double? amount,
    String? currencyCode,
    String? paidByParticipantId,
    SplitType? splitType,
    List<ExpenseShare>? shares,
    DateTime? expenseDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdByUserId,
    String? receiptImagePath,
    String? notes,
  }) {
    return Expense(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      description: description ?? this.description,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      currencyCode: currencyCode ?? this.currencyCode,
      paidByParticipantId: paidByParticipantId ?? this.paidByParticipantId,
      splitType: splitType ?? this.splitType,
      shares: shares ?? this.shares,
      expenseDate: expenseDate ?? this.expenseDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'description': description,
      'category': category,
      'amount': amount,
      'currencyCode': currencyCode,
      'paidByParticipantId': paidByParticipantId,
      'splitType': splitType.name,
      'shares': shares.map((s) => s.toJson()).toList(),
      'expenseDate': expenseDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdByUserId': createdByUserId,
      'receiptImagePath': receiptImagePath,
      'notes': notes,
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      currencyCode: json['currencyCode'] as String,
      paidByParticipantId: json['paidByParticipantId'] as String,
      splitType: SplitType.values.firstWhere(
        (e) => e.name == json['splitType'],
        orElse: () => SplitType.equal,
      ),
      shares: (json['shares'] as List<dynamic>?)
              ?.map((s) => ExpenseShare.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      expenseDate: DateTime.parse(json['expenseDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      createdByUserId: json['createdByUserId'] as String?,
      receiptImagePath: json['receiptImagePath'] as String?,
      notes: json['notes'] as String?,
    );
  }

  /// Create equal shares for all participants
  static List<ExpenseShare> createEqualShares(
    double totalAmount,
    List<String> participantIds,
  ) {
    if (participantIds.isEmpty) return [];
    final shareAmount = totalAmount / participantIds.length;
    return participantIds
        .map((id) => ExpenseShare(
              participantId: id,
              amount: double.parse(shareAmount.toStringAsFixed(2)),
              isIncluded: true,
            ))
        .toList();
  }
}
