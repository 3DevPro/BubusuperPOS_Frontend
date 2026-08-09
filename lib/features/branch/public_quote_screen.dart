import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/formatters.dart';
import 'branch_providers.dart';
import 'branch_repository.dart';

/// Public O2O quote page — no login required (see router.dart, which keeps
/// this path outside the auth redirect). "เช็คเบี้ยใน 3 คลิก" from the case:
/// occupation/age/budget in, a real price out, and a Lead is created and
/// routed to the nearest branch (see Backend's public_quote_service).
class PublicQuoteScreen extends ConsumerStatefulWidget {
  const PublicQuoteScreen({super.key});

  @override
  ConsumerState<PublicQuoteScreen> createState() => _PublicQuoteScreenState();
}

class _PublicQuoteScreenState extends ConsumerState<PublicQuoteScreen> {
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
    return Scaffold(
      appBar: AppBar(title: const Text('เช็คเบี้ยประกัน')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _quote == null ? _buildForm(context) : _buildResult(context, _quote!),
          ),
        ),
      ),
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
