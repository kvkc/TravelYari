import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../trip_planning/models/trip.dart';
import '../models/currency.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';
import '../widgets/split_selector.dart';
import '../widgets/currency_picker.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final Trip trip;
  final TripCurrencySettings currencySettings;
  final Expense? existingExpense;

  const AddExpenseScreen({
    super.key,
    required this.trip,
    required this.currencySettings,
    this.existingExpense,
  });

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _notesController = TextEditingController();

  late String _selectedCurrency;
  late String _paidByParticipantId;
  late SplitType _splitType;
  late List<ExpenseShare> _shares;
  late DateTime _expenseDate;
  bool _isSaving = false;

  bool get _isEditing => widget.existingExpense != null;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    final expense = widget.existingExpense;
    final participants = widget.trip.participants;

    if (expense != null) {
      _descriptionController.text = expense.description;
      _amountController.text = expense.amount.toStringAsFixed(2);
      _categoryController.text = expense.category;
      _notesController.text = expense.notes ?? '';
      _selectedCurrency = expense.currencyCode;
      _paidByParticipantId = expense.paidByParticipantId;
      _splitType = expense.splitType;
      _shares = List.from(expense.shares);
      _expenseDate = expense.expenseDate;
    } else {
      _selectedCurrency = widget.currencySettings.primaryCurrencyCode;
      _paidByParticipantId =
          participants.isNotEmpty ? participants.first.id : '';
      _splitType = SplitType.equal;
      _shares = participants
          .map((p) => ExpenseShare(participantId: p.id, amount: 0, isIncluded: true))
          .toList();
      _expenseDate = DateTime.now();
    }
  }

  void _updateSplitAmounts() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final includedCount = _shares.where((s) => s.isIncluded).length;

    if (_splitType == SplitType.equal && includedCount > 0) {
      final shareAmount = amount / includedCount;
      _shares = _shares.map((s) {
        return s.copyWith(
          amount: s.isIncluded ? double.parse(shareAmount.toStringAsFixed(2)) : 0,
        );
      }).toList();
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _expenseDate = picked);
    }
  }

  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => CurrencyPicker(
        selectedCurrency: _selectedCurrency,
        onSelected: (currency) {
          setState(() => _selectedCurrency = currency);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final amount = double.parse(_amountController.text);

      // Update share amounts for equal split
      if (_splitType == SplitType.equal) {
        _updateSplitAmounts();
      }

      final expense = Expense(
        id: widget.existingExpense?.id,
        tripId: widget.trip.id,
        description: _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
        amount: amount,
        currencyCode: _selectedCurrency,
        paidByParticipantId: _paidByParticipantId,
        splitType: _splitType,
        shares: _shares.where((s) => s.isIncluded).toList(),
        expenseDate: _expenseDate,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: widget.existingExpense?.createdAt,
      );

      final service = ref.read(expenseServiceProvider);
      if (_isEditing) {
        await service.updateExpense(expense);
      } else {
        await service.addExpense(expense);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final participants = widget.trip.participants;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Expense' : 'Add Expense'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveExpense,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g., Lunch at restaurant',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  v?.trim().isEmpty == true ? 'Required' : null,
            ),

            const SizedBox(height: 16),

            // Amount with currency
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Currency selector
                InkWell(
                  onTap: _showCurrencyPicker,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          TripCurrency.getSymbol(_selectedCurrency),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 20),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Amount field
                Expanded(
                  child: TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      hintText: '0.00',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    validator: (v) {
                      if (v?.isEmpty == true) return 'Required';
                      final amount = double.tryParse(v!);
                      if (amount == null || amount <= 0) return 'Invalid amount';
                      return null;
                    },
                    onChanged: (_) {
                      if (_splitType == SplitType.equal) {
                        setState(() => _updateSplitAmounts());
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Category
            TextFormField(
              controller: _categoryController,
              decoration: InputDecoration(
                labelText: 'Category',
                hintText: 'e.g., Food, Transport, Accommodation',
                prefixIcon: const Icon(Icons.category_outlined),
                suffixIcon: PopupMenuButton<String>(
                  icon: const Icon(Icons.arrow_drop_down),
                  onSelected: (value) {
                    _categoryController.text = value;
                  },
                  itemBuilder: (context) => [
                    'Food',
                    'Transport',
                    'Accommodation',
                    'Fuel',
                    'Tickets',
                    'Shopping',
                    'Activities',
                    'Other',
                  ].map((c) => PopupMenuItem(value: c, child: Text(c))).toList(),
                ),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  v?.trim().isEmpty == true ? 'Required' : null,
            ),

            const SizedBox(height: 16),

            // Date
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(DateFormat('EEE, MMM d, yyyy').format(_expenseDate)),
              ),
            ),

            const SizedBox(height: 24),

            // Paid by
            if (participants.isNotEmpty) ...[
              Text(
                'Paid by',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: participants.map((p) {
                  final isSelected = _paidByParticipantId == p.id;
                  return ChoiceChip(
                    label: Text(p.name ?? 'Unknown'),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _paidByParticipantId = p.id);
                    },
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 24),

            // Split selector
            if (participants.length > 1) ...[
              SplitSelector(
                participants: participants,
                splitType: _splitType,
                shares: _shares,
                totalAmount: double.tryParse(_amountController.text) ?? 0,
                currencySymbol: TripCurrency.getSymbol(_selectedCurrency),
                onSplitTypeChanged: (type) {
                  setState(() {
                    _splitType = type;
                    _updateSplitAmounts();
                  });
                },
                onSharesChanged: (shares) {
                  setState(() => _shares = shares);
                },
              ),
            ],

            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Any additional details...',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
