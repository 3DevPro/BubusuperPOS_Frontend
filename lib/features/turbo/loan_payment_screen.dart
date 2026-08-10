import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../shared/formatters.dart';
import '../pos/promptpay.dart';
import 'turbo_providers.dart';
import 'turbo_repository.dart';

// Not a real PromptPay biller — same placeholder as Backend's
// TURBO_BILLER_PROMPTPAY_ID (app/core/turbo_config.py). This prototype has
// no settlement feed behind this QR; "ยืนยันว่าชำระแล้ว" below is the only
// signal a payment happened, same as the backend comment on
// loan_service.pay_installment explains.
const _demoBillerPromptPayId = '0000000000000';

class LoanPaymentScreen extends ConsumerStatefulWidget {
  const LoanPaymentScreen({super.key, required this.installment});
  final LoanInstallmentDto installment;

  @override
  ConsumerState<LoanPaymentScreen> createState() => _LoanPaymentScreenState();
}

class _LoanPaymentScreenState extends ConsumerState<LoanPaymentScreen> {
  bool _confirming = false;
  String? _error;

  Future<void> _confirmPaid() async {
    setState(() {
      _confirming = true;
      _error = null;
    });
    try {
      await ref.read(turboRepositoryProvider).payInstallment(
        installmentId: widget.installment.id,
        amount: widget.installment.amountDue,
        reference: 'app-qr-demo',
      );
      ref.invalidate(loanAccountSummaryProvider);
      ref.invalidate(loanInstallmentsProvider(widget.installment.accountId));
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกการชำระเรียบร้อย')),
        );
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      if (mounted) {
        setState(() {
          _error = (data is Map && data['detail'] != null) ? data['detail'].toString() : 'บันทึกการชำระไม่สำเร็จ';
        });
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final installment = widget.installment;
    final payload = buildPromptPayPayload(promptPayId: _demoBillerPromptPayId, amount: installment.amountDue);

    return Scaffold(
      appBar: AppBar(title: const Text('ชำระค่างวด')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('งวดที่ ${installment.sequence}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(formatBaht(installment.amountDue), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  QrImageView(data: payload, size: 220, backgroundColor: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    'สแกนจ่าย ${formatBaht(installment.amountDue)} ผ่านแอปธนาคาร',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFA726).withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFA726).withAlpha(80)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFFFA726), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'QR เดโม — ยังไม่กระทบยอดจริง กดยืนยันด้านล่างเพื่อบันทึกว่าชำระแล้ว',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _confirming ? null : _confirmPaid,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _confirming
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('ยืนยันว่าชำระแล้ว'),
            ),
          ),
        ],
      ),
    );
  }
}
