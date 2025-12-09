class PaymentHistory {
  final String planName;
  final double price;
  final String priceCurrency;
  final double paidAmount;
  final String paidCurrency;
  final double? change;
  final String transactionTime;

  PaymentHistory({
    required this.planName,
    required this.price,
    required this.priceCurrency,
    required this.paidAmount,
    required this.paidCurrency,
    required this.change,
    required this.transactionTime,
  });

  Map<String, dynamic> toJson() => {
    'planName': planName,
    'price': price,
    'priceCurrency': priceCurrency,
    'paidAmount': paidAmount,
    'paidCurrency': paidCurrency,
    'change': change,
    'transactionTime': transactionTime,
  };

  factory PaymentHistory.fromJson(Map<String, dynamic> json) {
    final fallbackCurrency = json['currency'] ?? 'IDR';
    return PaymentHistory(
      planName: json['planName'],
      price: (json['price'] as num).toDouble(),
      priceCurrency: json['priceCurrency'] ?? fallbackCurrency,
      paidAmount: (json['paidAmount'] as num).toDouble(),
      paidCurrency: json['paidCurrency'] ?? fallbackCurrency,
      change: json['change'] != null
          ? (json['change'] as num).toDouble()
          : null,
      transactionTime: json['transactionTime'],
    );
  }
}
