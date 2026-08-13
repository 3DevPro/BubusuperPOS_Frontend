import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

String formatBaht(Decimal amount) {
  final formatter = NumberFormat('#,##0.00', 'en_US');
  return '฿${formatter.format(amount.toDouble())}';
}

String formatPoints(int points) {
  final formatter = NumberFormat('#,##0', 'en_US');
  return formatter.format(points);
}

String formatThaiDateTime(DateTime dt) {
  final local = dt.toLocal();
  final formatter = DateFormat('d MMM y HH:mm', 'th');
  final buddhistYear = local.year + 543;
  return formatter.format(local).replaceFirst('${local.year}', '$buddhistYear');
}

String formatThaiDate(DateTime dt) {
  final local = dt.toLocal();
  final formatter = DateFormat('d MMM y', 'th');
  final buddhistYear = local.year + 543;
  return formatter.format(local).replaceFirst('${local.year}', '$buddhistYear');
}
