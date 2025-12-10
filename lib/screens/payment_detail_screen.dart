import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/settings_service.dart';
import '../utils/currency_utils.dart';
import '../models/payment_history.dart';
import '../services/currency_service.dart';
import '../services/history_service.dart';
import '../services/user_status_service.dart';
import '../services/notification_service.dart';
import '../screens/premium_screen.dart';

class PaymentDetailScreen extends StatefulWidget {
  final String planName;
  final double price;

  const PaymentDetailScreen({
    super.key,
    required this.planName,
    required this.price,
  });

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  final TextEditingController _payController = TextEditingController();
  final List<String> _currencies = ['IDR', 'USD', 'EUR', 'JPY', 'MYR', 'SGD'];

  String _from = 'IDR';
  String _to = 'IDR';
  bool _isLoading = false;
  bool _showSuccess = false;

  double? _paidAmount;
  double? _convertedPaid;
  double? _convertedChange;
  double? _change;
  DateTime? _transactionDateTime;
  final List<String> _timeZones = ['WIB', 'WITA', 'WIT', 'GMT'];

  Future<void> _processPayment() async {
    final paid = double.tryParse(_payController.text);
    if (paid == null || paid <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Masukkan jumlah uang yang valid 💰")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _paidAmount = paid;
    });

    await Future.delayed(const Duration(seconds: 1)); // simulasi loading

    try {
      // Konversi harga dari IDR ke mata uang asal (_from)
      final convertedPrice = await CurrencyService.convertCurrency(
        widget.price,
        'IDR',
        _from,
      );

      final change = paid - convertedPrice;

      // Konversi ke mata uang target (_to)
      final paidToTarget = await CurrencyService.convertCurrency(
        paid,
        _from,
        _to,
      );
      final changeToTarget = await CurrencyService.convertCurrency(
        change.abs(),
        _from,
        _to,
      );

      setState(() {
        _convertedPaid = paidToTarget;
        _convertedChange = changeToTarget;
        _change = change;
        _transactionDateTime = DateTime.now();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal memproses pembayaran: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmPayment() async {
    if (_change == null) return;

    if (_change! < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Uang yang dibayar belum cukup ❌")),
      );
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2)); // simulasi loading

    final userBox = await Hive.openBox('userBox');
    final currentEmail = userBox.get('current_email', defaultValue: '-');

    final nowStr = _formatDateTimeForZone(DateTime.now());

    final history = PaymentHistory(
      planName: widget.planName,
      price: widget.price,
      // The product prices in the app are expressed in IDR by design
      priceCurrency: 'IDR',
      paidAmount: _paidAmount ?? 0,
      paidCurrency: _from,
      change: _change,
      transactionTime: nowStr,
    );

    // Simpan berdasarkan akun (email)
    await HistoryService.addHistory(currentEmail, history);

    // Tandai user jadi Premium
    debugPrint('▶️ PaymentDetail: setting premium -> true');
    await UserStatusService.setPremium(true);
    debugPrint('✅ PaymentDetail: setPremium returned');

    // Kirim notifikasi lokal
    await NotificationService.show(
      "🎉 Selamat!",
      "Akun kamu sekarang Premium. Nikmati semua fitur tanpa batas 🚀",
    );

    setState(() {
      _isLoading = false;
      _showSuccess = true;
    });

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PremiumScreen(
            username: userBox.get('username', defaultValue: 'User'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: const CustomAppBar(
        title: 'Pembayaran',
        centerTitle: true,
        backgroundColor: Color(0xFF012D5A),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _showSuccess ? _buildSuccessScreen() : _buildPaymentForm(),
      ),
    );
  }

  Widget _buildPaymentForm() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.planName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              CurrencyUtils.format(widget.price, 'IDR'),
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white24),
            const SizedBox(height: 10),
            const Text(
              "Masukkan Jumlah Pembayaran",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _payController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF012D5A),
                hintText: "Contoh: 15000",
                hintStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildDropdown(
                    "Dari",
                    _from,
                    (val) => setState(() => _from = val!),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(Icons.arrow_forward, color: Colors.white),
                ),
                Expanded(
                  child: _buildDropdown(
                    "Ke",
                    _to,
                    (val) => setState(() => _to = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Time zone selector (syncs with SettingsService)
            Row(
              children: [
                const Text(
                  'Zona Waktu: ',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: SettingsService.timeZone,
                    builder: (context, tz, _) {
                      return DropdownButton<String>(
                        isExpanded: true,
                        dropdownColor: const Color(0xFF001F3F),
                        value: tz,
                        style: const TextStyle(color: Colors.white),
                        items: _timeZones
                            .map(
                              (z) => DropdownMenuItem(
                                value: z,
                                child: Text(
                                  z,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            v != null ? SettingsService.setTimeZone(v) : null,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                minimumSize: const Size(double.infinity, 45),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Proses Pembayaran"),
            ),
            const SizedBox(height: 30),
            if (_paidAmount != null) _buildInvoiceCard(),
            if (_paidAmount != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _confirmPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(double.infinity, 45),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Konfirmasi Pembayaran"),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.check_circle, color: Colors.greenAccent, size: 100),
          SizedBox(height: 20),
          Text(
            "Pembayaran Berhasil 🎉",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            "Akun kamu sekarang Premium!",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    Function(String?) onChanged,
  ) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF001F3F),
          style: const TextStyle(color: Colors.white),
          items: _currencies
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildInvoiceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF012D5A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "🧾 Ringkasan Transaksi",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _buildInvoiceRow("Paket", widget.planName),
          _buildInvoiceRow(
            "Harga",
            CurrencyUtils.format(widget.price, 'IDR', approximate: true),
          ),
          _buildInvoiceRow(
            "Dibayar",
            CurrencyUtils.format(_paidAmount ?? 0, _from),
          ),
          if (_convertedPaid != null)
            _buildInvoiceRow(
              "≈ Dalam $_to",
              CurrencyUtils.format(_convertedPaid ?? 0, _to),
            ),
          if (_change != null)
            _buildInvoiceRow(
              _change! >= 0 ? "Kembalian" : "Kurang",
              CurrencyUtils.format(_change!.abs(), _from),
              valueColor: _change! >= 0 ? Colors.greenAccent : Colors.redAccent,
            ),
          if (_convertedChange != null)
            _buildInvoiceRow(
              "≈ Dalam $_to",
              CurrencyUtils.format(_convertedChange ?? 0, _to),
              valueColor: Colors.white70,
            ),
          ValueListenableBuilder<String>(
            valueListenable: SettingsService.timeZone,
            builder: (context, tz, _) {
              final timeLabel = _transactionDateTime != null
                  ? _formatDateTimeForZone(_transactionDateTime!)
                  : null;
              return timeLabel != null
                  ? _buildInvoiceRow(
                      "Waktu",
                      timeLabel,
                      valueColor: Colors.white,
                    )
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTimeForZone(DateTime dt) {
    final currentZone = SettingsService.timeZone.value;
    Duration offset;
    switch (currentZone) {
      case 'WITA':
        offset = const Duration(hours: 8);
        break;
      case 'WIT':
        offset = const Duration(hours: 9);
        break;
      case 'GMT':
        offset = const Duration(hours: 0);
        break;
      default:
        offset = const Duration(hours: 7);
    }
    final zoneTime = dt.toUtc().add(offset);
    // Build human-friendly label: e.g. "WIB (GMT+7)" or "WITA (GMT+8)"
    final label = currentZone == 'GMT' ? 'GMT' : currentZone;
    final gmtOffset = offset.inHours >= 0
        ? '+${offset.inHours}'
        : '${offset.inHours}';
    final gmtLabel = 'GMT$gmtOffset';
    final formatted = DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(zoneTime);
    return '$formatted ($label, $gmtLabel)';
  }
}
