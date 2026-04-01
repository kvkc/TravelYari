import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../trip_planning/models/trip.dart';
import '../models/expense.dart';

class SplitSelector extends StatelessWidget {
  final List<TripParticipant> participants;
  final SplitType splitType;
  final List<ExpenseShare> shares;
  final double totalAmount;
  final String currencySymbol;
  final ValueChanged<SplitType> onSplitTypeChanged;
  final ValueChanged<List<ExpenseShare>> onSharesChanged;

  const SplitSelector({
    super.key,
    required this.participants,
    required this.splitType,
    required this.shares,
    required this.totalAmount,
    required this.currencySymbol,
    required this.onSplitTypeChanged,
    required this.onSharesChanged,
  });

  double get _assignedTotal => shares
      .where((s) => s.isIncluded)
      .fold(0.0, (sum, s) => sum + s.amount);

  bool get _isBalanced => (totalAmount - _assignedTotal).abs() < 0.01;

  ExpenseShare? _getShare(String participantId) {
    try {
      return shares.firstWhere((s) => s.participantId == participantId);
    } catch (e) {
      return null;
    }
  }

  void _toggleParticipant(String participantId, bool included) {
    final newShares = shares.map((s) {
      if (s.participantId == participantId) {
        return s.copyWith(isIncluded: included);
      }
      return s;
    }).toList();

    // Recalculate if equal split
    if (splitType == SplitType.equal) {
      final includedCount = newShares.where((s) => s.isIncluded).length;
      if (includedCount > 0) {
        final shareAmount = totalAmount / includedCount;
        for (int i = 0; i < newShares.length; i++) {
          newShares[i] = newShares[i].copyWith(
            amount: newShares[i].isIncluded
                ? double.parse(shareAmount.toStringAsFixed(2))
                : 0,
          );
        }
      }
    }

    onSharesChanged(newShares);
  }

  void _updateShareAmount(String participantId, double amount) {
    final newShares = shares.map((s) {
      if (s.participantId == participantId) {
        return s.copyWith(amount: amount);
      }
      return s;
    }).toList();
    onSharesChanged(newShares);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Split',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),

        // Split type selector
        SegmentedButton<SplitType>(
          segments: const [
            ButtonSegment(
              value: SplitType.equal,
              label: Text('Equal'),
              icon: Icon(Icons.balance, size: 18),
            ),
            ButtonSegment(
              value: SplitType.unequal,
              label: Text('Unequal'),
              icon: Icon(Icons.tune, size: 18),
            ),
          ],
          selected: {splitType},
          onSelectionChanged: (selected) {
            onSplitTypeChanged(selected.first);
          },
        ),

        const SizedBox(height: 16),

        // Participant list
        ...participants.map((participant) {
          final share = _getShare(participant.id);
          final isIncluded = share?.isIncluded ?? false;
          final amount = share?.amount ?? 0;

          return _ParticipantShareRow(
            participant: participant,
            isIncluded: isIncluded,
            amount: amount,
            currencySymbol: currencySymbol,
            showAmountInput: splitType == SplitType.unequal,
            onIncludedChanged: (included) {
              _toggleParticipant(participant.id, included);
            },
            onAmountChanged: (newAmount) {
              _updateShareAmount(participant.id, newAmount);
            },
          );
        }),

        // Validation row for unequal split
        if (splitType == SplitType.unequal && totalAmount > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isBalanced ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _isBalanced ? Icons.check_circle : Icons.warning,
                  size: 18,
                  color: _isBalanced ? Colors.green[700] : Colors.orange[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isBalanced
                        ? 'Split is balanced'
                        : 'Assigned: $currencySymbol${_assignedTotal.toStringAsFixed(2)} of $currencySymbol${totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: _isBalanced ? Colors.green[700] : Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ParticipantShareRow extends StatefulWidget {
  final TripParticipant participant;
  final bool isIncluded;
  final double amount;
  final String currencySymbol;
  final bool showAmountInput;
  final ValueChanged<bool> onIncludedChanged;
  final ValueChanged<double> onAmountChanged;

  const _ParticipantShareRow({
    required this.participant,
    required this.isIncluded,
    required this.amount,
    required this.currencySymbol,
    required this.showAmountInput,
    required this.onIncludedChanged,
    required this.onAmountChanged,
  });

  @override
  State<_ParticipantShareRow> createState() => _ParticipantShareRowState();
}

class _ParticipantShareRowState extends State<_ParticipantShareRow> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.amount > 0 ? widget.amount.toStringAsFixed(2) : '',
    );
  }

  @override
  void didUpdateWidget(_ParticipantShareRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amount != widget.amount) {
      final newText = widget.amount > 0 ? widget.amount.toStringAsFixed(2) : '';
      if (_controller.text != newText) {
        _controller.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.participant.name ?? 'Unknown';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Checkbox
          Checkbox(
            value: widget.isIncluded,
            onChanged: (value) => widget.onIncludedChanged(value ?? false),
          ),

          // Avatar and name
          CircleAvatar(
            radius: 16,
            backgroundColor: widget.isIncluded
                ? Colors.blue[100]
                : Colors.grey[200],
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: widget.isIncluded
                    ? Colors.blue[700]
                    : Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: widget.isIncluded ? null : Colors.grey[500],
                decoration: widget.isIncluded ? null : TextDecoration.lineThrough,
              ),
            ),
          ),

          // Amount
          if (widget.showAmountInput && widget.isIncluded)
            SizedBox(
              width: 100,
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  prefixText: widget.currencySymbol,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                onChanged: (value) {
                  final amount = double.tryParse(value) ?? 0;
                  widget.onAmountChanged(amount);
                },
              ),
            )
          else if (widget.isIncluded)
            Text(
              '${widget.currencySymbol}${widget.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
        ],
      ),
    );
  }
}
