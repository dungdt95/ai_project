import 'package:intl/intl.dart';

final _vndFormat = NumberFormat.decimalPattern('vi_VN');

String formatVnd(int amount) => '${_vndFormat.format(amount)}đ';
