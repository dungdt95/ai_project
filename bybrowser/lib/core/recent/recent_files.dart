import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/document_ref.dart';

/// Danh sách file mở gần đây, lưu trong SharedPreferences.
///
/// Mỗi mục là một [DocumentRef] có content URI đã được cấp quyền lâu dài,
/// nên có thể mở lại trực tiếp mà không cần chọn file lần nữa.
class RecentFilesStore extends ChangeNotifier {
  RecentFilesStore({this.maxItems = 30});

  static const _key = 'recent_files_v1';
  final int maxItems;

  List<DocumentRef> _items = const [];
  List<DocumentRef> get items => _items;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    _items = raw
        .map((s) {
          try {
            return DocumentRef.decode(s);
          } catch (_) {
            return null;
          }
        })
        .whereType<DocumentRef>()
        .toList();
    notifyListeners();
  }

  /// Đưa [ref] lên đầu danh sách, gỡ mục cũ trùng.
  ///
  /// Trùng = cùng URI, hoặc cùng tên + kích thước: Downloads provider của
  /// Android có thể trả về hai URI khác nhau cho cùng một file (`raw:` trước
  /// khi MediaStore index, `msf:` sau đó) nên chỉ so URI là chưa đủ.
  Future<void> touch(DocumentRef ref) async {
    bool same(DocumentRef e) =>
        e.uri == ref.uri ||
        (e.name == ref.name && e.size != null && e.size == ref.size);
    final next = [
      ref.copyWith(lastOpened: DateTime.now()),
      ..._items.where((e) => !same(e)),
    ];
    if (next.length > maxItems) next.removeRange(maxItems, next.length);
    await _save(next);
  }

  Future<void> remove(String uri) async {
    await _save(_items.where((e) => e.uri != uri).toList());
  }

  Future<void> _save(List<DocumentRef> next) async {
    _items = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next.map((e) => e.encode()).toList());
  }
}
