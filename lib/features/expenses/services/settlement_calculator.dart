import 'dart:math';

import '../../trip_planning/models/trip.dart';
import '../models/currency.dart';
import '../models/expense.dart';
import '../models/settlement.dart';

class SettlementCalculator {
  /// Calculate net balances for all participants
  /// Positive = they are owed money, Negative = they owe money
  static Map<String, double> calculateBalances(
    List<Expense> expenses,
    List<TripParticipant> participants,
    TripCurrencySettings currencySettings,
  ) {
    final balances = <String, double>{};

    // Initialize all participants with 0 balance
    for (final p in participants) {
      balances[p.id] = 0.0;
    }

    for (final expense in expenses) {
      // Convert to primary currency
      final amountInPrimary = currencySettings.toBase(
        expense.amount,
        expense.currencyCode,
      );

      // Add to payer's balance (they paid, so they're owed)
      balances[expense.paidByParticipantId] =
          (balances[expense.paidByParticipantId] ?? 0) + amountInPrimary;

      // Subtract shares from each participant
      for (final share in expense.shares) {
        if (share.isIncluded) {
          final shareInPrimary = currencySettings.toBase(
            share.amount,
            expense.currencyCode,
          );
          balances[share.participantId] =
              (balances[share.participantId] ?? 0) - shareInPrimary;
        }
      }
    }

    return balances;
  }

  /// Calculate detailed balance info per participant
  static List<ParticipantBalance> calculateDetailedBalances(
    List<Expense> expenses,
    List<TripParticipant> participants,
    TripCurrencySettings currencySettings,
  ) {
    final details = <String, ParticipantBalance>{};

    // Initialize
    for (final p in participants) {
      details[p.id] = ParticipantBalance(
        participantId: p.id,
        totalPaid: 0,
        totalOwed: 0,
        netBalance: 0,
        paidByCategory: {},
        expenseCount: 0,
      );
    }

    for (final expense in expenses) {
      final amountInPrimary = currencySettings.toBase(
        expense.amount,
        expense.currencyCode,
      );

      // Update payer's totals
      final payerId = expense.paidByParticipantId;
      if (details.containsKey(payerId)) {
        final current = details[payerId]!;
        final categoryTotals = Map<String, double>.from(current.paidByCategory);
        categoryTotals[expense.category] =
            (categoryTotals[expense.category] ?? 0) + amountInPrimary;

        details[payerId] = ParticipantBalance(
          participantId: payerId,
          totalPaid: current.totalPaid + amountInPrimary,
          totalOwed: current.totalOwed,
          netBalance: current.netBalance + amountInPrimary,
          paidByCategory: categoryTotals,
          expenseCount: current.expenseCount + 1,
        );
      }

      // Update each participant's owed amount
      for (final share in expense.shares) {
        if (share.isIncluded && details.containsKey(share.participantId)) {
          final shareInPrimary = currencySettings.toBase(
            share.amount,
            expense.currencyCode,
          );
          final current = details[share.participantId]!;
          details[share.participantId] = ParticipantBalance(
            participantId: share.participantId,
            totalPaid: current.totalPaid,
            totalOwed: current.totalOwed + shareInPrimary,
            netBalance: current.netBalance - shareInPrimary,
            paidByCategory: current.paidByCategory,
            expenseCount: current.expenseCount,
          );
        }
      }
    }

    return details.values.toList();
  }

  /// Simplify debts using greedy algorithm
  /// Minimizes the number of transactions needed to settle
  static List<DebtRecord> simplifyDebts(
    Map<String, double> balances,
    String currencyCode,
  ) {
    final debts = <DebtRecord>[];
    const threshold = 0.01; // Small threshold for floating point comparison

    // Separate into creditors (positive) and debtors (negative)
    final creditors = <_BalanceEntry>[];
    final debtors = <_BalanceEntry>[];

    for (final entry in balances.entries) {
      if (entry.value > threshold) {
        creditors.add(_BalanceEntry(entry.key, entry.value));
      } else if (entry.value < -threshold) {
        debtors.add(_BalanceEntry(entry.key, entry.value.abs()));
      }
    }

    // Sort by amount (descending) for efficiency
    creditors.sort((a, b) => b.amount.compareTo(a.amount));
    debtors.sort((a, b) => b.amount.compareTo(a.amount));

    // Greedy matching
    int i = 0, j = 0;
    while (i < creditors.length && j < debtors.length) {
      final creditor = creditors[i];
      final debtor = debtors[j];

      final amount = min(creditor.amount, debtor.amount);

      if (amount > threshold) {
        debts.add(DebtRecord(
          fromParticipantId: debtor.id,
          toParticipantId: creditor.id,
          amount: double.parse(amount.toStringAsFixed(2)),
          currencyCode: currencyCode,
        ));
      }

      // Update remaining amounts
      creditors[i] = _BalanceEntry(creditor.id, creditor.amount - amount);
      debtors[j] = _BalanceEntry(debtor.id, debtor.amount - amount);

      if (creditors[i].amount < threshold) i++;
      if (debtors[j].amount < threshold) j++;
    }

    return debts;
  }

  /// Calculate complete settlement summary
  static SettlementSummary calculateSettlement({
    required String tripId,
    required List<Expense> expenses,
    required List<TripParticipant> participants,
    required TripCurrencySettings currencySettings,
  }) {
    if (expenses.isEmpty || participants.isEmpty) {
      return SettlementSummary.empty(tripId, currencySettings.primaryCurrencyCode);
    }

    final balances = calculateBalances(expenses, participants, currencySettings);
    final detailedBalances =
        calculateDetailedBalances(expenses, participants, currencySettings);
    final debts = simplifyDebts(balances, currencySettings.primaryCurrencyCode);

    // Calculate totals
    double totalExpenses = 0;
    final expensesByCategory = <String, double>{};

    for (final expense in expenses) {
      final amountInPrimary = currencySettings.toBase(
        expense.amount,
        expense.currencyCode,
      );
      totalExpenses += amountInPrimary;
      expensesByCategory[expense.category] =
          (expensesByCategory[expense.category] ?? 0) + amountInPrimary;
    }

    return SettlementSummary(
      tripId: tripId,
      primaryCurrencyCode: currencySettings.primaryCurrencyCode,
      participantBalances: balances,
      participantDetails: detailedBalances,
      simplifiedDebts: debts,
      totalExpenses: totalExpenses,
      expensesByCategory: expensesByCategory,
      calculatedAt: DateTime.now(),
    );
  }
}

class _BalanceEntry {
  final String id;
  final double amount;

  _BalanceEntry(this.id, this.amount);
}
