import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/currency.dart';
import '../services/expense_service.dart';

class ExpenseSummaryCard extends ConsumerWidget {
  final String tripId;
  final TripCurrencySettings currencySettings;
  final int participantCount;
  final VoidCallback? onTap;

  const ExpenseSummaryCard({
    super.key,
    required this.tripId,
    required this.currencySettings,
    required this.participantCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(expenseServiceProvider);
    final total = service.getTripTotal(tripId, currencySettings);
    final symbol = TripCurrency.getSymbol(currencySettings.primaryCurrencyCode);
    final perPerson = participantCount > 0 ? total / participantCount : total;

    return Card(
      margin: const EdgeInsets.all(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Expenses',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$symbol${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (participantCount > 1) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$symbol${perPerson.toStringAsFixed(2)} per person',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
