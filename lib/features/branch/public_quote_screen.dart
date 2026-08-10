import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/formatters.dart';
import 'branch_providers.dart';
import 'branch_repository.dart';

const _collateralLabels = {
  'motorcycle': 'มอเตอร์ไซค์',
  'car': 'รถยนต์',
  'tractor': 'แทรกเตอร์',
  'land_title': 'โฉนดที่ดิน',
};

class _TermRange {
  const _TermRange(this.min, this.max);
  final int min;
  final int max;
}

/// Public O2O quote page — no login required (see router.dart, which keeps
/// this path outside the auth redirect). "เช็คเบี้ยใน 3 คลิก" from the case,
/// now with two tabs: the original insurance quote and a loan quote for the
/// case's 4 secured-loan products. Either tab creates a Lead routed to the
/// nearest branch (see Backend's public_quote_service).
class PublicQuoteScreen extends StatefulWidget {
  const PublicQuoteScreen({super.key});

  @override
  State<PublicQuoteScreen> createState() => _PublicQuoteScreenState();
}

class _PublicQuoteScreenState extends State<PublicQuoteScreen> with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เช็คราคาใน 3 คลิก'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'สินเชื่อ'), Tab(text: 'ประกัน')],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: TabBarView(
            controller: _tabController,
            children: const [_LoanQuoteTab(), _InsuranceQuoteTab()],
          ),
        ),
      ),
    );
  }
}

class _InsuranceQuoteTab extends ConsumerStatefulWidget {
  const _InsuranceQuoteTab();

  @override
  ConsumerState<_InsuranceQuoteTab> createState() => _InsuranceQuoteTabState();
}

class _InsuranceQuoteTabState extends ConsumerState<_InsuranceQuoteTab> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _occupationController = TextEditingController();
  final _ageController = TextEditingController();
  final _budgetController = TextEditingController();
  final _provinceController = TextEditingController();

  bool _submitting = false;
  String? _error;
  PublicQuoteDto? _quote;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _occupationController.dispose();
    _ageController.dispose();
    _budgetController.dispose();
    _provinceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final age = int.tryParse(_ageController.text.trim());
    final budget = Decimal.tryParse(_budgetController.text.trim());
    if (_nameController.text.trim().isEmpty ||
        _occupationController.text.trim().isEmpty ||
        age == null ||
        budget == null ||
        budget <= Decimal.zero) {
      setState(() => _error = 'กรอกข้อมูลให้ครบและถูกต้อง');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final quote = await ref
          .read(branchRepositoryProvider)
          .publicQuote(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            occupation: _occupationController.text.trim(),
            age: age,
            monthlyBudget: budget,
            province: _provinceController.text.trim(),
          );
      setState(() => _quote = quote);
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _error = (data is Map && data['detail'] != null) ? data['detail'].toString() : 'เช็คราคาไม่สำเร็จ ลองใหม่อีกครั้ง';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _quote == null ? _buildForm(context) : _buildResult(context, _quote!),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ประกันชดเชยรายได้รายวัน', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'กรอกข้อมูล 3 อย่าง เห็นราคาจริงทันที ไม่ต้องโหลดแอป ไม่ต้องสมัครสมาชิก',
          style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13),
        ),
        const SizedBox(height: 24),
        TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'ชื่อ')),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(labelText: 'เบอร์โทร (ถ้ามี)'),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        TextField(controller: _occupationController, decoration: const InputDecoration(labelText: 'อาชีพ')),
        const SizedBox(height: 12),
        TextField(
          controller: _ageController,
          decoration: const InputDecoration(labelText: 'อายุ'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _budgetController,
          decoration: const InputDecoration(labelText: 'งบต่อเดือนที่จ่ายไหว (บาท)'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 12),
        TextField(controller: _provinceController, decoration: const InputDecoration(labelText: 'จังหวัด (ถ้ามี)')),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('เช็คราคาเลย'),
          ),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context, PublicQuoteDto quote) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF66BB6A), size: 48),
        const SizedBox(height: 12),
        const Text('นี่คือราคาของคุณ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ค่าชดเชยรายวัน', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13)),
                Text(formatBaht(quote.dailyBenefit), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text('เบี้ยประกัน', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13)),
                Text('${formatBaht(quote.premiumAmount)} / วัน', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'พนักงานสาขาใกล้บ้านคุณจะติดต่อกลับภายใน 15 นาที เพื่อยืนยันและปิดการสมัคร',
          style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => setState(() => _quote = null),
            child: const Text('เช็คราคาใหม่'),
          ),
        ),
      ],
    );
  }
}

class _LoanQuoteTab extends ConsumerStatefulWidget {
  const _LoanQuoteTab();

  @override
  ConsumerState<_LoanQuoteTab> createState() => _LoanQuoteTabState();
}

class _LoanQuoteTabState extends ConsumerState<_LoanQuoteTab> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _occupationController = TextEditingController();
  final _ageController = TextEditingController();
  final _collateralValueController = TextEditingController();
  final _requestedAmountController = TextEditingController();
  final _provinceController = TextEditingController();

  String _collateralKind = 'motorcycle';
  double _termMonths = 24;

  bool _submitting = false;
  String? _error;
  PublicLoanQuoteDto? _quote;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _occupationController.dispose();
    _ageController.dispose();
    _collateralValueController.dispose();
    _requestedAmountController.dispose();
    _provinceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final age = int.tryParse(_ageController.text.trim());
    final collateralValue = Decimal.tryParse(_collateralValueController.text.trim());
    final requestedAmount = Decimal.tryParse(_requestedAmountController.text.trim());
    if (_nameController.text.trim().isEmpty ||
        _occupationController.text.trim().isEmpty ||
        age == null ||
        collateralValue == null ||
        collateralValue <= Decimal.zero ||
        requestedAmount == null ||
        requestedAmount <= Decimal.zero) {
      setState(() => _error = 'กรอกข้อมูลให้ครบและถูกต้อง');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    final range = _rangeFor(ref.read(loanTermBoundsProvider).valueOrNull, _collateralKind);
    final termMonths = _termMonths.clamp(range.min.toDouble(), range.max.toDouble()).round();
    try {
      final quote = await ref
          .read(branchRepositoryProvider)
          .publicLoanQuote(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            occupation: _occupationController.text.trim(),
            age: age,
            collateralKind: _collateralKind,
            collateralValue: collateralValue,
            requestedAmount: requestedAmount,
            termMonths: termMonths,
            province: _provinceController.text.trim(),
          );
      setState(() => _quote = quote);
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _error = (data is Map && data['detail'] != null) ? data['detail'].toString() : 'เช็คราคาไม่สำเร็จ ลองใหม่อีกครั้ง';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  _TermRange _rangeFor(List<LoanTermBoundsDto>? bounds, String collateralKind) {
    if (bounds == null) return const _TermRange(12, 36); // fallback while loading/on error
    for (final b in bounds) {
      if (b.collateralKind == collateralKind) return _TermRange(b.minTermMonths, b.maxTermMonths);
    }
    return const _TermRange(12, 36);
  }

  @override
  Widget build(BuildContext context) {
    final bounds = ref.watch(loanTermBoundsProvider).valueOrNull;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _quote == null ? _buildForm(context, bounds) : _buildResult(context, _quote!),
    );
  }

  Widget _buildForm(BuildContext context, List<LoanTermBoundsDto>? bounds) {
    final range = _rangeFor(bounds, _collateralKind);
    final clampedTerm = _termMonths.clamp(range.min.toDouble(), range.max.toDouble());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('สินเชื่อมีหลักประกัน', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'เลือกหลักประกัน กรอกราคาประเมินและจำนวนที่ต้องการ เห็นค่างวดจริงทันที',
          style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in _collateralLabels.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _collateralKind == entry.key,
                onSelected: (_) => setState(() {
                  _collateralKind = entry.key;
                  final newRange = _rangeFor(bounds, entry.key);
                  _termMonths = _termMonths.clamp(newRange.min.toDouble(), newRange.max.toDouble());
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'ชื่อ')),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(labelText: 'เบอร์โทร (ถ้ามี)'),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        TextField(controller: _occupationController, decoration: const InputDecoration(labelText: 'อาชีพ')),
        const SizedBox(height: 12),
        TextField(
          controller: _ageController,
          decoration: const InputDecoration(labelText: 'อายุ'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _collateralValueController,
          decoration: const InputDecoration(labelText: 'ราคาประเมินหลักประกัน (บาท)'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _requestedAmountController,
          decoration: const InputDecoration(labelText: 'จำนวนที่ต้องการยื่นขอ (บาท)'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 8),
        Text('จำนวนงวด: ${clampedTerm.round()} เดือน', style: const TextStyle(fontWeight: FontWeight.w600)),
        Slider(
          value: clampedTerm,
          min: range.min.toDouble(),
          max: range.max.toDouble(),
          divisions: range.max > range.min ? range.max - range.min : null,
          label: '${clampedTerm.round()} เดือน',
          onChanged: (v) => setState(() => _termMonths = v),
        ),
        TextField(controller: _provinceController, decoration: const InputDecoration(labelText: 'จังหวัด (ถ้ามี)')),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('เช็คราคาเลย'),
          ),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context, PublicLoanQuoteDto quote) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF66BB6A), size: 48),
        const SizedBox(height: 12),
        const Text('นี่คือราคาของคุณ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('วงเงินที่ได้รับ', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13)),
                Text(formatBaht(quote.approvedAmount), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text('ค่างวดต่อเดือน', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13)),
                Text('${formatBaht(quote.monthlyInstallment)} × ${quote.termMonths} เดือน', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('ดอกเบี้ยรวม ${formatBaht(quote.totalInterest)} · ยอดชำระรวม ${formatBaht(quote.totalRepayment)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'พนักงานสาขาใกล้บ้านคุณจะติดต่อกลับภายใน 15 นาที เพื่อยืนยันและปิดการสมัคร',
          style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => setState(() => _quote = null),
            child: const Text('เช็คราคาใหม่'),
          ),
        ),
      ],
    );
  }
}
