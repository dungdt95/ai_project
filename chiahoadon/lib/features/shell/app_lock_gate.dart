import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../services/app_lock_service.dart';
import '../settings/settings_provider.dart';

/// Bản thật của [Authenticator]; test ghi đè provider này bằng bản giả.
final authenticatorProvider = Provider<Authenticator>(
  (ref) => DeviceAuthenticator(),
);

/// Phiên hiện tại đã mở khóa hay chưa.
///
/// Nằm ở provider chứ không nằm trong trạng thái của [AppLockGate] vì màn Cài
/// đặt cũng phải đặt được nó: người dùng vừa xác thực xong để **bật** khóa thì
/// bắt xác thực lại ngay là vô nghĩa.
class AppUnlocked extends Notifier<bool> {
  @override
  bool build() => false;

  void unlock() => state = true;

  void lock() => state = false;
}

final appUnlockedProvider = NotifierProvider<AppUnlocked, bool>(
  AppUnlocked.new,
);

/// Che toàn bộ app cho tới khi người dùng xác thực (SPEC Phase 11).
///
/// Chỉ che màn hình chứ **không** mã hóa dữ liệu: tệp SQLite vẫn nằm trong
/// vùng riêng của app, được hệ điều hành bảo vệ. Khóa này để người ngồi cạnh
/// không mở xem được ai nợ ai, chứ không chống được người có quyền root.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _authenticating = false;

  /// Đã tự hỏi xác thực cho lần khóa hiện tại hay chưa.
  ///
  /// Chỉ tự hỏi **một lần** mỗi lần khóa: hỏi lại tự động sau khi người dùng
  /// bấm hủy sẽ thành vòng lặp hộp thoại không thoát ra được.
  bool _autoPrompted = false;

  /// Lúc app rời tiền cảnh gần nhất. `null` nghĩa là chưa rời lần nào.
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final enabled = ref.read(settingsProvider).value?.appLockEnabled ?? false;
    if (!enabled) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _leftAt = DateTime.now();
      case AppLifecycleState.resumed:
        if (shouldRelock(
          lockEnabled: enabled,
          leftAt: _leftAt,
          now: DateTime.now(),
        )) {
          ref.read(appUnlockedProvider.notifier).lock();
          setState(() => _autoPrompted = false);
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);

    final authenticator = ref.read(authenticatorProvider);

    // Người dùng bật khóa rồi sau đó gỡ mã khóa màn hình trong cài đặt máy:
    // giờ không còn cách nào xác thực, mà dữ liệu thì chỉ nằm trên máy này và
    // không có đường vào nào khác. Mở ra và tự tắt khóa, thà vậy còn hơn nhốt
    // người dùng ngoài sổ nợ của chính họ.
    if (!await authenticator.isAvailable()) {
      if (!mounted) return;
      await ref.read(settingsProvider.notifier).setAppLockEnabled(false);
      if (!mounted) return;

      ref.read(appUnlockedProvider.notifier).unlock();
      setState(() => _authenticating = false);
      return;
    }

    final passed = await authenticator.authenticate();
    if (!mounted) return;

    if (passed) ref.read(appUnlockedProvider.notifier).unlock();
    setState(() => _authenticating = false);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(settingsProvider).value?.appLockEnabled ?? false;

    // Tắt khóa trong lúc app đang bị che thì mở ra ngay, không bắt xác thực.
    if (!enabled || ref.watch(appUnlockedProvider)) return widget.child;

    // Hỏi ngay thay vì bắt bấm thêm một nút: app khóa màn hình nào cũng hiện
    // hộp thoại xác thực liền khi mở. Nút "Mở khóa" là đường quay lại cho
    // trường hợp người dùng vừa bấm hủy.
    if (!_autoPrompted && !_authenticating) {
      _autoPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }

    return _LockScreen(busy: _authenticating, onUnlock: _unlock);
  }
}

/// Màn che khi app đang khóa.
class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.busy, required this.onUnlock});

  final bool busy;
  final Future<void> Function() onUnlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.s32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppTheme.s16),
              Text(
                AppConstants.appName,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppTheme.s8),
              Text(
                'Ứng dụng đang khóa.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.s24),
              FilledButton.icon(
                onPressed: busy ? null : onUnlock,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Mở khóa'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
