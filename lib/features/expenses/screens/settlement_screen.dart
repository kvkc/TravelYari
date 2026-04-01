import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../trip_planning/models/trip.dart';
import '../models/currency.dart';
import '../models/settlement.dart';
import '../services/expense_service.dart';
import '../widgets/settlement_card.dart';

class SettlementScreen extends ConsumerStatefulWidget {
  final Trip trip;
  final TripCurrencySettings currencySettings;

  const SettlementScreen({
    super.key,
    required this.trip,
    required this.currencySettings,
  });

  @override
  ConsumerState<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends ConsumerState<SettlementScreen> {
  SettlementSummary? _settlement;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettlement();
  }

  Future<void> _loadSettlement() async {
    final service = ref.read(expenseServiceProvider);
    final settlement = await service.calculateSettlement(
      tripId: widget.trip.id,
      participants: widget.trip.participants,
      currencySettings: widget.currencySettings,
    );
    setState(() {
      _settlement = settlement;
      _isLoading = false;
    });
  }

  TripParticipant? _getParticipant(String id) {
    try {
      return widget.trip.participants.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  String _formatAmount(double amount) {
    final symbol = TripCurrency.getSymbol(widget.currencySettings.primaryCurrencyCode);
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settlement')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final settlement = _settlement!;
    final participants = widget.trip.participants;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settlement'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Total expenses card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 40,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Expenses',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatAmount(settlement.totalExpenses),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (participants.length > 1) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${_formatAmount(settlement.averagePerPerson)} per person',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Per-person balances
          Text(
            'Balance Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),

          ...settlement.participantDetails.map((balance) {
            final participant = _getParticipant(balance.participantId);
            final name = participant?.name ?? 'Unknown';
            final isPositive = balance.netBalance > 0;
            final isSettled = balance.netBalance.abs() < 0.01;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSettled
                      ? Colors.grey[200]
                      : isPositive
                          ? Colors.green[50]
                          : Colors.red[50],
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: isSettled
                          ? Colors.grey[600]
                          : isPositive
                              ? Colors.green[700]
                              : Colors.red[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(name),
                subtitle: Text(
                  'Paid ${_formatAmount(balance.totalPaid)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isSettled
                          ? 'Settled'
                          : isPositive
                              ? 'Gets back'
                              : 'Owes',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSettled
                            ? Colors.grey[600]
                            : isPositive
                                ? Colors.green[700]
                                : Colors.red[700],
                      ),
                    ),
                    if (!isSettled)
                      Text(
                        _formatAmount(balance.netBalance.abs()),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isPositive
                              ? Colors.green[700]
                              : Colors.red[700],
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 24),

          // Settlements needed
          if (settlement.simplifiedDebts.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.swap_horiz, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Settlements Needed',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ...settlement.simplifiedDebts.map((debt) {
              final from = _getParticipant(debt.fromParticipantId);
              final to = _getParticipant(debt.toParticipantId);

              return SettlementCard(
                fromName: from?.name ?? 'Unknown',
                toName: to?.name ?? 'Unknown',
                amount: debt.amount,
                currencySymbol: TripCurrency.getSymbol(debt.currencyCode),
              );
            }),
          ] else ...[
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 48,
                      color: Colors.green[700],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'All Settled!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No pending settlements',
                      style: TextStyle(color: Colors.green[600]),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Category breakdown
          if (settlement.expensesByCategory.isNotEmpty) ...[
            Text(
              'By Category',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Column(
                children: settlement.expensesByCategory.entries.map((entry) {
                  final percentage =
                      (entry.value / settlement.totalExpenses * 100).round();
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      _getCategoryIcon(entry.key),
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    title: Text(entry.key),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatAmount(entry.value),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$percentage%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'accommodation':
        return Icons.hotel;
      case 'fuel':
        return Icons.local_gas_station;
      case 'tickets':
        return Icons.confirmation_number;
      case 'shopping':
        return Icons.shopping_bag;
      case 'activities':
        return Icons.attractions;
      default:
        return Icons.receipt;
    }
  }
}
