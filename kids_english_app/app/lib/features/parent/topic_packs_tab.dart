import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/drive_sync_service.dart';

class TopicPacksTab extends ConsumerStatefulWidget {
  const TopicPacksTab({super.key});

  @override
  ConsumerState<TopicPacksTab> createState() => _TopicPacksTabState();
}

class _TopicPacksTabState extends ConsumerState<TopicPacksTab> {
  bool _isImporting = false;
  bool _isSyncing = false;
  bool _checking = true;
  DriveAccessStatus _status = DriveAccessStatus.notSignedIn;
  String? _authError;
  final List<String> _progress = [];

  DriveSyncService get _drive => ref.read(driveSyncServiceProvider);

  @override
  void initState() {
    super.initState();
    _refreshStatus(silent: true);
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: error ? Colors.red : AppColors.teal, content: Text(msg)),
    );
  }

  Future<void> _refreshStatus({bool silent = false}) async {
    setState(() => _checking = true);
    try {
      if (silent && _drive.account == null) await _drive.signInSilently();
      final st = await _drive.checkAccess();
      if (mounted) setState(() => _status = st);
    } catch (_) {
      if (mounted) setState(() => _status = DriveAccessStatus.error);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _authError = null;
      _checking = true;
    });
    try {
      final acc = await _drive.signIn();
      if (acc == null) {
        if (mounted) setState(() => _checking = false);
        return;
      }
      await _refreshStatus();
    } on DriveAuthException catch (e) {
      if (mounted) {
        setState(() {
          _authError = e.message;
          _checking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _authError = 'Đăng nhập thất bại: $e';
          _checking = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await _drive.signOut();
    if (mounted) setState(() => _authError = null);
    await _refreshStatus();
  }

  Future<void> _requestAccess() async {
    final id = ref.read(settingsProvider).driveFolderId;
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse('https://drive.google.com/drive/folders/$id'), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) _toast('Không mở được trang Google Drive.', error: true);
  }

  Future<void> _syncNow() async {
    setState(() {
      _isSyncing = true;
      _progress.clear();
    });
    try {
      final r = await _drive.syncNow(onProgress: (m) {
        if (mounted) setState(() => _progress.add(m));
      });
      if (mounted) setState(() => _status = r.status);
      if (r.status == DriveAccessStatus.ready) {
        await ref.read(settingsProvider.notifier).markDriveSynced();
        if (r.installed > 0) ref.invalidate(topicsProvider);
        final msg = r.installed > 0
            ? 'Đã nạp ${r.installed} chủ đề từ Google Drive.'
            : (r.errors.isEmpty ? 'Tất cả chủ đề đã là bản mới nhất.' : 'Không nạp được chủ đề nào.');
        _toast(r.errors.isEmpty ? msg : '$msg (${r.errors.length} lỗi)', error: r.errors.isNotEmpty && r.installed == 0);
        if (mounted) setState(() => _progress.addAll(r.errors.map((e) => 'Lỗi: $e')));
      } else if (r.status == DriveAccessStatus.notSignedIn) {
        _toast('Hãy đăng nhập Gmail trước.', error: true);
      } else if (r.status == DriveAccessStatus.noPermission) {
        _toast('Tài khoản chưa được cấp quyền vào kho chủ đề.', error: true);
      } else {
        _toast('Lỗi mạng hoặc Google Drive. Vui lòng thử lại.', error: true);
      }
    } catch (e) {
      _toast('Lỗi đồng bộ: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _importPack() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['bvpack', 'zip'],
    );

    if (result.isEmpty || result.first.path == null) return;

    setState(() => _isImporting = true);
    try {
      final bytes = await File(result.first.path!).readAsBytes();
      final topic = await ref.read(packInstallerProvider).install(bytes);
      ref.invalidate(topicsProvider);
      _toast('Đã nạp thành công gói chủ đề: ${topic.titleEn}!');
    } catch (e) {
      _toast('Lỗi khi nạp gói: $e', error: true);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _deletePack(String topicId, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa gói chủ đề?'),
        content: Text('Gói "$title" sẽ bị xóa khỏi máy. Bạn có thể nạp lại sau.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(packInstallerProvider).uninstall(topicId);
      final storage = ref.read(storageProvider);
      final v = storage.installedPackVersions()..remove(topicId);
      await storage.putInstalledPackVersions(v);
      ref.invalidate(topicsProvider);
      _toast('Đã xóa gói "$title".');
    } catch (e) {
      _toast('Không xóa được gói: $e', error: true);
    }
  }

  String _formatTime(String iso) {
    final t = DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)} ${two(t.day)}/${two(t.month)}/${t.year}';
  }

  Widget _driveCard() {
    final settings = ref.watch(settingsProvider);
    final email = _drive.account?.email;
    final busy = _isSyncing || _checking;

    Widget statusArea;
    if (_checking) {
      statusArea = const Row(children: [
        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 8),
        Text('Đang kiểm tra...'),
      ]);
    } else if (_status == DriveAccessStatus.noPermission) {
      statusArea = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.orange),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.lock_outline, color: AppColors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text('Tài khoản này chưa được cấp quyền vào kho chủ đề.', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 6),
          const Text(
            'Bấm nút dưới đây để mở Google Drive và chọn "Yêu cầu quyền truy cập". Khi chủ kho đồng ý, quay lại đây bấm "Kiểm tra lại".',
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
              onPressed: _requestAccess,
              icon: const Icon(Icons.mail_outline),
              label: const Text('Gửi yêu cầu cấp quyền truy cập'),
            ),
            OutlinedButton(onPressed: _refreshStatus, child: const Text('Kiểm tra lại')),
          ]),
        ]),
      );
    } else if (_status == DriveAccessStatus.ready) {
      final last = settings.lastDriveSyncAt;
      statusArea = Row(children: [
        const Icon(Icons.check_circle, color: AppColors.teal),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Đã kết nối kho chủ đề${last == null ? '' : '\nĐồng bộ gần nhất: ${_formatTime(last)}'}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ]);
    } else if (_status == DriveAccessStatus.error) {
      statusArea = Row(children: [
        const Icon(Icons.cloud_off, color: Colors.red),
        const SizedBox(width: 8),
        const Expanded(child: Text('Không kết nối được Google Drive (lỗi mạng?).')),
        TextButton(onPressed: _refreshStatus, child: const Text('Thử lại')),
      ]);
    } else {
      statusArea = const Text('Hãy đăng nhập Gmail đã được cấp quyền để nạp chủ đề mới.');
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.cloud_sync_rounded, color: AppColors.teal, size: 28),
              SizedBox(width: 8),
              Text('Đồng bộ từ Google Drive', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.account_circle_outlined),
              const SizedBox(width: 8),
              Expanded(child: Text(email ?? 'Chưa đăng nhập Gmail', style: const TextStyle(fontWeight: FontWeight.w600))),
              if (email == null)
                FilledButton(onPressed: busy ? null : _signIn, child: const Text('Đăng nhập Gmail'))
              else ...[
                OutlinedButton(onPressed: busy ? null : _signIn, child: const Text('Đổi tài khoản')),
                const SizedBox(width: 8),
                TextButton(onPressed: busy ? null : _signOut, child: const Text('Đăng xuất')),
              ],
            ]),
            if (_authError != null) ...[
              const SizedBox(height: 8),
              Text(_authError!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            statusArea,
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tự động kiểm tra & nạp chủ đề mới khi mở app'),
              value: settings.autoSyncDrive,
              onChanged: (v) => ref.read(settingsProvider.notifier).setAutoSyncDrive(v),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: busy ? null : _syncNow,
              icon: _isSyncing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.cloud_download_outlined),
              label: Text(_isSyncing ? 'Đang đồng bộ...' : 'Kiểm tra & Nạp từ Google Drive ngay'),
            ),
            if (_progress.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final line in _progress.length > 8 ? _progress.sublist(_progress.length - 8) : _progress)
                Text(line, style: TextStyle(fontSize: 13, color: line.startsWith('Lỗi') ? Colors.red : Colors.black54)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(topicsProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _driveCard(),
        const SizedBox(height: 16),
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
                    Icon(Icons.extension_rounded, color: AppColors.orange, size: 28),
                    SizedBox(width: 8),
                    Text(
                      "Nạp thêm chủ đề mới (.bvpack)",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "Bạn có thể bổ sung các chủ đề học mới (Level 2, Level 3...) bất cứ lúc nào bằng cách chọn file gói dữ liệu .bvpack hoặc .zip mà không cần cài lại app.",
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  onPressed: _isImporting ? null : _importPack,
                  icon: _isImporting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.file_upload_outlined),
                  label: Text(_isImporting ? "Đang xử lý..." : "Chọn file gói từ thiết bị"),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text("Danh sách các chủ đề hiện có:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        topicsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text("Lỗi: $e"),
          data: (topics) => Column(
            children: topics.map((t) {
              final isBuiltin = t.baseDir == null;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isBuiltin ? AppColors.teal : AppColors.pink,
                    child: Icon(isBuiltin ? Icons.check_circle_outline : Icons.cloud_done_outlined, color: Colors.white),
                  ),
                  title: Text(t.titleEn, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${t.titleVi} • ${t.words.length} từ vựng • ${isBuiltin ? 'Tích hợp sẵn' : 'Gói cài thêm'}"),
                  trailing: isBuiltin
                      ? null
                      : IconButton(
                          tooltip: 'Xóa gói này',
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deletePack(t.id, t.titleEn),
                        ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
