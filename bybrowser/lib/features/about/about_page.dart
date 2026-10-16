import 'package:flutter/material.dart';

/// Giới thiệu ứng dụng và giới hạn hỗ trợ từng định dạng.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key, required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Giới thiệu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.description, size: 30, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ByBrowser', style: theme.textTheme.headlineSmall),
                  Text('Phiên bản $version', style: theme.textTheme.bodyMedium),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Đọc, hiển thị và chỉnh sửa file văn bản, Excel (.xlsx) và Word (.docx) '
            'ngay trên điện thoại, hoàn toàn offline. File được mở qua hộp thoại chọn file '
            'của Android và lưu đè trực tiếp vào file gốc.',
          ),
          const SizedBox(height: 24),
          _Section(
            icon: Icons.description_outlined,
            color: Colors.blueGrey,
            title: 'Văn bản (.txt, .md, .json, .csv, mã nguồn…)',
            ok: const [
              'Tự nhận encoding UTF-8 / UTF-8 BOM / UTF-16, giữ nguyên kiểu xuống dòng (CRLF/LF) khi lưu',
              'Số dòng, tô màu cú pháp cho ~30 ngôn ngữ, tự xuống dòng',
              'Tìm kiếm / thay thế (phân biệt hoa thường, biểu thức chính quy), hoàn tác / làm lại',
            ],
            limits: const [
              'File > 5 MB chỉ xem; file > 512 KB không tô màu cú pháp',
              'File không phải UTF-8 được hiển thị theo Latin-1, lưu có thể mất ký tự',
            ],
          ),
          _Section(
            icon: Icons.table_chart_outlined,
            color: Colors.green,
            title: 'Bảng tính Excel (.xlsx)',
            ok: const [
              'Nhiều sheet, ô gộp, độ rộng cột, chữ đậm, căn lề, định dạng số / ngày / phần trăm',
              'Sửa ô (số, chữ, TRUE/FALSE, =công thức), chèn / xóa dòng và cột có dịch tham chiếu công thức',
              'Chỉ ghi lại phần dữ liệu; chart, conditional formatting, định nghĩa tên… trong file được giữ nguyên',
            ],
            limits: const [
              'Không tính lại công thức trong app (hiển thị giá trị đã lưu; Excel tính lại khi mở)',
              'Không hiển thị màu nền, viền ô, chart',
              'Vùng conditional formatting / data validation không được dịch khi chèn, xóa dòng cột',
              'Không hỗ trợ .xls (Excel 97-2003)',
            ],
          ),
          _Section(
            icon: Icons.article_outlined,
            color: Colors.blue,
            title: 'Tài liệu Word (.docx)',
            ok: const [
              'Sửa văn bản, đậm / nghiêng / gạch chân / gạch ngang, màu chữ, nền, cỡ chữ, font',
              'Heading 1-6, danh sách bullet / số nhiều cấp, căn lề, thụt lề, liên kết',
              'Bảng, ảnh, hộp văn bản, biểu đồ, công thức toán, header/footer, khổ giấy được giữ nguyên khi lưu',
            ],
            limits: const [
              'Bảng, ảnh và các đối tượng khác chỉ xem, không sửa được trong app',
              'Chú thích cuối trang, bình luận, trường tự động (số trang, mục lục), theo dõi thay đổi sẽ mất khi lưu',
              'Ngắt dòng mềm và ngắt trang thành đoạn mới',
              'Không hỗ trợ .doc (Word 97-2003)',
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.color,
    required this.title,
    required this.ok,
    required this.limits,
  });

  final IconData icon;
  final Color color;
  final String title;
  final List<String> ok;
  final List<String> limits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            for (final s in ok) _Line(Icons.check_circle_outline, Colors.green, s),
            for (final s in limits) _Line(Icons.info_outline, theme.colorScheme.tertiary, s),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.color, this.text);
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
