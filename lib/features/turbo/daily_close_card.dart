import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'turbo_providers.dart';
import 'turbo_repository.dart';

// "open" isn't offered in the reason sheet below — it's what closing via the
// single primary button means (the shop traded normally today), so it only
// ever appears here as a status label for an already-closed day.
const _reasonLabels = {
  'open': 'เปิดร้านตามปกติ',
  'sick': 'ป่วย',
  'accident': 'อุบัติเหตุ',
  'holiday': 'วันหยุด',
  'other': 'อื่น ๆ',
};

const _closedReasons = ['sick', 'accident', 'holiday', 'other'];

/// Dashboard card for the daily-close ritual — this is what lets Turbo's
/// income-certificate logic later tell "day genuinely closed" (claim
/// evidence) apart from "no data recorded yet" (see app/models/turbo).
class DailyCloseCard extends ConsumerWidget {
  const DailyCloseCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final closeAsync = ref.watch(todayCloseProvider);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: closeAsync.when(
          loading: () => const SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (err, _) => Text('โหลดสถานะปิดร้านไม่สำเร็จ: $err'),
          data: (close) {
            if (close == null) {
              return _NotClosedYet(
                onCloseNormally: () => _closeNow(context, ref, 'open'),
                onShopClosed: () => _openReasonSheet(context, ref),
              );
            }
            return _AlreadyClosed(close: close, onEdit: () => _openReasonSheet(context, ref, existing: close));
          },
        ),
      ),
    );
  }

  Future<void> _closeNow(BuildContext context, WidgetRef ref, String reason) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(turboRepositoryProvider).closeDay(businessDate: DateTime.now(), closedReason: reason);
      ref.invalidate(todayCloseProvider);
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = (data is Map && data['detail'] != null) ? data['detail'].toString() : 'ปิดร้านไม่สำเร็จ';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openReasonSheet(BuildContext context, WidgetRef ref, {DailyCloseDto? existing}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _CloseShopSheet(existing: existing),
    );
  }
}

class _NotClosedYet extends StatelessWidget {
  const _NotClosedYet({required this.onCloseNormally, required this.onShopClosed});
  final VoidCallback onCloseNormally;
  final VoidCallback onShopClosed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ปิดร้านวันนี้', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'ยืนยันปิดยอดวันนี้ทุกวัน เพื่อให้ระบบรู้ว่าวันไหนขายจริง วันไหนร้านปิด',
          style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onCloseNormally,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('ปิดร้านวันนี้'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(onPressed: onShopClosed, child: const Text('วันนี้ร้านปิด (ไม่ได้ขาย)')),
        ),
      ],
    );
  }
}

class _AlreadyClosed extends StatelessWidget {
  const _AlreadyClosed({required this.close, required this.onEdit});
  final DailyCloseDto close;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final isOpen = close.closedReason == 'open';
    final color = isOpen ? const Color(0xFF66BB6A) : const Color(0xFFFFA726);
    final label = _reasonLabels[close.closedReason] ?? close.closedReason;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(14)),
          child: Icon(isOpen ? Icons.check_circle : Icons.storefront_outlined, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isOpen ? 'ปิดยอดวันนี้แล้ว' : 'วันนี้ร้านปิด: $label',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              if (close.note != null && close.note!.isNotEmpty)
                Text(close.note!, style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13)),
            ],
          ),
        ),
        TextButton(onPressed: onEdit, child: const Text('แก้ไข')),
      ],
    );
  }
}

class _CloseShopSheet extends ConsumerStatefulWidget {
  const _CloseShopSheet({this.existing});
  final DailyCloseDto? existing;

  @override
  ConsumerState<_CloseShopSheet> createState() => _CloseShopSheetState();
}

class _CloseShopSheetState extends ConsumerState<_CloseShopSheet> {
  late String _reason = widget.existing != null && _closedReasons.contains(widget.existing!.closedReason)
      ? widget.existing!.closedReason
      : 'sick';
  late final _expenseController = TextEditingController(
    text: widget.existing != null && widget.existing!.extraExpense > Decimal.zero
        ? widget.existing!.extraExpense.toString()
        : '',
  );
  late final _noteController = TextEditingController(text: widget.existing?.note ?? '');
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _expenseController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    Decimal? extraExpense;
    if (_expenseController.text.trim().isNotEmpty) {
      try {
        extraExpense = Decimal.parse(_expenseController.text.trim());
      } catch (_) {
        setState(() => _error = 'กรอกจำนวนเงินให้ถูกต้อง');
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(turboRepositoryProvider)
          .closeDay(
            businessDate: DateTime.now(),
            closedReason: _reason,
            extraExpense: extraExpense,
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          );
      ref.invalidate(todayCloseProvider);
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _error = (data is Map && data['detail'] != null) ? data['detail'].toString() : 'บันทึกไม่สำเร็จ';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
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
          const Text('วันนี้ร้านปิด', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'เลือกเหตุผล เพื่อให้ระบบแยกวันร้านปิดออกจากวันที่ยังไม่ได้บันทึกยอด',
            style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final reason in _closedReasons)
                ChoiceChip(
                  label: Text(_reasonLabels[reason]!),
                  selected: _reason == reason,
                  onSelected: (_) => setState(() => _reason = reason),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _expenseController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'ค่าใช้จ่ายวันนี้ (ถ้ามี)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'หมายเหตุ (ไม่บังคับ)', border: OutlineInputBorder()),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('บันทึก'),
            ),
          ),
        ],
      ),
    );
  }
}
