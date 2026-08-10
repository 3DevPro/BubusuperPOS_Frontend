import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/formatters.dart';
import 'turbo_providers.dart';
import 'turbo_repository.dart';

class LoanApplyScreen extends ConsumerStatefulWidget {
  const LoanApplyScreen({super.key, this.productCode});
  final String? productCode;

  @override
  ConsumerState<LoanApplyScreen> createState() => _LoanApplyScreenState();
}

class _LoanApplyScreenState extends ConsumerState<LoanApplyScreen> {
  final _collateralController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedCode;
  int _termMonths = 12;
  LoanQuoteDto? _quote;
  bool _loadingQuote = false;
  bool _applying = false;
  String? _error;
  bool _initialized = false;

  @override
  void dispose() {
    _collateralController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _initDefaults(List<LoanProductDto> products) {
    if (_initialized || products.isEmpty) return;
    _initialized = true;
    final match = products.where((p) => p.code == widget.productCode).toList();
    final product = match.isNotEmpty ? match.first : products.first;
    _selectedCode = product.code;
    _termMonths = product.minTermMonths <= 12 && 12 <= product.maxTermMonths ? 12 : product.minTermMonths;
    final defaultAmount = product.maxPrincipal < Decimal.fromInt(20000)
        ? product.maxPrincipal
        : Decimal.fromInt(20000);
    _amountController.text = defaultAmount.toString();
    _collateralController.text = (defaultAmount * Decimal.fromInt(2)).toString();
    // Fire the first quote after the frame so setState from initDefaults
    // (called during build) doesn't recurse back into build synchronously.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshQuote());
  }

  LoanProductDto _productFor(List<LoanProductDto> products, String code) =>
      products.firstWhere((p) => p.code == code, orElse: () => products.first);

  Future<void> _refreshQuote() async {
    final products = ref.read(loanProductsProvider).valueOrNull;
    if (products == null || _selectedCode == null) return;
    final requested = Decimal.tryParse(_amountController.text.trim());
    final collateral = Decimal.tryParse(_collateralController.text.trim());
    if (requested == null || collateral == null || requested <= Decimal.zero || collateral <= Decimal.zero) {
      setState(() => _error = 'กรอกจำนวนเงินให้ถูกต้อง');
      return;
    }

    setState(() {
      _loadingQuote = true;
      _error = null;
      _quote = null;
    });
    try {
      final quote = await ref.read(turboRepositoryProvider).loanQuote(
        productCode: _selectedCode!,
        requestedAmount: requested,
        collateralValue: collateral,
        termMonths: _termMonths,
      );
      if (mounted) setState(() => _quote = quote);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (mounted) {
        setState(() {
          _error = (data is Map && data['detail'] != null) ? data['detail'].toString() : 'คำนวณราคาไม่สำเร็จ';
        });
      }
    } finally {
      if (mounted) setState(() => _loadingQuote = false);
    }
  }

  Future<void> _apply() async {
    final requested = Decimal.tryParse(_amountController.text.trim());
    final collateral = Decimal.tryParse(_collateralController.text.trim());
    if (requested == null || collateral == null || _selectedCode == null) return;

    setState(() {
      _applying = true;
      _error = null;
    });
    try {
      final application = await ref.read(turboRepositoryProvider).applyForLoan(
        productCode: _selectedCode!,
        requestedAmount: requested,
        collateralValue: collateral,
        termMonths: _termMonths,
      );
      if (mounted) await _showSubmittedSheet(application);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (mounted) {
        setState(() {
          _error = (data is Map && data['detail'] != null) ? data['detail'].toString() : 'ยื่นขอสินเชื่อไม่สำเร็จ';
        });
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _showSubmittedSheet(LoanApplicationDto application) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => _SubmittedSheet(application: application),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(loanProductsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ยื่นขอสินเชื่อ')),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดข้อมูลไม่สำเร็จ: $err')),
        data: (products) {
          if (products.isEmpty) return const Center(child: Text('ยังไม่มีสินเชื่อในระบบ'));
          _initDefaults(products);
          final product = _productFor(products, _selectedCode ?? products.first.code);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in products)
                    ChoiceChip(
                      label: Text(p.name),
                      selected: _selectedCode == p.code,
                      onSelected: (_) {
                        setState(() {
                          _selectedCode = p.code;
                          _termMonths = p.minTermMonths <= _termMonths && _termMonths <= p.maxTermMonths
                              ? _termMonths
                              : p.minTermMonths;
                        });
                        _refreshQuote();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(product.description, style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
                      const SizedBox(height: 8),
                      Text(
                        'ดอกเบี้ย ${(product.monthlyInterestRate.toDouble() * 100).toStringAsFixed(2)}%/เดือน '
                        '(≈${(product.monthlyInterestRate.toDouble() * 1200).toStringAsFixed(1)}%/ปี) '
                        '· วงเงินสูงสุด ${formatBaht(product.maxPrincipal)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _collateralController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'ราคาประเมินหลักประกัน (บาท)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'จำนวนที่ต้องการยื่นขอ (บาท)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Text('จำนวนงวด: $_termMonths เดือน', style: const TextStyle(fontWeight: FontWeight.w600)),
              Slider(
                value: _termMonths.toDouble().clamp(product.minTermMonths.toDouble(), product.maxTermMonths.toDouble()),
                min: product.minTermMonths.toDouble(),
                max: product.maxTermMonths.toDouble(),
                divisions: product.maxTermMonths > product.minTermMonths
                    ? product.maxTermMonths - product.minTermMonths
                    : null,
                label: '$_termMonths เดือน',
                onChanged: (v) => setState(() => _termMonths = v.round()),
                onChangeEnd: (_) => _refreshQuote(),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _loadingQuote ? null : _refreshQuote,
                child: _loadingQuote
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('คำนวณค่างวด'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              if (_quote != null) ...[
                const SizedBox(height: 16),
                _QuoteCard(quote: _quote!),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_quote == null || _applying) ? null : _apply,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _applying
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('ยื่นขอสินเชื่อ'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote});
  final LoanQuoteDto quote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE5007D).withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5007D).withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('วงเงินที่ได้รับอนุมัติ: ${formatBaht(quote.approvedAmount)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (quote.capReasons.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final reason in quote.capReasons)
              Text('• $reason', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
          ],
          const Divider(height: 20),
          _row(context, 'ค่างวดต่อเดือน', formatBaht(quote.monthlyInstallment)),
          _row(context, 'ดอกเบี้ยรวม', formatBaht(quote.totalInterest)),
          _row(context, 'ยอดชำระรวม', formatBaht(quote.totalRepayment)),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: const TextStyle(fontSize: 13)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))],
    ),
  );
}

class _SubmittedSheet extends ConsumerStatefulWidget {
  const _SubmittedSheet({required this.application});
  final LoanApplicationDto application;

  @override
  ConsumerState<_SubmittedSheet> createState() => _SubmittedSheetState();
}

class _SubmittedSheetState extends ConsumerState<_SubmittedSheet> {
  bool _disbursing = false;
  String? _error;

  Future<void> _disburseNow() async {
    setState(() {
      _disbursing = true;
      _error = null;
    });
    try {
      await ref.read(turboRepositoryProvider).disburseLoan(widget.application.id);
      ref.invalidate(loanAccountSummaryProvider);
      ref.invalidate(loanApplicationsProvider);
      ref.invalidate(incomeProfileProvider);
      if (mounted) {
        Navigator.of(context).pop();
        context.pushReplacement('/turbo/loans/account');
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      if (mounted) {
        setState(() {
          _error = (data is Map && data['detail'] != null) ? data['detail'].toString() : 'เบิกจ่ายไม่สำเร็จ';
        });
      }
    } finally {
      if (mounted) setState(() => _disbursing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF66BB6A), size: 48),
          const SizedBox(height: 12),
          const Text('ส่งคำขอสินเชื่อแล้ว', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'วงเงิน ${formatBaht(widget.application.approvedAmount)} · ค่างวด ${formatBaht(widget.application.monthlyInstallment)}/เดือน\n'
            'สาขาใกล้คุณจะติดต่อกลับภายใน 15 นาที',
            style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _disbursing ? null : _disburseNow,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _disbursing
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('รับเงินทันที (เดโม)'),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ปุ่มนี้เป็นการเดโมเท่านั้น — ของจริงต้องรอสาขายืนยันก่อนเบิกจ่าย',
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('ปิด')),
          ),
        ],
      ),
    );
  }
}
