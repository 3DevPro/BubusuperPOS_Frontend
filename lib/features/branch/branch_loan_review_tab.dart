import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/formatters.dart';
import 'branch_labels.dart';
import 'branch_providers.dart';
import 'branch_repository.dart';

const _statusColors = {
  'submitted': Color(0xFFFFA726),
  'doc_review': Color(0xFF42A5F5),
  'collateral_check': Color(0xFF42A5F5),
  'under_review': Color(0xFFAB47BC),
  'approved': Color(0xFF66BB6A),
};

const _docChecklistItems = ['สำเนาบัตรประชาชน', 'เล่มทะเบียน', 'สมุดบัญชีธนาคาร'];

const _rejectReasonPresets = ['เอกสารไม่ครบ', 'หลักประกันไม่ผ่านเกณฑ์', 'รายได้ไม่เพียงพอ'];

String _errorMessage(Object e) {
  return e is DioException ? (e.response?.data?['detail'] as String? ?? e.message ?? '$e') : '$e';
}

class LoanReviewTab extends ConsumerWidget {
  const LoanReviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(branchLoanApplicationsProvider);

    return applicationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('โหลดไม่สำเร็จ: $err')),
      data: (applications) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(branchLoanApplicationsProvider),
        child: applications.isEmpty
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'ยังไม่มีคำขอสินเชื่อรอตรวจ',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: applications.length,
                itemBuilder: (context, i) => _LoanReviewCard(item: applications[i]),
              ),
      ),
    );
  }
}

class _LoanReviewCard extends ConsumerStatefulWidget {
  const _LoanReviewCard({required this.item});
  final LoanReviewItemDto item;

  @override
  ConsumerState<_LoanReviewCard> createState() => _LoanReviewCardState();
}

class _LoanReviewCardState extends ConsumerState<_LoanReviewCard> {
  final Set<String> _checkedDocs = {};
  bool _submitting = false;

  Future<void> _advance(String toStatus, {String? note}) async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(branchRepositoryProvider)
          .advanceLoanApplication(widget.item.id, toStatus: toStatus, note: note);
      ref.invalidate(branchLoanApplicationsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ทำรายการไม่สำเร็จ: ${_errorMessage(e)}')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openRejectDialog() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectDialog(shopName: widget.item.tenantName),
    );
    if (reason == null) return;

    setState(() => _submitting = true);
    try {
      await ref.read(branchRepositoryProvider).rejectLoanApplication(widget.item.id, reason: reason);
      ref.invalidate(branchLoanApplicationsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ปฏิเสธไม่สำเร็จ: ${_errorMessage(e)}')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _actionArea() {
    final status = widget.item.status;
    if (status == 'submitted') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(onPressed: _submitting ? null : () => _advance('doc_review'), child: const Text('รับเรื่อง')),
      );
    }
    if (status == 'doc_review') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final doc in _docChecklistItems)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(doc, style: const TextStyle(fontSize: 13)),
              value: _checkedDocs.contains(doc),
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  _checkedDocs.add(doc);
                } else {
                  _checkedDocs.remove(doc);
                }
              }),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_submitting || _checkedDocs.length < _docChecklistItems.length)
                  ? null
                  : () => _advance('collateral_check', note: _checkedDocs.join(', ')),
              child: const Text('เอกสารครบ'),
            ),
          ),
        ],
      );
    }
    if (status == 'collateral_check') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _submitting ? null : () => _advance('under_review'),
          child: const Text('หลักประกันผ่าน'),
        ),
      );
    }
    if (status == 'under_review') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(onPressed: _submitting ? null : () => _advance('approved'), child: const Text('อนุมัติ')),
      );
    }
    // approved — nothing left for a Champion to do; the tenant disburses.
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final outline = Theme.of(context).colorScheme.outline;
    final color = _statusColors[item.status] ?? Colors.grey;
    final collateral = item.collateralDetail;
    final hasCollateralDetail =
        collateral.registrationNo != null || collateral.brandModel != null || collateral.year != null || collateral.note != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.tenantName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      if (item.tenantPhone != null) Text(item.tenantPhone!, style: TextStyle(color: outline, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    loanStageLabels[item.status] ?? item.status,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${formatBaht(item.approvedAmount)} · ค่างวด ${formatBaht(item.monthlyInstallment)}/เดือน · ${item.termMonths} งวด',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              'หลักประกัน: ${collateralKindLabels[item.collateralKind] ?? item.collateralKind} · ${formatBaht(item.collateralValue)}',
              style: TextStyle(color: outline, fontSize: 12),
            ),
            if (hasCollateralDetail) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (collateral.registrationNo != null) Text('เลขทะเบียน/เลขที่: ${collateral.registrationNo}', style: const TextStyle(fontSize: 12)),
                    if (collateral.brandModel != null) Text('ยี่ห้อ/รุ่น: ${collateral.brandModel}', style: const TextStyle(fontSize: 12)),
                    if (collateral.year != null) Text('ปี: ${collateral.year}', style: const TextStyle(fontSize: 12)),
                    if (collateral.note != null) Text('หมายเหตุ: ${collateral.note}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
            _WaitingTicker(since: item.stageStartedAt),
            const SizedBox(height: 10),
            _actionArea(),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF5350)),
                onPressed: _submitting ? null : _openRejectDialog,
                child: const Text('ปฏิเสธ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.shopName});
  final String shopName;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('ปฏิเสธคำขอของ ${widget.shopName}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'เหตุผลที่ปฏิเสธ (จำเป็น)', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _rejectReasonPresets)
                ActionChip(label: Text(preset, style: const TextStyle(fontSize: 12)), onPressed: () => setState(() => _controller.text = preset)),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('ยกเลิก')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF5350)),
          onPressed: _controller.text.trim().length >= 5 ? () => Navigator.of(context).pop(_controller.text.trim()) : null,
          child: const Text('ยืนยันปฏิเสธ'),
        ),
      ],
    );
  }
}

// Same Timer-in-initState/cancel-in-dispose lifecycle as _SlaCountdown
// (branch_home_screen.dart), copied rather than imported for the same
// reason loan_status_screen.dart's _ElapsedTicker is: that class is private.
class _WaitingTicker extends StatefulWidget {
  const _WaitingTicker({required this.since});
  final DateTime since;

  @override
  State<_WaitingTicker> createState() => _WaitingTickerState();
}

class _WaitingTickerState extends State<_WaitingTicker> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.since.toLocal());
    return Text(
      'รอมาแล้ว ${_fmt(elapsed.isNegative ? Duration.zero : elapsed)}',
      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
    );
  }
}
