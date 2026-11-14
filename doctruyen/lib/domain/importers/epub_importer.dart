import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../models/book.dart';
import 'parsed_book.dart';
import 'text_decoder.dart';
import 'txt_importer.dart';

/// Nhập .epub: container.xml → OPF → spine; tiêu đề lấy từ NCX/nav, rồi tới
/// thẻ heading đầu tiên; HTML được đưa về các đoạn văn (Markdown-lite).
class EpubImporter {
  const EpubImporter._();

  static ParsedBook parseBytes(List<int> bytes, String fileName) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const ImportException('Không đọc được tệp EPUB.');
    }
    final files = <String, Uint8List>{
      for (final f in archive.files)
        if (f.isFile) f.name.replaceAll('\\', '/'): f.content,
    };
    String text(String path) => TextDecoder.decode(files[path]!);

    final container = files['META-INF/container.xml'];
    if (container == null) {
      throw const ImportException('EPUB thiếu META-INF/container.xml.');
    }
    final rootfile = XmlDocument.parse(TextDecoder.decode(container))
        .findAllElements('rootfile')
        .map((e) => e.getAttribute('full-path'))
        .whereType<String>()
        .firstOrNull;
    if (rootfile == null || !files.containsKey(rootfile)) {
      throw const ImportException('EPUB thiếu tệp OPF.');
    }
    final opfDir = _dirOf(rootfile);
    final opf = XmlDocument.parse(text(rootfile));

    final manifest = <String, _Item>{};
    for (final e in opf.findAllElements('item')) {
      final id = e.getAttribute('id');
      final href = e.getAttribute('href');
      if (id == null || href == null) continue;
      manifest[id] = _Item(
        _resolve(opfDir, Uri.decodeFull(href)),
        e.getAttribute('media-type') ?? '',
        e.getAttribute('properties') ?? '',
      );
    }
    final spine = opf
        .findAllElements('itemref')
        .map((e) => manifest[e.getAttribute('idref')])
        .whereType<_Item>()
        .where((i) => i.mediaType.contains('html') && files.containsKey(i.path))
        .toList();
    if (spine.isEmpty) throw const ImportException('EPUB không có nội dung.');

    final titles = <String, String>{};
    final navItem = manifest.values
        .where((i) => i.properties.split(' ').contains('nav'))
        .firstOrNull;
    final ncxItem = manifest.values
        .where((i) => i.mediaType.contains('ncx'))
        .firstOrNull;
    try {
      if (navItem != null && files.containsKey(navItem.path)) {
        _readNav(text(navItem.path), _dirOf(navItem.path), titles);
      }
    } catch (_) {}
    try {
      if (ncxItem != null && files.containsKey(ncxItem.path)) {
        _readNcx(text(ncxItem.path), _dirOf(ncxItem.path), titles);
      }
    } catch (_) {}

    final chapters = <ParsedChapter>[];
    for (final item in spine) {
      final html = text(item.path);
      final body = htmlToParagraphs(html);
      if (body.trim().isEmpty) continue;
      final heading = RegExp(
        r'<h[1-3][^>]*>(.*?)</h[1-3]>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(html);
      final title =
          titles[item.path] ??
          (heading != null ? _stripTags(heading.group(1)!).trim() : '');
      final n = chapters.length + 1;
      chapters.add(
        ParsedChapter(
          number: n,
          title: title.isEmpty ? 'Phần $n' : title,
          content: body,
        ),
      );
    }
    if (chapters.isEmpty) {
      throw const ImportException('EPUB không có nội dung văn bản.');
    }

    String meta(String name) =>
        opf
            .findAllElements(name)
            .map((e) => e.innerText.trim())
            .where((s) => s.isNotEmpty)
            .firstOrNull ??
        '';
    final title = meta('dc:title');
    return ParsedBook(
      title: title.isEmpty ? TxtImporter.titleFromFileName(fileName) : title,
      author: meta('dc:creator'),
      sourceType: SourceType.epub,
      chapters: chapters,
    );
  }

  static void _readNcx(String xml, String dir, Map<String, String> out) {
    for (final p in XmlDocument.parse(xml).findAllElements('navPoint')) {
      final label = p.getElement('navLabel')?.innerText.trim() ?? '';
      final src = p.getElement('content')?.getAttribute('src');
      if (src == null || label.isEmpty) continue;
      out.putIfAbsent(
        _resolve(dir, Uri.decodeFull(src.split('#').first)),
        () => label,
      );
    }
  }

  static void _readNav(String xml, String dir, Map<String, String> out) {
    final doc = XmlDocument.parse(xml);
    for (final a in doc.findAllElements('a')) {
      final href = a.getAttribute('href');
      final label = a.innerText.trim();
      if (href == null || label.isEmpty) continue;
      out.putIfAbsent(
        _resolve(dir, Uri.decodeFull(href.split('#').first)),
        () => label,
      );
    }
  }

  static String _dirOf(String path) =>
      path.contains('/') ? path.substring(0, path.lastIndexOf('/') + 1) : '';

  static String _resolve(String dir, String href) {
    final out = <String>[];
    for (final part in '$dir$href'.split('/')) {
      if (part == '..') {
        if (out.isNotEmpty) out.removeLast();
      } else if (part != '.' && part.isNotEmpty) {
        out.add(part);
      }
    }
    return out.join('/');
  }

  static String _stripTags(String s) =>
      _decodeEntities(s.replaceAll(RegExp(r'<[^>]+>'), ''));

  /// HTML → các dòng văn bản; `<em>/<i>` → `*`, `<strong>/<b>` → `**`.
  static String htmlToParagraphs(String html) {
    var s = html;
    s = s.replaceAll(
      RegExp(
        r'<(script|style|head)[^>]*>.*?</\1>',
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );
    s = s.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    s = s.replaceAll(
      RegExp(r'</?(strong|b)(\s[^>]*)?>', caseSensitive: false),
      '**',
    );
    s = s.replaceAll(
      RegExp(r'</?(em|i)(\s[^>]*)?>', caseSensitive: false),
      '*',
    );
    s = s.replaceAll(RegExp(r'<hr[^>]*>', caseSensitive: false), '\n---\n');
    s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    s = s.replaceAll(
      RegExp(
        r'</(p|div|h[1-6]|li|tr|blockquote|section)>',
        caseSensitive: false,
      ),
      '\n',
    );
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');
    s = _decodeEntities(s);
    return s
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'[ \t ]+'), ' ').trim())
        .where((l) => l.isNotEmpty)
        .join('\n');
  }

  static const Map<String, String> _entities = {
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': ' ',
    'mdash': '—',
    'ndash': '–',
    'hellip': '…',
    'ldquo': '“',
    'rdquo': '”',
    'lsquo': '‘',
    'rsquo': '’',
    'laquo': '«',
    'raquo': '»',
  };

  static String _decodeEntities(String s) {
    return s.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z]+);'), (
      m,
    ) {
      final g = m.group(1)!;
      if (g.startsWith('#x')) {
        return String.fromCharCode(int.parse(g.substring(2), radix: 16));
      }
      if (g.startsWith('#')) {
        return String.fromCharCode(int.parse(g.substring(1)));
      }
      return _entities[g] ?? m.group(0)!;
    });
  }
}

class _Item {
  const _Item(this.path, this.mediaType, this.properties);

  final String path;
  final String mediaType;
  final String properties;
}
