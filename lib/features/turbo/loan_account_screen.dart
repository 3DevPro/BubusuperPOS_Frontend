import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/formatters.dart';
import 'turbo_providers.dart';
import 'turbo_repository.dart';

String _shortDate(DateTime d) => '${d.day}/${d.month}/${d.year + 543}';

class LoanAccountScreen extends ConsumerWidget {
  const LoanAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(loanAccountSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('บัญชีสินเชื่อ')),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดข้อมูลไม่สำเร็จ: $err')),
        data: (summary) {
          if (summary == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('ยังไม่มีบัญชีสินเชื่อที่ใช้งานอยู่', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: () => context.pop(), child: const Text('กลับไปเลือกสินเชื่อ')),
                  ],
                ),
              ),
            );
          }
          return _AccountBody(summary: summary);
        },
      ),
    );
  }
}

class _AccountBody extends ConsumerWidget {
  const _AccountBody({required this.summary});
  final LoanAccountSummaryDto summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installmentsAsync = ref.watch(loanInstallmentsProvider(summary.account.id));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(loanAccountSummaryProvider);
        ref.invalidate(loanInstallmentsProvider(summary.account.id));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SummaryHeader(summary: summary),
          const SizedBox(height: 20),
          const Text('ตารางผ่อนชำระ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          installmentsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Text('โหลดตารางผ่อนไม่สำเร็จ: $err'),
            data: (installments) => Column(
              children: [for (final i in installments) _InstallmentTile(installment: i)],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.summary});
  final LoanAccountSummaryDto summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('บัญชี ${summary.account.accountNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('เงินต้น ${formatBaht(summary.account.principal)} · ${summary.account.termMonths} เดือน',
                style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _stat(context, 'ยอดคงค้าง', formatBaht(summary.outstandingBalance), const Color(0xFFE5007D)),
                ),
                Expanded(
                  child: _stat(context, 'ผ่อนตรงเวลา', '${summary.onTimePayments} งวด', const Color(0xFF66BB6A)),
                ),
              ],
            ),
            if (summary.nextDueDate != null) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('งวดถัดไป ${_shortDate(summary.nextDueDate!)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(formatBaht(summary.nextDueAmount!), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ] else
              const Padding(padding: EdgeInsets.only(top: 16), child: Text('ผ่อนครบทุกงวดแล้ว 🎉')),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      ],
    );
  }
}

class _InstallmentTile extends StatelessWidget {
  const _InstallmentTile({required this.installment});
  final LoanInstallmentDto installment;

  @override
  Widget build(BuildContext context) {
    final paid = installment.status == 'paid';
    final color = paid ? const Color(0xFF66BB6A) : (installment.isOverdue ? const Color(0xFFEF5350) : const Color(0xFFFFA726));
    final statusLabel =
        paid ? 'ชำระแล้ว' : (installment.isOverdue ? 'เกินกำหนด ${installment.daysOverdue} วัน' : 'รอชำระ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          foregroundColor: color,
          child: Text('${installment.sequence}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        title: Text('${_shortDate(installment.dueDate)} · ${formatBaht(installment.amountDue)}'),
        subtitle: Text(statusLabel, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        trailing: paid
            ? const Icon(Icons.check_circle, color: Color(0xFF66BB6A))
            : FilledButton(
                onPressed: () => context.push('/turbo/loans/installments/pay', extra: installment),
                child: const Text('ชำระด้วย QR'),
              ),
      ),
    );
  }
}
