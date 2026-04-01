import 'package:flutter/material.dart';

import '../models/currency.dart';

class CurrencyPicker extends StatelessWidget {
  final String selectedCurrency;
  final ValueChanged<String> onSelected;

  const CurrencyPicker({
    super.key,
    required this.selectedCurrency,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final currencies = TripCurrency.availableCurrencies;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Select Currency',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: currencies.length,
              itemBuilder: (context, index) {
                final code = currencies[index];
                final symbol = TripCurrency.getSymbol(code);
                final name = TripCurrency.getName(code);
                final isSelected = code == selectedCurrency;

                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blue[100]
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      symbol,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.blue[700]
                            : Colors.grey[700],
                      ),
                    ),
                  ),
                  title: Text(code),
                  subtitle: Text(name),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () => onSelected(code),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
