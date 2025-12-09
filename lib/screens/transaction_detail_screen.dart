import 'package:flutter/material.dart';
import '../models/payment_history.dart';
import '../utils/currency_utils.dart';
import '../widgets/custom_app_bar.dart';

class TransactionDetailScreen extends StatelessWidget {
  final PaymentHistory history;
  const TransactionDetailScreen({Key? key, required this.history})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: const CustomAppBar(
        title: 'Detail Transaksi',
        backgroundColor: Color(0xFF012D5A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF00345B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                history.planName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _row(
                'Harga',
                CurrencyUtils.format(
                  history.price,
                  history.priceCurrency,
                  approximate: true,
                ),
              ),
              _row(
                'Dibayar',
                CurrencyUtils.format(history.paidAmount, history.paidCurrency),
              ),
              _row(
                history.change != null
                    ? (history.change! >= 0 ? 'Kembalian' : 'Kurang')
                    : 'Kembalian',
                history.change != null
                    ? CurrencyUtils.format(
                        history.change!,
                        history.paidCurrency,
                      )
                    : '-',
              ),
              // If paidCurrency differs from priceCurrency, show converted approximations
              if (history.paidCurrency.toUpperCase() !=
                  history.priceCurrency.toUpperCase())
                _row(
                  '≈ Dalam ${history.priceCurrency}',
                  CurrencyUtils.format(history.price, history.priceCurrency),
                ),
              _row('Waktu', history.transactionTime),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
