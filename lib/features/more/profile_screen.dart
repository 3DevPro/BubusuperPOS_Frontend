import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/formatters.dart';
import '../auth/auth_provider.dart';
import '../settings/settings_providers.dart';
import '../turbo/turbo_providers.dart';
import '../turbo/turbo_repository.dart';

String _cycleLabel(String cycle) => switch (cycle) { 'daily' => 'วัน', 'weekly' => 'สัปดาห์', _ => 'เดือน' };

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider).me;
    final role = me?['role'] as String?;
    final canViewFinancials = role == 'owner' || role == 'manager';
    final tenantAsync = ref.watch(tenantSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('โปรไฟล์ของฉัน')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (me != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(me['name'] as String),
                subtitle: Text('บทบาท: ${me['role']}'),
              ),
            ),
          const SizedBox(height: 16),
          const Text('ข้อมูลร้าน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          tenantAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Text('โหลดข้อมูลร้านไม่สำเร็จ: $err'),
            data: (tenant) => Card(
              child: ListTile(
                leading: const Icon(Icons.storefront),
                title: Text(tenant.name),
                subtitle: Text(
                  tenant.businessType == null ? 'ยังไม่ระบุประเภทร้าน' : 'ประเภทร้าน: ${tenant.businessType}',
                ),
                trailing: TextButton(
                  onPressed: () => context.push('/settings'),
                  child: const Text('แก้ไข'),
                ),
              ),
            ),
          ),
          if (canViewFinancials) ...[
            const SizedBox(height: 16),
            const Text('ประกัน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _InsuranceSummary(),
            const SizedBox(height: 16),
            const Text('สินเชื่อ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _LoanSummary(),
          ],
        ],
      ),
    );
  }
}

class _InsuranceSummary extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(insuranceProductsProvider);
    final policiesAsync = ref.watch(insurancePoliciesProvider);

    return productsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Text('โหลดข้อมูลประกันไม่สำเร็จ: $err'),
      data: (products) => policiesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Text('โหลดข้อมูลประกันไม่สำเร็จ: $err'),
        data: (policies) {
          final active = policies.where((p) => p.status == 'active').toList();
          if (active.isEmpty) {
            return _CtaCard(
              icon: Icons.shield_outlined,
              message: 'ยังไม่มีประกัน',
              buttonLabel: 'ซื้อประกันคุ้มครอง',
              onPressed: () => context.push('/turbo/insurance'),
            );
          }
          return Column(
            children: [
              for (final policy in active)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.shield, color: Color(0xFF66BB6A)),
                    title: Text(_productNameFor(products, policy.productId)),
                    subtitle: Text(
                      'เบี้ย ${formatBaht(policy.premiumAmount)}/${_cycleLabel(policy.premiumCycle)} · '
                      'คุ้มครอง ${formatBaht(policy.dailyBenefit)}/วัน',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _productNameFor(List<InsuranceProductDto> products, String productId) {
    for (final product in products) {
      if (product.id == productId) return product.name;
    }
    return 'ประกัน';
  }
}

class _LoanSummary extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(loanAccountSummaryProvider);

    return summaryAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Text('โหลดข้อมูลสินเชื่อไม่สำเร็จ: $err'),
      data: (summary) {
        if (summary == null) {
          return _CtaCard(
            icon: Icons.account_balance_outlined,
            message: 'ยังไม่มีสินเชื่อ',
            buttonLabel: 'ขอสินเชื่อ',
            onPressed: () => context.push('/turbo/loans/apply'),
          );
        }
        return Card(
          child: ListTile(
            leading: Icon(
              Icons.account_balance,
              color: summary.hasOverdue ? const Color(0xFFEF5350) : const Color(0xFF66BB6A),
            ),
            title: Text('บัญชี ${summary.account.accountNumber}'),
            subtitle: Text(
              summary.hasOverdue
                  ? 'ค้างชำระ ${summary.overdueCount} งวด รวม ${formatBaht(summary.overdueAmount)} '
                        '(ช้าสุด ${summary.maxDaysOverdue} วัน)'
                  : 'เงินต้น ${formatBaht(summary.account.principal)} · '
                        'ยอดคงค้าง ${formatBaht(summary.outstandingBalance)}',
            ),
            onTap: () => context.push('/turbo/loans/account'),
          ),
        );
      },
    );
  }
}

class _CtaCard extends StatelessWidget {
  const _CtaCard({
    required this.icon,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.outline),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
            FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}
