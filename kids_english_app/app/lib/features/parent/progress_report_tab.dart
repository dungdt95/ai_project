import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/media.dart';
import '../../data/review_planner.dart';
import '../../data/storage.dart';

class ProgressReportTab extends ConsumerWidget {
  const ProgressReportTab({
    super.key,
    required this.profileId,
    required this.storage,
  });

  final String? profileId;
  final Storage storage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

        // Kho từ vựng của bé
        const _VocabularySection(),

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

// ---------------- Kho từ vựng của bé ----------------
class _VocabularySection extends ConsumerWidget {
  const _VocabularySection();

  void _reviewNow(BuildContext context) {
    // Về bản đồ rồi mới mở phiên ôn: giữ router trước khi go() vì màn phụ huynh sẽ bị gỡ khỏi cây.
    final router = GoRouter.of(context);
    router.go('/home');
    WidgetsBinding.instance.addPostFrameCallback((_) => router.push('/review?mode=weak'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(reviewSummaryProvider);
    final canStart = s.canReview && s.dueOrWeakWords.isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.menu_book_rounded, color: AppColors.teal, size: 28),
                SizedBox(width: 8),
                Text("Kho từ vựng của bé", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatTile(key: const Key('stat_learned'), emoji: '📚', label: 'Đã học', value: s.learnedWords.length),
                const SizedBox(width: 10),
                _StatTile(key: const Key('stat_mastered'), emoji: '🟢', label: 'Đã thuộc', value: s.masteredWords.length),
                const SizedBox(width: 10),
                _StatTile(key: const Key('stat_due'), emoji: '🔴', label: 'Cần ôn tập', value: s.dueOrWeakWords.length),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('review_now_button'),
                onPressed: canStart ? () => _reviewNow(context) : null,
                icon: const Icon(Icons.star_rounded),
                label: const Text("Cho bé ôn ngay nhóm từ cần luyện", style: TextStyle(fontSize: 16)),
              ),
            ),
            if (s.learnedWords.isNotEmpty && !s.canReview)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  "Bé cần học ít nhất 4 từ để mở chế độ ôn tập.",
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ),
            const SizedBox(height: 8),
            if (s.learnedWords.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  "Bé chưa học từ nào. Hãy cùng bé hoàn thành bài học đầu tiên nhé!",
                  style: TextStyle(fontSize: 15, color: Colors.black54),
                ),
              )
            else ...[
              _WordGroup(title: '🔴 Cần ôn tập', words: s.dueOrWeakWords, initiallyExpanded: true),
              _WordGroup(title: '🟡 Đang củng cố', words: s.learningWords),
              _WordGroup(title: '🟢 Đã thuộc', words: s.masteredWords),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({super.key, required this.emoji, required this.label, required this.value});
  final String emoji;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: AppColors.sky, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            Text('$value', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _WordGroup extends ConsumerWidget {
  const _WordGroup({required this.title, required this.words, this.initiallyExpanded = false});
  final String title;
  final List<ReviewWord> words;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExpansionTile(
      key: PageStorageKey<String>(title),
      initiallyExpanded: initiallyExpanded,
      tilePadding: EdgeInsets.zero,
      title: Text('$title (${words.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      children: [
        if (words.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text("Chưa có từ nào.", style: TextStyle(color: Colors.black54)),
          ),
        for (final w in words)
          ListTile(
            key: Key('vocab_${w.id}'),
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: 40,
              height: 40,
              child: MediaImage(w.word.image, baseDir: w.baseDir, label: w.word.text),
            ),
            title: Text(w.word.text, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: (w.word.vi ?? '').isEmpty ? null : Text(w.word.vi!),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 1; i <= 5; i++)
                  Icon(i <= w.box ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 18, color: i <= w.box ? AppColors.yellow : Colors.grey.shade400),
              ],
            ),
            onTap: () => ref.read(audioProvider).playWord(w.word.audio, w.word.text, viText: w.word.vi, baseDir: w.baseDir),
          ),
      ],
    );
  }
}
