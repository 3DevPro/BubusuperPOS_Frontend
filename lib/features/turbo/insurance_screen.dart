import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/formatters.dart';
import 'turbo_providers.dart';
import 'turbo_repository.dart';

String _cycleLabel(String cycle) => switch (cycle) { 'daily' => 'วัน', 'weekly' => 'สัปดาห์', _ => 'เดือน' };
String _shortDate(DateTime d) => '${d.day}/${d.month}';

class InsuranceScreen extends ConsumerWidget {
  const InsuranceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(insuranceProductsProvider);
    final policiesAsync = ref.watch(insurancePoliciesProvider);
    final claimsAsync = ref.watch(insuranceClaimsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ประกันจิ๋ว')),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดข้อมูลไม่สำเร็จ: $err')),
        data: (products) => policiesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('โหลดข้อมูลไม่สำเร็จ: $err')),
          data: (policies) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(insuranceProductsProvider);
              ref.invalidate(insurancePoliciesProvider);
              ref.invalidate(insuranceClaimsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final product in products) ...[
                  _ProductCard(product: product, policy: _activePolicyFor(policies, product.id)),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                const Text('ประวัติการเคลม', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                claimsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => Text('โหลดไม่สำเร็จ: $err'),
                  data: (claims) => claims.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('ยังไม่มีประวัติการเคลม', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                        )
                      : Card(
                          child: Column(
                            children: [
                              for (final claim in claims)
                                ListTile(
                                  leading: const Icon(Icons.check_circle_outline, color: Color(0xFF66BB6A)),
                                  title: Text('${_shortDate(claim.startDate)} – ${_shortDate(claim.endDate)} · ${claim.days} วัน'),
                                  trailing: Text(formatBaht(claim.benefitAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InsurancePolicyDto? _activePolicyFor(List<InsurancePolicyDto> policies, String productId) {
    for (final policy in policies) {
      if (policy.productId == productId && policy.status == 'active') return policy;
    }
    return null;
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.policy});
  final InsuranceProductDto product;
  final InsurancePolicyDto? policy;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        product.description,
                        style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (policy != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF66BB6A).withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ใช้งานอยู่',
                      style: TextStyle(color: Color(0xFF66BB6A), fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  )
                else
                  FilledButton(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (context) => _QuoteSheet(product: product),
                    ),
                    child: const Text('ดูราคา'),
                  ),
              ],
            ),
            if (policy != null) ...[
              const SizedBox(height: 8),
              Text(
                'เบี้ย ${formatBaht(policy!.premiumAmount)} / ${_cycleLabel(policy!.premiumCycle)}'
                '${policy!.dailyBenefit > Decimal.zero ? ' · ชดเชย ${formatBaht(policy!.dailyBenefit)}/วัน' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
              if (product.kind == 'daily_income') _ClaimsSection(policy: policy!),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuoteSheet extends ConsumerStatefulWidget {
  const _QuoteSheet({required this.product});
  final InsuranceProductDto product;

  @override
  ConsumerState<_QuoteSheet> createState() => _QuoteSheetState();
}

class _QuoteSheetState extends ConsumerState<_QuoteSheet> {
  InsuranceQuoteDto? _quote;
  String? _error;
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    try {
      final quote = await ref.read(turboRepositoryProvider).insuranceQuote(widget.product.code);
      if (mounted) setState(() => _quote = quote);
    } on DioException catch (_) {
      if (mounted) setState(() => _error = 'ดึงราคาไม่สำเร็จ');
    }
  }

  Future<void> _buy() async {
    setState(() {
      _buying = true;
      _error = null;
    });
    try {
      await ref.read(turboRepositoryProvider).purchaseInsurance(widget.product.code);
      ref.invalidate(insurancePoliciesProvider);
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _error = (data is Map && data['detail'] != null) ? data['detail'].toString() : 'ซื้อประกันไม่สำเร็จ';
      });
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            widget.product.description,
            style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13),
          ),
          const SizedBox(height: 20),
          if (_quote == null && _error == null) const Center(child: CircularProgressIndicator()),
          if (_quote != null) ...[
            if (_quote!.dailyBenefit > Decimal.zero) _quoteRow('ค่าชดเชยต่อวัน', formatBaht(_quote!.dailyBenefit)),
            _quoteRow('เบี้ยประกัน', '${formatBaht(_quote!.premiumAmount)} / ${_cycleLabel(_quote!.premiumCycle)}'),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_quote == null || _buying) ? null : _buy,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _buying
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('ซื้อเลย'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quoteRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))],
      ),
    );
  }
}

class _ClaimsSection extends ConsumerWidget {
  const _ClaimsSection({required this.policy});
  final InsurancePolicyDto policy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detectedAsync = ref.watch(detectedClaimsProvider(policy.id));

    return detectedAsync.when(
      loading: () => const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
      error: (err, _) => Text('โหลดข้อมูลเคลมไม่สำเร็จ: $err', style: const TextStyle(fontSize: 12)),
      data: (detected) {
        if (detected.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 24),
            const Text('ตรวจพบวันที่เคลมได้', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            for (final claim in detected) _DetectedClaimTile(policyId: policy.id, claim: claim),
          ],
        );
      },
    );
  }
}

class _DetectedClaimTile extends ConsumerStatefulWidget {
  const _DetectedClaimTile({required this.policyId, required this.claim});
  final String policyId;
  final DetectedClaimDto claim;

  @override
  ConsumerState<_DetectedClaimTile> createState() => _DetectedClaimTileState();
}

class _DetectedClaimTileState extends ConsumerState<_DetectedClaimTile> {
  bool _confirming = false;

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    try {
      await ref
          .read(turboRepositoryProvider)
          .createClaim(
            policyId: widget.policyId,
            startDate: widget.claim.startDate,
            endDate: widget.claim.endDate,
          );
      ref.invalidate(detectedClaimsProvider(widget.policyId));
      ref.invalidate(insuranceClaimsProvider);
    } on DioException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ยืนยันเคลมไม่สำเร็จ')));
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final claim = widget.claim;
    final range = claim.days == 1
        ? _shortDate(claim.startDate)
        : '${_shortDate(claim.startDate)} – ${_shortDate(claim.endDate)}';

    return Card(
      color: const Color(0xFF66BB6A).withAlpha(20),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.notifications_active_outlined, color: Color(0xFF66BB6A)),
        title: Text('$range · ${claim.days} วัน'),
        subtitle: Text('รับเงินชดเชย ${formatBaht(claim.benefitAmount)}'),
        trailing: FilledButton(
          onPressed: _confirming ? null : _confirm,
          child: _confirming
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('ยืนยันรับเงิน'),
        ),
      ),
    );
  }
}
