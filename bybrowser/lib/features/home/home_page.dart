import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/intent/open_intent.dart';
import '../../core/models/document_ref.dart';
import '../../core/recent/recent_files.dart';
import '../../core/saf/saf_service.dart';
import '../../core/settings/app_settings.dart';
import '../../shared/dialogs.dart';
import '../about/about_page.dart';
import 'open_document.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.recents, required this.settings});

  final RecentFilesStore recents;
  final AppSettings settings;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // File đến từ "Mở bằng…": lúc khởi động (pending) hoặc khi app đang chạy.
    OpenIntent.bind();
    OpenIntent.onOpen = _openFromIntent;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uri = await OpenIntent.takePending();
      if (uri != null) _openFromIntent(uri);
    });
  }

  @override
  void dispose() {
    OpenIntent.onOpen = null;
    super.dispose();
  }

  Future<void> _openFromIntent(String uri) async {
    if (!mounted) return;
    // Về Home trước để không chồng nhiều editor.
    Navigator.of(context).popUntil((r) => r.isFirst);
    final name = Uri.decodeComponent(uri.split('/').last);
    await openDocument(context, DocumentRef(uri: uri, name: name), widget.recents);
  }

  Future<void> _pickAndOpen() async {
    DocumentRef? ref;
    try {
      ref = await SafService.openDocument();
    } on SafException catch (e) {
      if (mounted) await showErrorDialog(context, 'Không chọn được file', e.message);
      return;
    }
    if (ref == null || !mounted) return;
    await openDocument(context, ref, widget.recents);
  }

  Future<void> _remove(DocumentRef ref) async {
    await widget.recents.remove(ref.uri);
    try {
      await SafService.releasePermission(ref.uri);
    } catch (_) {
      // Không quan trọng nếu thả quyền thất bại.
    }
  }

  Future<void> _chooseTheme() async {
    final mode = await showDialog<ThemeMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Giao diện'),
        children: [
          for (final m in ThemeMode.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, m),
              child: Row(
                children: [
                  Icon(
                    m == widget.settings.themeMode
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(themeModeLabel(m)),
                ],
              ),
            ),
        ],
      ),
    );
    if (mode != null) await widget.settings.setThemeMode(mode);
  }

  Future<void> _about() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AboutPage(version: '${info.version} (${info.buildNumber})'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ByBrowser'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'theme':
                  _chooseTheme();
                case 'about':
                  _about();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'theme',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.brightness_6_outlined),
                  title: Text('Giao diện sáng / tối'),
                ),
              ),
              PopupMenuItem(
                value: 'about',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.info_outline),
                  title: Text('Giới thiệu & giới hạn'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.recents,
        builder: (context, _) {
          final items = widget.recents.items;
          if (items.isEmpty) return _EmptyState(onOpen: _pickAndOpen);
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: items.length + 1,
            separatorBuilder: (_, i) =>
                i == 0 ? const SizedBox.shrink() : const Divider(height: 1),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Gần đây', style: Theme.of(context).textTheme.titleMedium),
                );
              }
              final ref = items[i - 1];
              return Dismissible(
                key: ValueKey(ref.uri),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: Icon(Icons.delete_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer),
                ),
                onDismissed: (_) => _remove(ref),
                child: ListTile(
                  leading: _KindIcon(kind: ref.kind),
                  title: Text(ref.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    [ref.kind.label, formatFileSize(ref.size)]
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                  ),
                  onTap: () => openDocument(context, ref, widget.recents),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndOpen,
        icon: const Icon(Icons.folder_open),
        label: const Text('Mở file'),
      ),
    );
  }
}

class _KindIcon extends StatelessWidget {
  const _KindIcon({required this.kind});
  final DocumentKind kind;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (kind) {
      DocumentKind.text => (Icons.description_outlined, Colors.blueGrey),
      DocumentKind.xlsx => (Icons.table_chart_outlined, Colors.green),
      DocumentKind.csv => (Icons.grid_on_outlined, Colors.teal),
      DocumentKind.docx => (Icons.article_outlined, Colors.blue),
      DocumentKind.unsupported => (Icons.insert_drive_file_outlined, Colors.grey),
    };
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 80, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text('Chưa có file nào', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Nhấn "Mở file" để chọn file văn bản, Excel (.xlsx) '
              'hoặc Word (.docx) trong máy.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
