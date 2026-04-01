import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class SettlementCard extends StatelessWidget {
  final String fromName;
  final String toName;
  final double amount;
  final String currencySymbol;
  final VoidCallback? onMarkPaid;

  const SettlementCard({
    super.key,
    required this.fromName,
    required this.toName,
    required this.amount,
    required this.currencySymbol,
    this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // From avatar
            _buildAvatar(fromName, Colors.red[100]!, Colors.red[700]!),

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
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '$currencySymbol${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        size: 20,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'owes',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // To avatar
            _buildAvatar(toName, Colors.green[100]!, Colors.green[700]!),
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
