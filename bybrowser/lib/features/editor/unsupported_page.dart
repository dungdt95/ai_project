import 'package:flutter/material.dart';

import '../../core/models/document_ref.dart';

/// Hiển thị khi file không thuộc loại app hỗ trợ.
class UnsupportedPage extends StatelessWidget {
  const UnsupportedPage({super.key, required this.document});

  final DocumentRef document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(document.name, overflow: TextOverflow.ellipsis)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('Định dạng không được hỗ trợ', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Ứng dụng chỉ mở được file văn bản (.txt, .md, .json…), '
                'bảng tính .xlsx và tài liệu .docx.\n\n'
                'File: ${document.name}'
                '${document.mime != null ? '\nMIME: ${document.mime}' : ''}'
                '${document.size != null ? '\nKích thước: ${formatFileSize(document.size)}' : ''}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
