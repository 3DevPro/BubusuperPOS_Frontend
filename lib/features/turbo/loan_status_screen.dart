import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/formatters.dart';
import 'turbo_providers.dart';
import 'turbo_repository.dart';

const _loanStageLabels = {
  'submitted': 'ยื่นคำขอ',
  'doc_review': 'ตรวจเอกสาร',
  'collateral_check': 'ตรวจหลักประกัน',
  'under_review': 'พิจารณาอนุมัติ',
  'approved': 'อนุมัติแล้ว',
  'disbursed': 'รับเงินแล้ว',
  'rejected': 'ไม่อนุมัติ',
};

// The 5-step forward path the timeline draws — rejected/disbursed are
// outcomes shown separately (a red card / an auto-redirect), not rows in
// this list, same as _loanStageLabels having 7 entries for only 5 rows.
// Public (not underscore-prefixed) specifically so test/loan_status_test.dart
// can exercise the timeline math without pumping a widget — see the plan's
// test section.
const forwardLoanStages = ['submitted', 'doc_review', 'collateral_check', 'under_review', 'approved'];

bool isReviewInProgress(String status) => forwardLoanStages.take(4).contains(status);

int reachedIndexAtRejection(List<LoanApplicationEventDto> events) {
  var maxIndex = 0;
  for (final e in events) {
    final toIdx = forwardLoanStages.indexOf(e.toStatus);
    if (toIdx > maxIndex) maxIndex = toIdx;
    final fromIdx = e.fromStatus == null ? -1 : forwardLoanStages.indexOf(e.fromStatus!);
    if (fromIdx > maxIndex) maxIndex = fromIdx;
  }
  return maxIndex;
}

class LoanStatusScreen extends ConsumerWidget {
  const LoanStatusScreen({super.key, required this.applicationId});
  final String applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(loanApplicationDetailProvider(applicationId));

    ref.listen(loanApplicationDetailProvider(applicationId), (previous, next) {
      final status = next.valueOrNull?.status;
      if (status == null) return;
      if (isTerminalLoanStatus(status)) {
        ref.invalidate(loanApplicationsProvider);
        ref.invalidate(loanAccountSummaryProvider);
        ref.invalidate(incomeProfileProvider);
      }
      // Covers disbursal happening from elsewhere (another device/tab) while
      // this screen is open and polling — the button-driven disburse below
      // navigates on its own success response, this is the same outcome
      // reached a different way.
      if (status == 'disbursed' && previous?.valueOrNull?.status != 'disbursed') {
        context.pushReplacement('/turbo/loans/account');
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('สถานะคำขอสินเชื่อ')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดไม่สำเร็จ: $err')),
        data: (detail) => _StatusBody(applicationId: applicationId, detail: detail),
      ),
    );
  }
}

class _StatusBody extends ConsumerStatefulWidget {
  const _StatusBody({required this.applicationId, required this.detail});
  final String applicationId;
  final LoanApplicationDetailDto detail;

  @override
  ConsumerState<_StatusBody> createState() => _StatusBodyState();
}

class _StatusBodyState extends ConsumerState<_StatusBody> {
  bool _disbursing = false;
  bool _fastForwarding = false;
  String? _error;

  Future<void> _disburseNow() async {
    setState(() {
      _disbursing = true;
      _error = null;
    });
    try {
      await ref.read(turboRepositoryProvider).disburseLoan(widget.applicationId);
      ref.invalidate(loanAccountSummaryProvider);
      ref.invalidate(loanApplicationsProvider);
      ref.invalidate(incomeProfileProvider);
      if (mounted) context.pushReplacement('/turbo/loans/account');
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

  Future<void> _fastForward() async {
    setState(() => _fastForwarding = true);
    try {
      await ref.read(turboRepositoryProvider).fastForwardLoanApplication(widget.applicationId);
      ref.invalidate(loanApplicationDetailProvider(widget.applicationId));
    } on DioException {
      // Best-effort demo shortcut — a failure here just means the clock
      // handles it on its own on the next poll instead.
    } finally {
      if (mounted) setState(() => _fastForwarding = false);
    }
  }

  Widget _timeline(String status, List<LoanApplicationEventDto> events) {
    final reachedAtRejection = status == 'rejected' ? reachedIndexAtRejection(events) : null;
    final currentOrdinal = isReviewInProgress(status) ? forwardLoanStages.indexOf(status) : null;
    final allDone = status == 'approved' || status == 'disbursed';

    return Column(
      children: [
        for (var i = 0; i < forwardLoanStages.length; i++)
          _TimelineRow(
            label: _loanStageLabels[forwardLoanStages[i]]!,
            isDone: allDone || (reachedAtRejection != null ? i < reachedAtRejection : currentOrdinal != null && i < currentOrdinal),
            isCurrent: currentOrdinal == i || reachedAtRejection == i,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final outline = Theme.of(context).colorScheme.outline;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(loanApplicationDetailProvider(widget.applicationId)),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatBaht(detail.approvedAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(
                    'ค่างวด ${formatBaht(detail.monthlyInstallment)}/เดือน · ${detail.termMonths} งวด',
                    style: TextStyle(color: outline),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ความคืบหน้า', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _timeline(detail.status, detail.events),
                  const SizedBox(height: 8),
                  Text('สถานะปัจจุบัน: ${_loanStageLabels[detail.status] ?? detail.status}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (!isTerminalLoanStatus(detail.status)) ...[
                    const SizedBox(height: 4),
                    _ElapsedTicker(stageStartedAt: detail.stageStartedAt),
                  ],
                ],
              ),
            ),
          ),
          if (detail.collateralDetail.registrationNo != null ||
              detail.collateralDetail.brandModel != null ||
              detail.collateralDetail.year != null ||
              detail.collateralDetail.note != null) ...[
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('รายละเอียดหลักประกัน', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (detail.collateralDetail.registrationNo != null)
                      Text('เลขทะเบียน/เลขที่: ${detail.collateralDetail.registrationNo}'),
                    if (detail.collateralDetail.brandModel != null)
                      Text('ยี่ห้อ/รุ่น: ${detail.collateralDetail.brandModel}'),
                    if (detail.collateralDetail.year != null) Text('ปี: ${detail.collateralDetail.year}'),
                    if (detail.collateralDetail.note != null) Text('หมายเหตุ: ${detail.collateralDetail.note}'),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ประวัติ', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  for (final event in detail.events)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '${_loanStageLabels[event.toStatus] ?? event.toStatus} · ${event.actorName}'
                              '${event.note != null && event.note!.isNotEmpty ? ' — ${event.note}' : ''}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(formatThaiDateTime(event.createdAt), style: TextStyle(fontSize: 11, color: outline)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          if (detail.status == 'approved')
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _disbursing ? null : _disburseNow,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _disbursing
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('รับเงินทันที'),
              ),
            )
          else if (detail.status == 'rejected')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF5350).withAlpha(20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEF5350).withAlpha(80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('คำขอไม่ได้รับการอนุมัติ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF5350))),
                  if (detail.rejectionReason != null) ...[
                    const SizedBox(height: 4),
                    Text(detail.rejectionReason!, style: const TextStyle(fontSize: 13)),
                  ],
                  if (detail.canReapplyAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'ยื่นใหม่ได้อีก ${detail.canReapplyAt!.difference(DateTime.now()).inDays + 1} วัน',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          if (!isTerminalLoanStatus(detail.status)) ...[
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton(
                onPressed: _fastForwarding ? null : _fastForward,
                child: _fastForwarding
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('เร่งเวลา (เดโม)'),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.label, required this.isDone, required this.isCurrent});
  final String label;
  final bool isDone;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final color = isDone ? const Color(0xFF66BB6A) : (isCurrent ? const Color(0xFFFFA726) : Colors.grey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color.withAlpha(30),
            foregroundColor: color,
            child: Icon(
              isDone ? Icons.check : (isCurrent ? Icons.hourglass_top : Icons.circle_outlined),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isDone || isCurrent ? null : Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Lifted from _SlaCountdown (branch_home_screen.dart) — same
// Timer-in-initState/cancel-in-dispose lifecycle, copied rather than
// imported since that class is private and that file is already 500+ lines.
class _ElapsedTicker extends StatefulWidget {
  const _ElapsedTicker({required this.stageStartedAt});
  final DateTime stageStartedAt;

  @override
  State<_ElapsedTicker> createState() => _ElapsedTickerState();
}

class _ElapsedTickerState extends State<_ElapsedTicker> {
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
    final elapsed = DateTime.now().difference(widget.stageStartedAt.toLocal());
    return Text(
      'อยู่ในขั้นตอนนี้มาแล้ว ${_fmt(elapsed.isNegative ? Duration.zero : elapsed)}',
      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
    );
  }
}
