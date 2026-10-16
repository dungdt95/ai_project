import 'package:flutter/material.dart';

class MonthYearPicker extends StatefulWidget {
  final DateTime initialDate;
  final int firstYear;
  final int? lastYear; // null → DateTime.now().year + 20

  const MonthYearPicker({
    super.key,
    required this.initialDate,
    this.firstYear = 1950,
    this.lastYear,
  });

  @override
  State<MonthYearPicker> createState() => _MonthYearPickerState();
}

class _MonthYearPickerState extends State<MonthYearPicker> {
  late int _year;
  late int _month;
  late int _lastYear;
  late ScrollController _yearCtrl;

  @override
  void initState() {
    super.initState();
    _year = widget.initialDate.year;
    _month = widget.initialDate.month;
    _lastYear = widget.lastYear ?? DateTime.now().year + 20;
    // Auto scroll tới năm hiện chọn
    final offset = ((_year - widget.firstYear) * 72.0) - 120;
    _yearCtrl = ScrollController(initialScrollOffset: offset.clamp(0.0, double.infinity));
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      title: const Text('Chọn tháng / năm'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Year header với arrow ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _year > widget.firstYear
                      ? () => setState(() => _year--)
                      : null,
                ),
                Text(
                  '$_year',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _year < _lastYear
                      ? () => setState(() => _year++)
                      : null,
                ),
              ],
            ),

            // ── Year quick chips ──
            SizedBox(
              height: 40,
              child: ListView.builder(
                controller: _yearCtrl,
                scrollDirection: Axis.horizontal,
                itemCount: _lastYear - widget.firstYear + 1,
                itemBuilder: (_, i) {
                  final y = widget.firstYear + i;
                  final isSelected = y == _year;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Text('$y'),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _year = y),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── Month grid ──
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: 12,
              itemBuilder: (_, i) {
                final m = i + 1;
                final isSelected = m == _month;
                return InkWell(
                  onTap: () => setState(() => _month = m),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? color : color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? color : Colors.transparent,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Th $m',
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : color,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            final now = DateTime.now();
            Navigator.pop(context, DateTime(now.year, now.month));
          },
          child: const Text('Hôm nay'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, DateTime(_year, _month)),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
