import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/formatters.dart';
import '../customers/customer_picker_sheet.dart';
import '../customers/customer_repository.dart';
import 'cart_notifier.dart';

/// Shown as a modal bottom sheet on phones, and as a persistent side panel
/// on wide/web layouts — same widget, same cart state either way.
class CartPanel extends ConsumerWidget {
  const CartPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    return Column(
      children: [
        Expanded(
          child: cart.isEmpty
              ? const Center(child: Text('ยังไม่มีสินค้าในตะกร้า'))
              : ListView.builder(
                  itemCount: cart.lines.length,
                  itemBuilder: (context, index) {
                    final line = cart.lines[index];
                    final overStock = line.product.trackStock && line.qty > line.product.stockQty;
                    return ListTile(
                      title: Text(line.product.name),
                      subtitle: Text(
                        '${formatBaht(line.product.sellPrice)} x ${line.qty}'
                        '${line.discount > Decimal.zero ? " • ลด ${formatBaht(line.discount)}" : ""}'
                        '${overStock ? " • สต็อกเหลือ ${line.product.stockQty}" : ""}',
                        style: overStock ? const TextStyle(color: Colors.orange) : null,
                      ),
                      leading: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => notifier.setQty(line.product.id, line.qty - 1),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.sell_outlined,
                              color: line.discount > Decimal.zero ? Theme.of(context).colorScheme.primary : null,
                            ),
                            tooltip: 'ส่วนลดรายชิ้น',
                            onPressed: () async {
                              final discount = await showDialog<Decimal>(
                                context: context,
                                builder: (context) => _ItemDiscountDialog(line: line),
                              );
                              if (discount == null) return;
                              notifier.setItemDiscount(line.product.id, discount);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => notifier.setQty(line.product.id, line.qty + 1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => notifier.removeProduct(line.product.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [const Text('รวม'), Text(formatBaht(cart.subtotal))],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ส่วนลด'),
                  TextButton(
                    onPressed: () async {
                      final result = await showDialog<String>(
                        context: context,
                        builder: (context) => _DiscountDialog(initial: cart.discount),
                      );
                      if (result == null) return;
                      final parsed = Decimal.tryParse(result) ?? Decimal.zero;
                      notifier.setDiscount(parsed < Decimal.zero ? Decimal.zero : parsed);
                    },
                    child: Text(cart.discount == Decimal.zero ? 'ใส่ส่วนลด' : '-${formatBaht(cart.discount)}'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ลูกค้า'),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () async {
                          final picked = await showModalBottomSheet<CustomerDto>(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) => SizedBox(
                              height: MediaQuery.of(context).size.height * 0.75,
                              child: const CustomerPickerSheet(),
                            ),
                          );
                          if (picked != null) notifier.setCustomer(picked);
                        },
                        child: Text(cart.customer?.name ?? 'เลือกลูกค้า'),
                      ),
                      if (cart.customer != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'เอาลูกค้าออก',
                          onPressed: () => notifier.setCustomer(null),
                        ),
                    ],
                  ),
                ],
              ),
              if (cart.customer != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('แต้มสะสม (มี ${formatPoints(cart.customer!.pointsBalance)} แต้ม)'),
                    TextButton(
                      onPressed: cart.customer!.pointsBalance <= 0
                          ? null
                          : () async {
                              final result = await showDialog<int>(
                                context: context,
                                builder: (context) => _RedeemPointsDialog(
                                  initial: cart.pointsToRedeem,
                                  maxPoints: cart.customer!.pointsBalance,
                                ),
                              );
                              if (result == null) return;
                              notifier.setPointsToRedeem(result);
                            },
                      child: Text(cart.pointsToRedeem == 0 ? 'ใช้แต้ม' : 'ใช้ ${formatPoints(cart.pointsToRedeem)} แต้ม'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ยอดสุทธิ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(formatBaht(cart.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: cart.isEmpty ? null : () => context.push('/checkout'),
                  child: const Text('ชำระเงิน'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiscountDialog extends StatefulWidget {
  const _DiscountDialog({required this.initial});
  final Decimal initial;

  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<_DiscountDialog> {
  late final _controller = TextEditingController(
    text: widget.initial == Decimal.zero ? '' : widget.initial.toString(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ส่วนลดท้ายบิล (บาท)'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(prefixText: '฿ '),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim().isEmpty ? '0' : _controller.text.trim()),
          child: const Text('ตกลง'),
        ),
      ],
    );
  }
}

class _RedeemPointsDialog extends StatefulWidget {
  const _RedeemPointsDialog({required this.initial, required this.maxPoints});
  final int initial;
  final int maxPoints;

  @override
  State<_RedeemPointsDialog> createState() => _RedeemPointsDialogState();
}

class _RedeemPointsDialogState extends State<_RedeemPointsDialog> {
  late final _controller = TextEditingController(text: widget.initial == 0 ? '' : '${widget.initial}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ใช้แต้มสะสม'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(helperText: 'สูงสุด ${formatPoints(widget.maxPoints)} แต้ม'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, 0), child: const Text('ไม่ใช้แต้ม')),
        FilledButton(
          onPressed: () {
            final entered = int.tryParse(_controller.text.trim()) ?? 0;
            final capped = entered.clamp(0, widget.maxPoints);
            Navigator.pop(context, capped);
          },
          child: const Text('ตกลง'),
        ),
      ],
    );
  }
}

enum _DiscountUnit { baht, percent }

/// ฿/% toggle: the % mode is purely a client-side convenience — whatever the
/// cashier enters is converted to a flat baht amount before it ever reaches
/// the cart state or the API, so the wire format never changes.
class _ItemDiscountDialog extends StatefulWidget {
  const _ItemDiscountDialog({required this.line});
  final CartLine line;

  @override
  State<_ItemDiscountDialog> createState() => _ItemDiscountDialogState();
}

class _ItemDiscountDialogState extends State<_ItemDiscountDialog> {
  late _DiscountUnit _unit = _DiscountUnit.baht;
  late final _controller = TextEditingController(
    text: widget.line.discount == Decimal.zero ? '' : widget.line.discount.toString(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('ส่วนลด: ${widget.line.product.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<_DiscountUnit>(
            segments: const [
              ButtonSegment(value: _DiscountUnit.baht, label: Text('฿')),
              ButtonSegment(value: _DiscountUnit.percent, label: Text('%')),
            ],
            selected: {_unit},
            onSelectionChanged: (s) => setState(() => _unit = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(prefixText: _unit == _DiscountUnit.baht ? '฿ ' : '% '),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        FilledButton(
          onPressed: () {
            final entered = Decimal.tryParse(_controller.text.trim());
            if (entered == null || entered <= Decimal.zero) {
              Navigator.pop(context, Decimal.zero);
              return;
            }
            final discount = _unit == _DiscountUnit.baht
                ? entered
                : (widget.line.gross * entered / Decimal.fromInt(100)).toDecimal(scaleOnInfinitePrecision: 2);
            final capped = discount > widget.line.gross ? widget.line.gross : discount;
            Navigator.pop(context, capped);
          },
          child: const Text('ตกลง'),
        ),
      ],
    );
  }
}
