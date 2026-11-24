import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import 'parent/learn_together_tab.dart';
import 'parent/progress_report_tab.dart';
import 'parent/topic_packs_tab.dart';
import 'screen_time/screen_time_controller.dart';
import '../../app/theme.dart';
import '../../core/media.dart';
import '../../data/models.dart';

const avatarEmoji = {
  'monkey': '🐵',
  'puppy': '🐶',
  'kitten': '🐱',
  'bunny': '🐰',
  'panda': '🐼',
  'lion': '🦁',
};

class AvatarView extends StatelessWidget {
  const AvatarView(this.avatarId, {super.key, this.size = 80});
  final String avatarId;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.yellow),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: Image.asset(
        'assets/images/common/avatar_$avatarId.png',
        width: size,
        height: size,
        errorBuilder: (_, _, _) => Text(avatarEmoji[avatarId] ?? '🐵', style: TextStyle(fontSize: size * 0.55)),
      ),
    );
  }
}

// ======================= Splash =======================
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    try {
      await ref.read(topicsProvider.future);
    } catch (_) {}
    final storage = ref.read(storageProvider);
    if (storage.profiles().isEmpty) {
      final p = await ref.read(profilesProvider.notifier).add('Bé Bo', 'monkey');
      await ref.read(activeProfileIdProvider.notifier).set(p.id);
    }
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    context.go(ref.read(activeProfileProvider) != null ? '/home' : '/profiles');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sky,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🐵', style: TextStyle(fontSize: 96)),
            const SizedBox(height: 12),
            Text('Bé Vui Tiếng Anh', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

// ======================= Chọn hồ sơ =======================
class ProfileSelectScreen extends ConsumerWidget {
  const ProfileSelectScreen({super.key});

  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    final nameCtl = TextEditingController();
    var avatar = 'monkey';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Thêm hồ sơ cho bé'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Biệt danh của bé'), maxLength: 12),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final id in avatarEmoji.keys)
                  GestureDetector(
                    onTap: () => setS(() => avatar = id),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: avatar == id ? AppColors.orange : Colors.transparent, width: 4),
                      ),
                      child: AvatarView(id, size: 56),
                    ),
                  ),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
          ],
        ),
      ),
    );
    final name = nameCtl.text.trim().isEmpty ? 'Bé' : nameCtl.text.trim();
    if (ok == true) {
      final p = await ref.read(profilesProvider.notifier).add(name, avatar);
      await ref.read(activeProfileIdProvider.notifier).set(p.id);
      if (context.mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    return Scaffold(
      backgroundColor: AppColors.sky,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(24),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final p in profiles)
                _bigTile(
                  AvatarView(p.avatarId, size: 120),
                  p.nickname,
                  () async {
                    await ref.read(activeProfileIdProvider.notifier).set(p.id);
                    if (context.mounted) context.go('/home');
                  },
                ),
              _bigTile(
                const CircleAvatar(radius: 60, backgroundColor: AppColors.orange, child: Icon(Icons.add, size: 64, color: Colors.white)),
                profiles.isEmpty ? 'Tạo hồ sơ cho bé' : 'Thêm bé',
                () => _addDialog(context, ref),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _bigTile(Widget icon, String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              icon,
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      );
}

// ======================= Bản đồ (Khu của Bé) =======================
class KidHomeScreen extends ConsumerStatefulWidget {
  const KidHomeScreen({super.key});

  @override
  ConsumerState<KidHomeScreen> createState() => _KidHomeScreenState();
}

class _KidHomeScreenState extends ConsumerState<KidHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Đồng bộ ngầm Google Drive một lần mỗi phiên; không bao giờ chặn hay làm lỗi giao diện của bé.
    if (!ref.read(driveBackgroundSyncDoneProvider) && ref.read(settingsProvider).autoSyncDrive) {
      // Ghi provider ngoài vòng build (Riverpod cấm sửa provider khi cây widget đang dựng).
      Future(_backgroundSync);
    }
  }

  Future<void> _backgroundSync() async {
    if (!mounted || ref.read(driveBackgroundSyncDoneProvider)) return;
    ref.read(driveBackgroundSyncDoneProvider.notifier).mark();
    try {
      final n = await ref.read(driveSyncServiceProvider).syncInBackground();
      if (n > 0 && mounted) {
        await ref.read(settingsProvider.notifier).markDriveSynced();
        if (!mounted) return;
        ref.invalidate(topicsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🎉 Đã cập nhật $n chủ đề mới từ Google Drive!')),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(topicsProvider);
    final profile = ref.watch(activeProfileProvider);
    ref.watch(progressVersionProvider);
    final storage = ref.read(storageProvider);

    // Kiểm tra giới hạn thời gian màn hình
    final screenTime = ref.watch(screenTimeProvider);
    if (screenTime.isTimeUp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/sleep');
      });
    }

    return Scaffold(
      backgroundColor: AppColors.sky,
      body: SafeArea(
        child: Stack(children: [
          topicsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Không đọc được nội dung: $e')),
            data: (topics) => ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(80, 50, 80, 16),
              itemCount: topics.length,
              itemBuilder: (ctx, i) {
                final t = topics[i];
                final done = profile == null ? 0 : t.lessons.where((l) => storage.isLessonDone(profile.id, l.id)).length;
                return _Island(topic: t, done: done, offsetDown: i.isOdd);
              },
            ),
          ),
          Positioned(
            left: 12,
            top: 8,
            child: GestureDetector(
              onTap: () => context.go('/profiles'),
              child: Row(children: [
                AvatarView(profile?.avatarId ?? 'monkey', size: 56),
                const SizedBox(width: 8),
                Text(profile?.nickname ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
          if (screenTime.isWarning)
            Positioned(
              top: 14,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, color: Colors.white, size: 20),
                      SizedBox(width: 6),
                      Text("2 minutes left!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          // Cổng phụ huynh: nút nhỏ, phải nhấn giữ 2 giây.
          Positioned(right: 12, top: 8, child: _HoldToOpen(onOpen: () => context.push('/gate'))),
        ]),
      ),
    );
  }
}

class _HoldToOpen extends StatefulWidget {
  const _HoldToOpen({required this.onOpen});
  final VoidCallback onOpen;
  @override
  State<_HoldToOpen> createState() => _HoldToOpenState();
}

class _HoldToOpenState extends State<_HoldToOpen> {
  Timer? _t;
  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _t = Timer(const Duration(seconds: 2), widget.onOpen),
      onTapUp: (_) => _t?.cancel(),
      onTapCancel: () => _t?.cancel(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.lock_outline, size: 28, color: AppColors.ink),
      ),
    );
  }
}

class _Island extends StatelessWidget {
  const _Island({required this.topic, required this.done, required this.offsetDown});
  final Topic topic;
  final int done;
  final bool offsetDown;

  @override
  Widget build(BuildContext context) {
    final total = topic.lessons.length;
    return Padding(
      padding: EdgeInsets.only(right: 28, top: offsetDown ? 28 : 0),
      child: GestureDetector(
        onTap: () => context.push('/topic/${topic.id}'),
        child: SizedBox(
          width: 190,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 150,
                width: 150,
                child: MediaImage(topic.mapIcon, baseDir: topic.baseDir, label: topic.titleEn),
              ),
              const SizedBox(height: 6),
              Text(
                topic.titleEn,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < total; i++)
                  Icon(i < done ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.yellow, size: 24),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================= Danh sách bài của chủ đề =======================
class TopicScreen extends ConsumerWidget {
  const TopicScreen({super.key, required this.topicId});
  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(topicsProvider).value ?? const <Topic>[];
    ref.watch(progressVersionProvider);
    final topic = topics.where((t) => t.id == topicId).firstOrNull;
    final profile = ref.watch(activeProfileProvider);
    final storage = ref.read(storageProvider);
    if (topic == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    var unlocked = true;
    final tiles = <Widget>[];
    for (final l in topic.lessons) {
      final done = profile != null && storage.isLessonDone(profile.id, l.id);
      final open = unlocked;
      tiles.add(_LessonTile(
        number: l.order,
        done: done,
        locked: !open,
        onTap: () => context.push('/lesson/${topic.id}/${l.id}'),
      ));
      unlocked = done; // bài kế tiếp chỉ mở khi bài này xong
    }

    return Scaffold(
      backgroundColor: AppColors.sky,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(iconSize: 36, icon: const Icon(Icons.home_rounded), onPressed: () => context.pop()),
        title: Text(topic.titleEn, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        actions: [
          if (topic.song != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.pink,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: () => context.push('/song/${topic.id}'),
                icon: const Icon(Icons.music_note_rounded, size: 28),
                label: const Text("Sing Song", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(24),
          child: Row(children: tiles),
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.number, required this.done, required this.locked, required this.onTap});
  final int number;
  final bool done;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: locked ? null : onTap,
        child: Container(
          width: 128,
          height: 128,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: locked ? Colors.grey.shade300 : (done ? AppColors.teal : AppColors.orange),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
          ),
          alignment: Alignment.center,
          child: locked
              ? const Icon(Icons.lock_rounded, size: 52, color: Colors.white)
              : Text('$number', style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
      ),
    );
  }
}

// (LessonPlayerScreen đã được chuyển sang features/lesson_player/lesson_player_screen.dart)

// ======================= Cổng phụ huynh =======================
const _viNumbers = ['không', 'một', 'hai', 'ba', 'bốn', 'năm', 'sáu', 'bảy', 'tám', 'chín'];

class ParentGateScreen extends StatefulWidget {
  const ParentGateScreen({super.key});
  @override
  State<ParentGateScreen> createState() => _ParentGateScreenState();
}

class _ParentGateScreenState extends State<ParentGateScreen> {
  final _rnd = Random();
  final _ctl = TextEditingController();
  late int _a, _b;
  int _fails = 0;
  DateTime? _lockedUntil;

  @override
  void initState() {
    super.initState();
    _newQuestion();
  }

  void _newQuestion() {
    _a = 3 + _rnd.nextInt(7);
    _b = 3 + _rnd.nextInt(7);
    _ctl.clear();
  }

  void _submit() {
    if (_lockedUntil != null && DateTime.now().isBefore(_lockedUntil!)) return;
    if (int.tryParse(_ctl.text.trim()) == _a * _b) {
      context.pushReplacement('/parent');
      return;
    }
    setState(() {
      _fails++;
      if (_fails >= 3) {
        _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
        _fails = 0;
      }
      _newQuestion();
    });
  }

  @override
  Widget build(BuildContext context) {
    final locked = _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);
    return Scaffold(
      appBar: AppBar(title: const Text('Dành cho phụ huynh')),
      body: Center(
        child: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${_viNumbers[_a]} nhân ${_viNumbers[_b]} bằng mấy?'.replaceFirstMapped(RegExp('^.'), (m) => m[0]!.toUpperCase()),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(controller: _ctl, keyboardType: TextInputType.number, textAlign: TextAlign.center, onSubmitted: (_) => _submit()),
            const SizedBox(height: 16),
            if (locked) const Text('Sai quá nhiều lần, vui lòng thử lại sau 30 giây.', style: TextStyle(color: Colors.red)),
            FilledButton(onPressed: locked ? null : _submit, child: const Text('Mở')),
          ]),
        ),
      ),
    );
  }
}

// ======================= Khu phụ huynh (Cài đặt, Báo cáo, Học cùng con, Gói chủ đề) =======================
class ParentHomeScreen extends ConsumerWidget {
  const ParentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final profiles = ref.watch(profilesProvider);
    final profile = ref.watch(activeProfileProvider);
    final storage = ref.read(storageProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Khu phụ huynh', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.orange,
            unselectedLabelColor: Colors.black54,
            indicatorColor: AppColors.orange,
            tabs: [
              Tab(icon: Icon(Icons.settings_outlined), text: "Cài đặt & Hồ sơ"),
              Tab(icon: Icon(Icons.bar_chart_rounded), text: "Báo cáo tiến độ"),
              Tab(icon: Icon(Icons.family_restroom_rounded), text: "Học cùng con"),
              Tab(icon: Icon(Icons.extension_outlined), text: "Gói chủ đề"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Cài đặt & Hồ sơ
            ListView(padding: const EdgeInsets.all(16), children: [
              SwitchListTile(
                title: const Text('Gợi ý tiếng Việt cho bé'),
                subtitle: const Text('Đọc thêm hướng dẫn bằng tiếng Việt (mặc định tắt)'),
                value: settings.viHints,
                onChanged: notifier.setViHints,
              ),
              SwitchListTile(title: const Text('Nhạc nền'), value: settings.musicOn, onChanged: notifier.setMusic),
              ListTile(
                title: Text('Giới hạn mỗi ngày: ${settings.dailyLimitMin} phút'),
                subtitle: Slider(
                  min: 10,
                  max: 60,
                  divisions: 10,
                  value: settings.dailyLimitMin.toDouble().clamp(10, 60),
                  label: '${settings.dailyLimitMin}',
                  onChanged: (v) => notifier.setDailyLimit(v.round()),
                ),
              ),
              const Divider(),
              const Padding(padding: EdgeInsets.all(8), child: Text('Hồ sơ của bé', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              for (final p in profiles)
                ListTile(
                  leading: AvatarView(p.avatarId, size: 44),
                  title: Text(p.nickname, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Xoá hồ sơ "${p.nickname}"?'),
                          content: const Text('Toàn bộ tiến độ học của bé sẽ bị xoá.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xoá')),
                          ],
                        ),
                      );
                      if (ok == true) await ref.read(profilesProvider.notifier).remove(p.id);
                    },
                  ),
                ),
            ]),

            // Tab 2: Báo cáo
            ProgressReportTab(profileId: profile?.id, storage: storage),

            // Tab 3: Học cùng con
            const LearnTogetherTab(),

            // Tab 4: Gói chủ đề
            const TopicPacksTab(),
          ],
        ),
      ),
    );
  }
}
