import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_provider.dart';

/// Signup for a Ngernturbo Branch Champion — a separate account type from a
/// shop owner (see Backend's UserRole.branch_champion), but /auth/login is
/// shared, so only signup needs its own screen. A second Champion signing up
/// with a branch code that already exists just joins that branch.
class BranchSignupScreen extends ConsumerStatefulWidget {
  const BranchSignupScreen({super.key});

  @override
  ConsumerState<BranchSignupScreen> createState() => _BranchSignupScreenState();
}

class _BranchSignupScreenState extends ConsumerState<BranchSignupScreen> {
  final _branchCodeController = TextEditingController();
  final _branchNameController = TextEditingController();
  final _provinceController = TextEditingController();
  final _staffNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _branchCodeController.dispose();
    _branchNameController.dispose();
    _provinceController.dispose();
    _staffNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    await ref.read(authControllerProvider.notifier).branchSignup(
      branchCode: _branchCodeController.text.trim(),
      branchName: _branchNameController.text.trim(),
      province: _provinceController.text.trim(),
      staffName: _staffNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.go('/login'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('สมัครพนักงานสาขา', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'สำหรับพนักงานเงินเทอร์โบที่เดินออกไปหาผู้ค้าในพื้นที่',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _branchCodeController,
                    decoration: const InputDecoration(labelText: 'รหัสสาขา (เช่น BKK-001)'),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _branchNameController,
                    decoration: const InputDecoration(labelText: 'ชื่อสาขา'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _provinceController,
                    decoration: const InputDecoration(labelText: 'จังหวัด'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _staffNameController,
                    decoration: const InputDecoration(labelText: 'ชื่อพนักงาน'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'อีเมล'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'รหัสผ่าน (อย่างน้อย 8 ตัว)',
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    obscureText: _obscurePassword,
                  ),
                  const SizedBox(height: 16),
                  if (authState.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(authState.error!, style: const TextStyle(color: Colors.red)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('สมัครใช้งาน'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
