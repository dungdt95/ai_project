import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_themes.dart';
import '../../../core/theme/theme_provider.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pref = ref.watch(themePreferenceProvider);
    final notifier = ref.read(themePreferenceProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Giao diện')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Chế độ sáng/tối ──
          const Text(
            'Chế độ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Sáng'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Tối'),
                icon: Icon(Icons.dark_mode),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('Hệ thống'),
                icon: Icon(Icons.brightness_auto),
              ),
            ],
            selected: {pref.mode},
            onSelectionChanged: (s) => notifier.setMode(s.first),
          ),

          const SizedBox(height: 24),

          // ── Màu chủ đạo ──
          const Text(
            'Màu chủ đạo',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: kThemePresets.length,
            itemBuilder: (_, i) {
              final preset = kThemePresets[i];
              final isSelected = preset.key == pref.colorName;
              return GestureDetector(
                onTap: () => notifier.setColor(preset.key),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: preset.seedColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: preset.seedColor.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 28)
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      preset.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Preview ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Xem trước',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(onPressed: () {}, child: const Text('Nút chính')),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: () {}, child: const Text('Phụ')),
                      const SizedBox(width: 8),
                      Icon(Icons.add_circle,
                          color: Theme.of(context).colorScheme.primary, size: 32),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.palette,
                            color: Theme.of(context).colorScheme.onPrimaryContainer),
                        const SizedBox(width: 8),
                        Text('Container chính',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
