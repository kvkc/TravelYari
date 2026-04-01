class DebtRecord {
  final String fromParticipantId;
  final String toParticipantId;
  final double amount;
  final String currencyCode;

  const DebtRecord({
    required this.fromParticipantId,
    required this.toParticipantId,
    required this.amount,
    required this.currencyCode,
  });

  DebtRecord copyWith({
    String? fromParticipantId,
    String? toParticipantId,
    double? amount,
    String? currencyCode,
  }) {
    return DebtRecord(
      fromParticipantId: fromParticipantId ?? this.fromParticipantId,
      toParticipantId: toParticipantId ?? this.toParticipantId,
      amount: amount ?? this.amount,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fromParticipantId': fromParticipantId,
      'toParticipantId': toParticipantId,
      'amount': amount,
      'currencyCode': currencyCode,
    };
  }

  factory DebtRecord.fromJson(Map<String, dynamic> json) {
    return DebtRecord(
      fromParticipantId: json['fromParticipantId'] as String,
      toParticipantId: json['toParticipantId'] as String,
      amount: (json['amount'] as num).toDouble(),
      currencyCode: json['currencyCode'] as String,
    );
  }
}

class ParticipantBalance {
  final String participantId;
  final double totalPaid;
  final double totalOwed;
  final double netBalance;
  final Map<String, double> paidByCategory;
  final int expenseCount;

  const ParticipantBalance({
    required this.participantId,
    required this.totalPaid,
    required this.totalOwed,
    required this.netBalance,
    this.paidByCategory = const {},
    this.expenseCount = 0,
  });

  bool get isOwed => netBalance > 0;
  bool get owes => netBalance < 0;
  bool get isSettled => netBalance.abs() < 0.01;

  Map<String, dynamic> toJson() {
    return {
      'participantId': participantId,
      'totalPaid': totalPaid,
      'totalOwed': totalOwed,
      'netBalance': netBalance,
      'paidByCategory': paidByCategory,
      'expenseCount': expenseCount,
    };
  }

  factory ParticipantBalance.fromJson(Map<String, dynamic> json) {
    return ParticipantBalance(
      participantId: json['participantId'] as String,
      totalPaid: (json['totalPaid'] as num).toDouble(),
      totalOwed: (json['totalOwed'] as num).toDouble(),
      netBalance: (json['netBalance'] as num).toDouble(),
      paidByCategory: Map<String, double>.from(
        (json['paidByCategory'] as Map?)?.map(
              (key, value) => MapEntry(key as String, (value as num).toDouble()),
            ) ??
            {},
      ),
      expenseCount: json['expenseCount'] as int? ?? 0,
    );
  }
}

class SettlementSummary {
  final String tripId;
  final String primaryCurrencyCode;
  final Map<String, double> participantBalances;
  final List<ParticipantBalance> participantDetails;
  final List<DebtRecord> simplifiedDebts;
  final double totalExpenses;
  final Map<String, double> expensesByCategory;
  final DateTime calculatedAt;

  const SettlementSummary({
    required this.tripId,
    required this.primaryCurrencyCode,
    required this.participantBalances,
    this.participantDetails = const [],
    required this.simplifiedDebts,
    required this.totalExpenses,
    this.expensesByCategory = const {},
    required this.calculatedAt,
  });

  bool get isSettled => simplifiedDebts.isEmpty;
  int get participantCount => participantBalances.length;
  double get averagePerPerson =>
      participantCount > 0 ? totalExpenses / participantCount : 0;

  Map<String, dynamic> toJson() {
    return {
      'tripId': tripId,
      'primaryCurrencyCode': primaryCurrencyCode,
      'participantBalances': participantBalances,
      'participantDetails': participantDetails.map((p) => p.toJson()).toList(),
      'simplifiedDebts': simplifiedDebts.map((d) => d.toJson()).toList(),
      'totalExpenses': totalExpenses,
      'expensesByCategory': expensesByCategory,
      'calculatedAt': calculatedAt.toIso8601String(),
    };
  }

  factory SettlementSummary.fromJson(Map<String, dynamic> json) {
    return SettlementSummary(
      tripId: json['tripId'] as String,
      primaryCurrencyCode: json['primaryCurrencyCode'] as String,
      participantBalances: Map<String, double>.from(
        (json['participantBalances'] as Map).map(
          (key, value) => MapEntry(key as String, (value as num).toDouble()),
        ),
      ),
      participantDetails: (json['participantDetails'] as List<dynamic>?)
              ?.map((p) => ParticipantBalance.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      simplifiedDebts: (json['simplifiedDebts'] as List<dynamic>)
          .map((d) => DebtRecord.fromJson(d as Map<String, dynamic>))
          .toList(),
      totalExpenses: (json['totalExpenses'] as num).toDouble(),
      expensesByCategory: Map<String, double>.from(
        (json['expensesByCategory'] as Map?)?.map(
              (key, value) => MapEntry(key as String, (value as num).toDouble()),
            ) ??
            {},
      ),
      calculatedAt: DateTime.parse(json['calculatedAt'] as String),
    );
  }

  factory SettlementSummary.empty(String tripId, String currencyCode) {
    return SettlementSummary(
      tripId: tripId,
      primaryCurrencyCode: currencyCode,
      participantBalances: {},
      simplifiedDebts: [],
      totalExpenses: 0,
      calculatedAt: DateTime.now(),
    );
  }
}
