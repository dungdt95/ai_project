import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/storage.dart';

class ProgressReportTab extends StatelessWidget {
  const ProgressReportTab({
    super.key,
    required this.profileId,
    required this.storage,
  });

  final String? profileId;
  final Storage storage;

  @override
  Widget build(BuildContext context) {
    if (profileId == null) {
      return const Center(child: Text("Please select a child profile first."));
    }

    final pid = profileId!;
    final now = DateTime.now();

    // Tính thời gian chơi 7 ngày gần nhất
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final playMinutes = days.map((d) => (storage.secondsPlayed(pid, d) / 60).round()).toList();
    final maxMinutes = playMinutes.fold<int>(20, (prev, val) => val > prev ? val : prev);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Card biểu đồ 7 ngày
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bar_chart_rounded, color: AppColors.orange, size: 28),
                    SizedBox(width: 8),
                    Text(
                      "Thời gian học 7 ngày qua (phút)",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 140,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (i) {
                      final m = playMinutes[i];
                      final d = days[i];
                      final heightRatio = maxMinutes > 0 ? (m / maxMinutes) : 0.0;
                      final isToday = i == 6;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('$m', style: TextStyle(fontSize: 12, fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
                          const SizedBox(height: 4),
                          Container(
                            width: 24,
                            height: (heightRatio * 80).clamp(4.0, 80.0),
                            decoration: BoxDecoration(
                              color: isToday ? AppColors.orange : AppColors.teal,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "${d.day}/${d.month}",
                            style: TextStyle(fontSize: 11, color: isToday ? AppColors.orange : Colors.grey.shade600, fontWeight: isToday ? FontWeight.bold : FontWeight.normal),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Thẻ ghi chú thuật toán ghi nhớ Leitner
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology_alt_rounded, color: AppColors.teal, size: 28),
                    SizedBox(width: 8),
                    Text(
                      "Phương pháp ghi nhớ ngắt quãng (Leitner)",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  "App tự động phân loại từ vựng bé đã học theo 5 cấp độ ghi nhớ. Các từ bé nhớ chắc sẽ được lặp lại sau 3, 7 hoặc 14 ngày; những từ bé quên sẽ tự động được đưa vào các trò chơi tiếp theo để ôn luyện.",
                  style: TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
