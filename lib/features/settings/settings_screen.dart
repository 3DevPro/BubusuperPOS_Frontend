import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import '../notifications/notification_providers.dart';
import '../notifications/notification_repository.dart';
import 'settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _promptpayController = TextEditingController();
  final _vatRateController = TextEditingController();
  bool _loadedInitialValue = false;
  bool _submitting = false;
  String? _error;
  String? _successMessage;

  bool _vatEnabled = false;
  bool _priceIncludesTax = true;
  bool _vatSubmitting = false;
  String? _vatError;
  String? _vatSuccessMessage;

  final _bahtPerPointController = TextEditingController();
  final _pointValueController = TextEditingController();
  bool _loyaltyEnabled = false;
  bool _loyaltySubmitting = false;
  String? _loyaltyError;
  String? _loyaltySuccessMessage;

  final _taxIdController = TextEditingController();
  final _addressController = TextEditingController();
  final _branchCodeController = TextEditingController();
  final _receiptFooterController = TextEditingController();
  bool _taxInvoiceSubmitting = false;
  String? _taxInvoiceError;
  String? _taxInvoiceSuccessMessage;

  @override
  void dispose() {
    _promptpayController.dispose();
    _vatRateController.dispose();
    _bahtPerPointController.dispose();
    _pointValueController.dispose();
    _taxIdController.dispose();
    _addressController.dispose();
    _branchCodeController.dispose();
    _receiptFooterController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _submitting = true;
      _error = null;
      _successMessage = null;
    });
    try {
      final text = _promptpayController.text.trim();
      await ref.read(tenantRepositoryProvider).updatePromptPayId(text.isEmpty ? null : text);
      ref.invalidate(tenantSettingsProvider);
      if (mounted) setState(() => _successMessage = 'บันทึกแล้ว');
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _error = (data is Map && data['detail'] != null)
            ? data['detail'].toString()
            : 'บันทึกไม่สำเร็จ ตรวจสอบเลขพร้อมเพย์อีกครั้ง';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _saveVat() async {
    setState(() {
      _vatSubmitting = true;
      _vatError = null;
      _vatSuccessMessage = null;
    });
    try {
      final rate = Decimal.tryParse(_vatRateController.text.trim());
      if (_vatEnabled && (rate == null || rate <= Decimal.zero || rate > Decimal.fromInt(100))) {
        setState(() => _vatError = 'อัตราภาษีต้องอยู่ระหว่าง 0-100');
        return;
      }
      await ref
          .read(tenantRepositoryProvider)
          .updateVatSettings(
            vatEnabled: _vatEnabled,
            vatRate: rate ?? Decimal.fromInt(7),
            priceIncludesTax: _priceIncludesTax,
          );
      ref.invalidate(tenantSettingsProvider);
      if (mounted) setState(() => _vatSuccessMessage = 'บันทึกแล้ว');
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _vatError = (data is Map && data['detail'] != null)
            ? data['detail'].toString()
            : 'บันทึกไม่สำเร็จ ตรวจสอบอัตราภาษีอีกครั้ง';
      });
    } finally {
      if (mounted) setState(() => _vatSubmitting = false);
    }
  }

  Future<void> _saveLoyalty() async {
    setState(() {
      _loyaltySubmitting = true;
      _loyaltyError = null;
      _loyaltySuccessMessage = null;
    });
    try {
      final bahtPerPoint = Decimal.tryParse(_bahtPerPointController.text.trim());
      final pointValue = Decimal.tryParse(_pointValueController.text.trim());
      if (_loyaltyEnabled &&
          (bahtPerPoint == null || bahtPerPoint <= Decimal.zero || pointValue == null || pointValue <= Decimal.zero)) {
        setState(() => _loyaltyError = 'กรอกอัตราแต้มและมูลค่าไถ่แต้มให้ถูกต้อง (มากกว่า 0)');
        return;
      }
      await ref
          .read(tenantRepositoryProvider)
          .updateLoyaltySettings(
            loyaltyEnabled: _loyaltyEnabled,
            bahtPerPoint: bahtPerPoint ?? Decimal.fromInt(25),
            pointValueBaht: pointValue ?? Decimal.one,
          );
      ref.invalidate(tenantSettingsProvider);
      if (mounted) setState(() => _loyaltySuccessMessage = 'บันทึกแล้ว');
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _loyaltyError = (data is Map && data['detail'] != null)
            ? data['detail'].toString()
            : 'บันทึกไม่สำเร็จ ตรวจสอบตัวเลขอีกครั้ง';
      });
    } finally {
      if (mounted) setState(() => _loyaltySubmitting = false);
    }
  }

  Future<void> _saveTaxInvoice() async {
    setState(() {
      _taxInvoiceSubmitting = true;
      _taxInvoiceError = null;
      _taxInvoiceSuccessMessage = null;
    });
    try {
      final taxId = _taxIdController.text.trim();
      await ref
          .read(tenantRepositoryProvider)
          .updateTaxInvoiceSettings(
            taxId: taxId.isEmpty ? null : taxId,
            address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
            branchCode: _branchCodeController.text.trim().isEmpty ? null : _branchCodeController.text.trim(),
            receiptFooter: _receiptFooterController.text.trim().isEmpty
                ? null
                : _receiptFooterController.text.trim(),
          );
      ref.invalidate(tenantSettingsProvider);
      if (mounted) setState(() => _taxInvoiceSuccessMessage = 'บันทึกแล้ว');
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _taxInvoiceError = (data is Map && data['detail'] != null)
            ? data['detail'].toString()
            : 'บันทึกไม่สำเร็จ ตรวจสอบเลขประจำตัวผู้เสียภาษีอีกครั้ง';
      });
    } finally {
      if (mounted) setState(() => _taxInvoiceSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(authControllerProvider).me?['role'] == 'owner';
    final settingsAsync = ref.watch(tenantSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่าร้าน')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('โหลดการตั้งค่าไม่สำเร็จ: $err')),
        data: (settings) {
          if (!_loadedInitialValue) {
            _promptpayController.text = settings.promptpayId ?? '';
            _vatRateController.text = settings.vatRate.toString();
            _vatEnabled = settings.vatEnabled;
            _priceIncludesTax = settings.priceIncludesTax;
            _bahtPerPointController.text = settings.bahtPerPoint.toString();
            _pointValueController.text = settings.pointValueBaht.toString();
            _loyaltyEnabled = settings.loyaltyEnabled;
            _taxIdController.text = settings.taxId ?? '';
            _addressController.text = settings.address ?? '';
            _branchCodeController.text = settings.branchCode ?? '';
            _receiptFooterController.text = settings.receiptFooter ?? '';
            _loadedInitialValue = true;
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(settings.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              const Text('เลขพร้อมเพย์ (PromptPay)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'เบอร์โทร 10 หลัก หรือเลขบัตรประชาชน 13 หลัก — ใช้สร้าง QR รับเงินตอนลูกค้าเลือก "โอน/QR"',
                style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _promptpayController,
                enabled: isOwner,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'เบอร์โทร หรือ เลขบัตรประชาชน',
                  border: OutlineInputBorder(),
                ),
              ),
              if (!isOwner) ...[
                const SizedBox(height: 8),
                const Text('เฉพาะเจ้าของร้านเท่านั้นที่แก้ไขได้', style: TextStyle(color: Colors.orange)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              if (_successMessage != null) ...[
                const SizedBox(height: 12),
                Text(_successMessage!, style: const TextStyle(color: Colors.green)),
              ],
              if (isOwner) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submitting ? null : _save,
                  child: _submitting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('บันทึก'),
                ),
              ],
              const Divider(height: 40),
              const Text('ภาษีมูลค่าเพิ่ม (VAT)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('เปิดใช้งาน VAT'),
                value: _vatEnabled,
                onChanged: isOwner ? (v) => setState(() => _vatEnabled = v) : null,
              ),
              TextField(
                controller: _vatRateController,
                enabled: isOwner && _vatEnabled,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'อัตราภาษี (%)', suffixText: '%', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              RadioGroup<bool>(
                groupValue: _priceIncludesTax,
                onChanged: (v) {
                  if (isOwner && _vatEnabled) setState(() => _priceIncludesTax = v!);
                },
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('ราคารวมภาษีแล้ว'),
                      value: true,
                      enabled: isOwner && _vatEnabled,
                    ),
                    RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('ราคายังไม่รวมภาษี (บวกเพิ่มตอนคิดเงิน)'),
                      value: false,
                      enabled: isOwner && _vatEnabled,
                    ),
                  ],
                ),
              ),
              if (_vatError != null) ...[
                const SizedBox(height: 12),
                Text(_vatError!, style: const TextStyle(color: Colors.red)),
              ],
              if (_vatSuccessMessage != null) ...[
                const SizedBox(height: 12),
                Text(_vatSuccessMessage!, style: const TextStyle(color: Colors.green)),
              ],
              if (isOwner) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _vatSubmitting ? null : _saveVat,
                  child: _vatSubmitting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('บันทึกภาษี'),
                ),
              ],
              const Divider(height: 40),
              const Text('แต้มสะสม (Loyalty)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'ลูกค้าสะสมแต้มจากยอดซื้อ แล้วนำแต้มมาแลกเป็นส่วนลดตอนคิดเงินได้',
                style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('เปิดใช้งานแต้มสะสม'),
                value: _loyaltyEnabled,
                onChanged: isOwner ? (v) => setState(() => _loyaltyEnabled = v) : null,
              ),
              TextField(
                controller: _bahtPerPointController,
                enabled: isOwner && _loyaltyEnabled,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'ซื้อกี่บาทได้ 1 แต้ม',
                  prefixText: '฿ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pointValueController,
                enabled: isOwner && _loyaltyEnabled,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '1 แต้มแลกส่วนลดกี่บาท',
                  prefixText: '฿ ',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_loyaltyError != null) ...[
                const SizedBox(height: 12),
                Text(_loyaltyError!, style: const TextStyle(color: Colors.red)),
              ],
              if (_loyaltySuccessMessage != null) ...[
                const SizedBox(height: 12),
                Text(_loyaltySuccessMessage!, style: const TextStyle(color: Colors.green)),
              ],
              if (isOwner) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loyaltySubmitting ? null : _saveLoyalty,
                  child: _loyaltySubmitting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('บันทึกแต้มสะสม'),
                ),
              ],
              const Divider(height: 40),
              const Text('ข้อมูลใบกำกับภาษี', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'กรอกครบแล้วใบเสร็จจะพิมพ์เป็น "ใบกำกับภาษีอย่างย่อ" อัตโนมัติเมื่อเปิดใช้งาน VAT',
                style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _taxIdController,
                enabled: isOwner,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'เลขประจำตัวผู้เสียภาษี (13 หลัก)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                enabled: isOwner,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'ที่อยู่ร้าน', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _branchCodeController,
                enabled: isOwner,
                decoration: const InputDecoration(
                  labelText: 'เลขที่สาขา (00000 = สำนักงานใหญ่)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _receiptFooterController,
                enabled: isOwner,
                decoration: const InputDecoration(labelText: 'ข้อความท้ายใบเสร็จ', border: OutlineInputBorder()),
              ),
              if (_taxInvoiceError != null) ...[
                const SizedBox(height: 12),
                Text(_taxInvoiceError!, style: const TextStyle(color: Colors.red)),
              ],
              if (_taxInvoiceSuccessMessage != null) ...[
                const SizedBox(height: 12),
                Text(_taxInvoiceSuccessMessage!, style: const TextStyle(color: Colors.green)),
              ],
              if (isOwner) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _taxInvoiceSubmitting ? null : _saveTaxInvoice,
                  child: _taxInvoiceSubmitting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('บันทึกใบกำกับภาษี'),
                ),
              ],
              const Divider(height: 40),
              _NotificationSettingsSection(isOwner: isOwner),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationSettingsSection extends ConsumerStatefulWidget {
  const _NotificationSettingsSection({required this.isOwner});
  final bool isOwner;

  @override
  ConsumerState<_NotificationSettingsSection> createState() => _NotificationSettingsSectionState();
}

class _NotificationSettingsSectionState extends ConsumerState<_NotificationSettingsSection> {
  bool _loaded = false;
  bool _lowStockEnabled = true;
  TimeOfDay _lowStockTime = const TimeOfDay(hour: 9, minute: 0);
  bool _dailySummaryEnabled = true;
  TimeOfDay _dailySummaryTime = const TimeOfDay(hour: 20, minute: 0);
  bool _submitting = false;
  String? _error;
  String? _successMessage;

  static TimeOfDay _parseTime(String hhmmss) {
    final parts = hhmmss.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickTime(TimeOfDay initial, ValueChanged<TimeOfDay> onPicked) async {
    if (!widget.isOwner) return;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) setState(() => onPicked(picked));
  }

  Future<void> _save() async {
    setState(() {
      _submitting = true;
      _error = null;
      _successMessage = null;
    });
    try {
      await ref
          .read(notificationRepositoryProvider)
          .updateSettings({
            'low_stock_enabled': _lowStockEnabled,
            'low_stock_time': _formatTime(_lowStockTime),
            'daily_summary_enabled': _dailySummaryEnabled,
            'daily_summary_time': _formatTime(_dailySummaryTime),
          });
      ref.invalidate(notificationSettingsProvider);
      if (mounted) setState(() => _successMessage = 'บันทึกแล้ว');
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
    final settingsAsync = ref.watch(notificationSettingsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Text('โหลดการแจ้งเตือนไม่สำเร็จ: $err'),
      data: (NotificationSettingsDto settings) {
        if (!_loaded) {
          _lowStockEnabled = settings.lowStockEnabled;
          _lowStockTime = _parseTime(settings.lowStockTime);
          _dailySummaryEnabled = settings.dailySummaryEnabled;
          _dailySummaryTime = _parseTime(settings.dailySummaryTime);
          _loaded = true;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('การแจ้งเตือน', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'แจ้งเตือนสต๊อกใกล้หมดและสรุปยอดขายประจำวัน ผ่านกล่องข้อความในแอป',
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('แจ้งเตือนสต๊อกใกล้หมด'),
              value: _lowStockEnabled,
              onChanged: widget.isOwner ? (v) => setState(() => _lowStockEnabled = v) : null,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('เวลาแจ้งเตือนสต๊อก'),
              trailing: Text(_lowStockTime.format(context)),
              enabled: widget.isOwner && _lowStockEnabled,
              onTap: () => _pickTime(_lowStockTime, (t) => _lowStockTime = t),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('สรุปยอดขายประจำวัน'),
              value: _dailySummaryEnabled,
              onChanged: widget.isOwner ? (v) => setState(() => _dailySummaryEnabled = v) : null,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('เวลาสรุปยอดขาย'),
              trailing: Text(_dailySummaryTime.format(context)),
              enabled: widget.isOwner && _dailySummaryEnabled,
              onTap: () => _pickTime(_dailySummaryTime, (t) => _dailySummaryTime = t),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_successMessage != null) ...[
              const SizedBox(height: 12),
              Text(_successMessage!, style: const TextStyle(color: Colors.green)),
            ],
            if (widget.isOwner) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting ? null : _save,
                child: _submitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('บันทึกการแจ้งเตือน'),
              ),
            ],
          ],
        );
      },
    );
  }
}
