import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/services/sync/trip_sync_service.dart';
import '../../trip_planning/models/trip.dart';
import '../models/currency.dart';
import '../models/expense.dart';
import '../models/settlement.dart';
import 'currency_service.dart';
import 'settlement_calculator.dart';

class ExpenseService {
  final CurrencyService _currencyService;
  final TripSyncService _syncService;

  ExpenseService({
    CurrencyService? currencyService,
    required TripSyncService syncService,
  })  : _currencyService = currencyService ?? CurrencyService(),
        _syncService = syncService;

  // CRUD Operations

  Future<void> addExpense(Expense expense) async {
    await StorageService.saveExpense(expense);
    _syncService.syncExpense(expense);
  }

  Future<void> updateExpense(Expense expense) async {
    final updated = expense.copyWith(updatedAt: DateTime.now());
    await StorageService.saveExpense(updated);
    _syncService.syncExpense(updated);
  }

  Future<void> deleteExpense(String expenseId) async {
    final expense = StorageService.getExpense(expenseId);
    await StorageService.deleteExpense(expenseId);
    if (expense != null) {
      _syncService.deleteExpenseFromCloud(expenseId, expense.tripId);
    }
  }

  Expense? getExpense(String expenseId) {
    return StorageService.getExpense(expenseId);
  }

  List<Expense> getTripExpenses(String tripId) {
    return StorageService.getTripExpenses(tripId);
  }

  // Summary and Settlement

  Future<SettlementSummary> calculateSettlement({
    required String tripId,
    required List<TripParticipant> participants,
    TripCurrencySettings? currencySettings,
  }) async {
    final expenses = getTripExpenses(tripId);

    // Use provided settings or create defaults
    final settings = currencySettings ??
        await _currencyService.createTripCurrencySettings('INR');

    return SettlementCalculator.calculateSettlement(
      tripId: tripId,
      expenses: expenses,
      participants: participants,
      currencySettings: settings,
    );
  }

  double getTripTotal(String tripId, TripCurrencySettings currencySettings) {
    final expenses = getTripExpenses(tripId);
    double total = 0;

    for (final expense in expenses) {
      total += currencySettings.toBase(expense.amount, expense.currencyCode);
    }

    return total;
  }

  Map<String, double> getExpensesByCategory(
    String tripId,
    TripCurrencySettings currencySettings,
  ) {
    final expenses = getTripExpenses(tripId);
    final byCategory = <String, double>{};

    for (final expense in expenses) {
      final amount = currencySettings.toBase(
        expense.amount,
        expense.currencyCode,
      );
      byCategory[expense.category] = (byCategory[expense.category] ?? 0) + amount;
    }

    return byCategory;
  }

  Set<String> getUsedCategories(String tripId) {
    final expenses = getTripExpenses(tripId);
    return expenses.map((e) => e.category).toSet();
  }

  Set<String> getUsedCurrencies(String tripId) {
    final expenses = getTripExpenses(tripId);
    return expenses.map((e) => e.currencyCode).toSet();
  }

  // Helper to create an expense with equal split
  Expense createEqualSplitExpense({
    required String tripId,
    required String description,
    required String category,
    required double amount,
    required String currencyCode,
    required String paidByParticipantId,
    required List<TripParticipant> participants,
    String? notes,
    String? createdByUserId,
  }) {
    final participantIds = participants.map((p) => p.id).toList();
    final shares = Expense.createEqualShares(amount, participantIds);

    return Expense(
      tripId: tripId,
      description: description,
      category: category,
      amount: amount,
      currencyCode: currencyCode,
      paidByParticipantId: paidByParticipantId,
      splitType: SplitType.equal,
      shares: shares,
      notes: notes,
      createdByUserId: createdByUserId,
    );
  }
}

// Providers

final currencyServiceProvider = Provider<CurrencyService>((ref) {
  return CurrencyService();
});

final expenseServiceProvider = Provider<ExpenseService>((ref) {
  return ExpenseService(
    currencyService: ref.watch(currencyServiceProvider),
    syncService: ref.watch(tripSyncServiceProvider.notifier),
  );
});

final tripExpensesProvider =
    Provider.family<List<Expense>, String>((ref, tripId) {
  final service = ref.watch(expenseServiceProvider);
  return service.getTripExpenses(tripId);
});

final tripExpenseTotalProvider =
    Provider.family<double, (String, TripCurrencySettings)>((ref, args) {
  final (tripId, currencySettings) = args;
  final service = ref.watch(expenseServiceProvider);
  return service.getTripTotal(tripId, currencySettings);
});

final tripCurrencySettingsProvider =
    FutureProvider.family<TripCurrencySettings, String>((ref, primaryCurrency) async {
  final currencyService = ref.watch(currencyServiceProvider);
  return currencyService.createTripCurrencySettings(primaryCurrency);
});
