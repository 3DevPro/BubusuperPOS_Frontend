import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/formatters.dart';
import '../auth/auth_provider.dart';
import 'branch_providers.dart';
import 'branch_repository.dart';

const _prospectStatusLabels = {
  'not_visited': 'ยังไม่ได้เยี่ยม',
  'visited': 'เยี่ยมแล้ว',
  'converted': 'สมัครแล้ว',
  'not_interested': 'ไม่สนใจ',
};
const _leadStatusLabels = {'new': 'ใหม่', 'contacted': 'ติดต่อแล้ว', 'converted': 'ปิดได้แล้ว', 'lost': 'ไม่สำเร็จ'};
const _leadSourceLabels = {
  'o2o_web': 'จากเว็บ O2O',
  'visit': 'จากการเยี่ยม',
  'referral': 'แนะนำ',
  'in_app': 'จากในแอป',
};
const _collateralKindLabels = {
  'motorcycle': 'มอเตอร์ไซค์',
  'car': 'รถยนต์',
  'tractor': 'แทรกเตอร์',
  'land_title': 'โฉนดที่ดิน',
};
const _slaTarget = Duration(minutes: 15);

class BranchHomeScreen extends ConsumerWidget {
  const BranchHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider).me;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(me?['name'] as String? ?? 'พนักงานสาขา'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'ออกจากระบบ',
              onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.storefront_outlined), text: 'ผู้ค้า'),
              Tab(icon: Icon(Icons.notifications_active_outlined), text: 'Lead'),
              Tab(icon: Icon(Icons.leaderboard_outlined), text: 'อันดับสาขา'),
            ],
          ),
        ),
        body: const TabBarView(children: [_ProspectsTab(), _LeadsTab(), _LeaderboardTab()]),
      ),
    );
  }
}

// ── Prospects (Morning Route) ──

class _ProspectsTab extends ConsumerWidget {
  const _ProspectsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prospectsAsync = ref.watch(prospectsProvider);

    return Scaffold(
      body: prospectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดไม่สำเร็จ: $err')),
        data: (prospects) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(prospectsProvider),
          child: prospects.isEmpty
              ? ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'ยังไม่มีรายชื่อผู้ค้าในรัศมี กดปุ่ม + เพื่อเพิ่ม',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.outline),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: prospects.length,
                  itemBuilder: (context, i) => _ProspectCard(prospect: prospects[i]),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (context) => const _AddProspectSheet(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ProspectCard extends ConsumerWidget {
  const _ProspectCard({required this.prospect});
  final ProspectDto prospect;

  Color _statusColor() {
    switch (prospect.status) {
      case 'visited':
        return const Color(0xFF42A5F5);
      case 'converted':
        return const Color(0xFF66BB6A);
      case 'not_interested':
        return Colors.grey;
      default:
        return const Color(0xFFFFA726);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _statusColor();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(prospect.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text([
          if (prospect.businessType != null) prospect.businessType!,
          if (prospect.phone != null) prospect.phone!,
          if (prospect.note != null && prospect.note!.isNotEmpty) prospect.note!,
        ].join(' · ')),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(10)),
          child: Text(
            _prospectStatusLabels[prospect.status] ?? prospect.status,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (context) => _VisitProspectSheet(prospect: prospect),
        ),
      ),
    );
  }
}

class _AddProspectSheet extends ConsumerStatefulWidget {
  const _AddProspectSheet();

  @override
  ConsumerState<_AddProspectSheet> createState() => _AddProspectSheetState();
}

class _AddProspectSheetState extends ConsumerState<_AddProspectSheet> {
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(branchRepositoryProvider)
          .createProspect(
            name: _nameController.text.trim(),
            businessType: _typeController.text.trim(),
            phone: _phoneController.text.trim(),
          );
      ref.invalidate(prospectsProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('เพิ่มผู้ค้าในรัศมี', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'ชื่อร้าน/ผู้ค้า')),
          const SizedBox(height: 12),
          TextField(controller: _typeController, decoration: const InputDecoration(labelText: 'ประเภทร้าน (ถ้ามี)')),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'เบอร์โทร (ถ้ามี)'),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
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

class _VisitProspectSheet extends ConsumerStatefulWidget {
  const _VisitProspectSheet({required this.prospect});
  final ProspectDto prospect;

  @override
  ConsumerState<_VisitProspectSheet> createState() => _VisitProspectSheetState();
}

class _VisitProspectSheetState extends ConsumerState<_VisitProspectSheet> {
  late String _status = widget.prospect.status == 'not_visited' ? 'visited' : widget.prospect.status;
  late final _noteController = TextEditingController(text: widget.prospect.note ?? '');
  bool _submitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(branchRepositoryProvider)
          .visitProspect(widget.prospect.id, status: _status, note: _noteController.text.trim());
      ref.invalidate(prospectsProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.prospect.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in ['visited', 'converted', 'not_interested'])
                ChoiceChip(
                  label: Text(_prospectStatusLabels[status]!),
                  selected: _status == status,
                  onSelected: (_) => setState(() => _status = status),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(controller: _noteController, decoration: const InputDecoration(labelText: 'บันทึกการเยี่ยม')),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('บันทึกผลการเยี่ยม'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Leads ──

class _LeadsTab extends ConsumerWidget {
  const _LeadsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leadsAsync = ref.watch(leadsProvider);

    return leadsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('โหลดไม่สำเร็จ: $err')),
      data: (leads) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(leadsProvider),
        child: leads.isEmpty
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'ยังไม่มี Lead เข้ามา',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: leads.length,
                itemBuilder: (context, i) => _LeadCard(lead: leads[i]),
              ),
      ),
    );
  }
}

class _LeadCard extends ConsumerWidget {
  const _LeadCard({required this.lead});
  final LeadDto lead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      Text(lead.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                        [
                          if (lead.occupation != null) lead.occupation!,
                          if (lead.age != null) 'อายุ ${lead.age}',
                          _leadSourceLabels[lead.source] ?? lead.source,
                        ].join(' · '),
                        style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12),
                      ),
                      if (lead.quotedLoanAmount != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          [
                            'สินเชื่อ ${formatBaht(lead.quotedLoanAmount!)}',
                            if (lead.quotedMonthlyInstallment != null)
                              'ค่างวด ${formatBaht(lead.quotedMonthlyInstallment!)}/เดือน',
                            if (lead.collateralKind != null)
                              _collateralKindLabels[lead.collateralKind] ?? lead.collateralKind!,
                          ].join(' · '),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
                if (lead.firstResponseAt == null)
                  _SlaCountdown(createdAt: lead.createdAt)
                else
                  Text(
                    _leadStatusLabels[lead.status] ?? lead.status,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
              ],
            ),
            if (lead.firstResponseAt == null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ref.read(branchRepositoryProvider).respondLead(lead.id, status: 'contacted').then((_) {
                        ref.invalidate(leadsProvider);
                      }),
                      child: const Text('ติดต่อแล้ว'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ref.read(branchRepositoryProvider).respondLead(lead.id, status: 'lost').then((_) {
                        ref.invalidate(leadsProvider);
                      }),
                      child: const Text('ไม่สำเร็จ'),
                    ),
                  ),
                ],
              ),
            ] else if (lead.status == 'contacted') ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => ref.read(branchRepositoryProvider).respondLead(lead.id, status: 'converted').then((_) {
                    ref.invalidate(leadsProvider);
                  }),
                  child: const Text('ปิดการขายได้แล้ว'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SlaCountdown extends StatefulWidget {
  const _SlaCountdown({required this.createdAt});
  final DateTime createdAt;

  @override
  State<_SlaCountdown> createState() => _SlaCountdownState();
}

class _SlaCountdownState extends State<_SlaCountdown> {
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

  @override
  Widget build(BuildContext context) {
    final deadline = widget.createdAt.add(_slaTarget);
    final remaining = deadline.difference(DateTime.now());
    final overdue = remaining.isNegative;
    final label = overdue ? 'เกินเวลา ${_fmt(-remaining)}' : 'เหลือ ${_fmt(remaining)}';

    return Text(
      label,
      style: TextStyle(
        color: overdue ? Colors.red : const Color(0xFF66BB6A),
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Leaderboard ──

class _LeaderboardTab extends ConsumerWidget {
  const _LeaderboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);
    final me = ref.watch(authControllerProvider).me;
    final myBranchId = me?['branch_id'] as String?;

    return leaderboardAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('โหลดไม่สำเร็จ: $err')),
      data: (entries) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(leaderboardProvider),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text('7 วันล่าสุด', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
            ),
            for (var i = 0; i < entries.length; i++)
              Card(
                color: entries[i].branchId == myBranchId ? const Color(0xFFEC1968).withAlpha(20) : null,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: i == 0 ? const Color(0xFFFFA726) : Colors.grey.withAlpha(60),
                    child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  title: Text(entries[i].branchName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('เยี่ยม ${entries[i].prospectsVisited} ร้าน · ติดต่อ Lead ${entries[i].leadsContacted} ราย'),
                  trailing: Text('${entries[i].score} คะแนน', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
