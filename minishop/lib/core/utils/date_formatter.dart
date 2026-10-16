import 'package:intl/intl.dart';

final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

String formatDateTime(DateTime dt) => _dateTimeFormat.format(dt);
