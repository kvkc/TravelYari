import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/sync/trip_sync_service.dart';
import '../../trip_planning/models/trip.dart';
import '../models/currency.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';
import '../widgets/expense_card.dart';
import '../widgets/expense_summary_card.dart';
import 'add_expense_screen.dart';
import 'settlement_screen.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  final Trip trip;

  const ExpenseListScreen({
    super.key,
    required this.trip,
  });

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  String? _selectedCategory;
  late TripCurrencySettings _currencySettings;
  bool _isLoading = true;
  StreamSubscription<(String, List<Expense>)>? _expenseSubscription;

  @override
  void initState() {
    super.initState();
    _loadCurrencySettings();
    _listenForRemoteUpdates();
  }

  void _listenForRemoteUpdates() {
    final syncService = ref.read(tripSyncServiceProvider.notifier);
    _expenseSubscription = syncService.expenseUpdates.listen((update) {
      final (tripId, _) = update;
      if (tripId == widget.trip.id && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _expenseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrencySettings() async {
    final currencyService = ref.read(currencyServiceProvider);
    _currencySettings = await currencyService.createTripCurrencySettings('INR');
    setState(() {
      _isLoading = false;
    });
  }

  List<Expense> _getFilteredExpenses() {
    final expenses = ref.watch(tripExpensesProvider(widget.trip.id));
    if (_selectedCategory == null) return expenses;
    return expenses.where((e) => e.category == _selectedCategory).toList();
  }

  Set<String> _getCategories() {
    final expenses = ref.watch(tripExpensesProvider(widget.trip.id));
    return expenses.map((e) => e.category).toSet();
  }

  TripParticipant? _getParticipant(String participantId) {
    try {
      return widget.trip.participants.firstWhere((p) => p.id == participantId);
    } catch (e) {
      return null;
    }
  }

  Future<void> _addExpense() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(
          trip: widget.trip,
          currencySettings: _currencySettings,
        ),
      ),
    );

    if (result == true) {
      setState(() {}); // Refresh list
    }
  }

  Future<void> _editExpense(Expense expense) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(
          trip: widget.trip,
          currencySettings: _currencySettings,
          existingExpense: expense,
        ),
      ),
    );

    if (result == true) {
      setState(() {}); // Refresh list
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Delete "${expense.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(expenseServiceProvider).deleteExpense(expense.id);
      setState(() {});
    }
  }

  void _showSettlement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettlementScreen(
          trip: widget.trip,
          currencySettings: _currencySettings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Expenses')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final expenses = _getFilteredExpenses();
    final categories = _getCategories();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: _showSettlement,
            tooltip: 'Settlement',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary card
          ExpenseSummaryCard(
            tripId: widget.trip.id,
            currencySettings: _currencySettings,
            participantCount: widget.trip.participants.length,
            onTap: _showSettlement,
          ),

          // Category filter
          if (categories.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _selectedCategory == null,
                    onSelected: (_) => setState(() => _selectedCategory = null),
                  ),
                  const SizedBox(width: 8),
                  ...categories.map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(category),
                        selected: _selectedCategory == category,
                        onSelected: (_) => setState(() {
                          _selectedCategory =
                              _selectedCategory == category ? null : category;
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Expense list
          Expanded(
            child: expenses.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final expense = expenses[index];
                      final paidBy = _getParticipant(expense.paidByParticipantId);

                      return ExpenseCard(
                        expense: expense,
                        paidByName: paidBy?.name ?? 'Unknown',
                        currencySymbol: TripCurrency.getSymbol(expense.currencyCode),
                        onTap: () => _editExpense(expense),
                        onDelete: () => _deleteExpense(expense),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpense,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No expenses yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first expense',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
