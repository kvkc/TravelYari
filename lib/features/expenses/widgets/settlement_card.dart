import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class SettlementCard extends StatelessWidget {
  final String fromName;
  final String toName;
  final double amount;
  final String currencySymbol;
  final VoidCallback? onSettle;
  final bool isSettled;

  const SettlementCard({
    super.key,
    required this.fromName,
    required this.toName,
    required this.amount,
    required this.currencySymbol,
    this.onSettle,
    this.isSettled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSettled ? Colors.green[50] : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // From avatar
                _buildAvatar(fromName, isSettled ? Colors.grey[200]! : Colors.red[100]!, isSettled ? Colors.grey[600]! : Colors.red[700]!),

                const SizedBox(width: 12),

                // Arrow with amount
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 2,
                            width: 30,
                            color: Colors.grey[300],
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSettled
                                    ? Colors.green[100]
                                    : AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '$currencySymbol${amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSettled ? Colors.green[700] : AppTheme.primaryColor,
                                  decoration: isSettled ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                          ),
                          Icon(
                            isSettled ? Icons.check : Icons.arrow_forward,
                            size: 20,
                            color: isSettled ? Colors.green[700] : Colors.grey[400],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isSettled ? 'settled' : 'owes',
                        style: TextStyle(
                          fontSize: 11,
                          color: isSettled ? Colors.green[600] : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // To avatar
                _buildAvatar(toName, isSettled ? Colors.grey[200]! : Colors.green[100]!, isSettled ? Colors.grey[600]! : Colors.green[700]!),
              ],
            ),
            if (onSettle != null && !isSettled) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onSettle,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Mark as Settled'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green[700],
                    side: BorderSide(color: Colors.green[300]!),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, Color bgColor, Color textColor) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: bgColor,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 60,
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
