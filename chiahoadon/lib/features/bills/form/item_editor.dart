import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/extensions/app_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/vn_text.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/money_field.dart';
import '../../../domain/models/bill_item.dart';
import '../../../domain/models/item_preset.dart';
import '../../../domain/models/member.dart';
import '../../items/item_preset_picker.dart';
import '../../items/item_presets_provider.dart';

/// Sheet thêm hoặc sửa một món (SPEC FR-3.6, FR-3.7).
///
/// Trả về món đã nhập, hoặc `null` nếu người dùng đóng sheet.
class ItemEditorSheet extends ConsumerStatefulWidget {
  const ItemEditorSheet({
    required this.participants,
    super.key,
    this.item,
  });

  /// Những người tham gia hóa đơn — chỉ họ mới được chọn cho món.
  final List<Member> participants;

  /// `null` nghĩa là thêm món mới.
  final BillItem? item;

  static Future<BillItem?> show(
    BuildContext context, {
    required List<Member> participants,
    BillItem? item,
  }) => showModalBottomSheet<BillItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        ItemEditorSheet(participants: participants, item: item),
  );

  @override
  ConsumerState<ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends ConsumerState<ItemEditorSheet> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  late Set<String> _users;
  late Map<String, int> _weights;

  int _unitPrice = 0;

  bool get _isEditing => widget.item != null;

  /// Tổng số phần của món — mỗi người ít nhất một phần.
  int get _portions => _users.fold(0, (sum, id) => sum + (_weights[id] ?? 1));

  /// Thành tiền: giá một phần × số phần.
  ///
  /// Giá ghi trên món là giá **cho một người**, nên hai người ăn là hai lần
  /// giá đó — không phải chia đôi (SPEC FR-4.2).
  int get _amount => _unitPrice * _portions;

  @override
  void initState() {
    super.initState();

    final item = widget.item;
    if (item != null) {
      _nameController.text = item.name;
      _priceController.text = item.unitPrice == 0
          ? ''
          : item.unitPrice.toVndPlain();
      _unitPrice = item.unitPrice;
      _users = {for (final user in item.participants) user.memberId};
      _weights = {
        for (final user in item.participants) user.memberId: user.weightNum,
      };
    } else {
      // Mặc định chọn sẵn tất cả người tham gia hóa đơn — phần lớn món là món
      // cả nhóm cùng ăn, nên cách này giảm được nhiều lần chạm (SPEC FR-4.2).
      _users = {for (final member in widget.participants) member.id};
      _weights = {};
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presets =
        ref.watch(itemPresetsProvider).value ?? const <ItemPreset>[];

    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.s16,
        right: AppTheme.s16,
        top: AppTheme.s16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppTheme.s16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Sửa món' : 'Thêm món',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.s16),

            // Đường chính: phần lớn món là món quen, chọn một phát xong cả tên
            // lẫn giá mà không phải bật bàn phím. Khi thêm món mới và đã có món
            // sẵn thì nút này nổi bật hơn ô nhập tay bên dưới; sửa món hoặc
            // chưa có món sẵn nào thì giữ dạng phụ để không lấn ô tên.
            SizedBox(
              width: double.infinity,
              child: !_isEditing && presets.isNotEmpty
                  ? FilledButton.tonalIcon(
                      onPressed: _pickPreset,
                      icon: const Icon(Icons.restaurant_menu_outlined),
                      label: const Text('Chọn món có sẵn'),
                    )
                  : OutlinedButton.icon(
                      onPressed: _pickPreset,
                      icon: const Icon(
                        Icons.restaurant_menu_outlined,
                        size: 18,
                      ),
                      label: const Text('Chọn món có sẵn'),
                    ),
            ),
            const SizedBox(height: AppTheme.s12),

            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Tên món *',
                hintText: 'Lẩu thái',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppTheme.s12),

            MoneyField(
              controller: _priceController,
              label: 'Giá một người',
              onChanged: (value) => setState(() => _unitPrice = value),
            ),
            const SizedBox(height: AppTheme.s8),

            // Viết hẳn phép nhân ra chứ không chỉ hiện kết quả: người dùng
            // nhìn một cái là biết app đang nhân hay đang chia.
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _portions == 0
                    ? 'Chọn người dùng món để tính tiền'
                    : '${_unitPrice.toVnd()} × $_portions phần '
                          '= ${_amount.toVnd()}',
                style: MoneyTextStyle.medium.copyWith(
                  color: _portions == 0
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.s16),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ai dùng món này? (${_users.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(
                    () => _users = {
                      for (final member in widget.participants) member.id,
                    },
                  ),
                  child: const Text('Cả nhóm'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.s8),

            Wrap(
              spacing: AppTheme.s8,
              runSpacing: AppTheme.s8,
              children: [
                for (final member in widget.participants)
                  FilterChip(
                    label: Text(_chipLabel(member)),
                    selected: _users.contains(member.id),
                    onSelected: (_) => setState(() {
                      if (!_users.remove(member.id)) _users.add(member.id);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.s8),

            // Hai lối tắt của SPEC FR-4.2. Để thành nút chứ không giấu sau
            // thao tác chạm giữ — người dùng không mò ra cử chỉ ẩn.
            // Dùng Wrap chứ không Row: hai nút này không vừa một hàng ở bề
            // ngang 360dp mà NFR-9 cam kết hỗ trợ.
            Wrap(
              spacing: AppTheme.s8,
              runSpacing: AppTheme.s8,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickOnlyOne,
                  icon: const Icon(Icons.person, size: 18),
                  label: const Text('Chỉ một người'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                  ),
                ),
                if (_users.length > 1)
                  OutlinedButton.icon(
                    onPressed: _editWeights,
                    icon: const Icon(Icons.balance, size: 18),
                    label: const Text('Số phần'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                  ),
              ],
            ),

            if (_users.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.s12),
                child: _SharedItemWarning(
                  count: widget.participants.length,
                ),
              ),

            // Gợi ý lưu lại món vừa gõ tay, để lần sau chỉ cần chọn. Chỉ hiện
            // khi món này chưa có trong danh sách — hỏi lại cái đã có là thừa.
            if (_canSave && !_isInPresets(presets))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saveToPresets,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: const Text('Lưu vào món có sẵn'),
                ),
              ),

            const SizedBox(height: AppTheme.s24),
            Row(
              children: [
                if (_isEditing) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.s12),
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _canSave ? _save : null,
                    child: Text(_isEditing ? 'Lưu món' : 'Thêm món'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Phải có tên, có giá, và **có ít nhất một người dùng món**.
  ///
  /// Số người là một vế của phép nhân, nên món không có ai dùng thì không có
  /// thành tiền để mà lưu.
  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      _unitPrice > 0 &&
      _users.isNotEmpty;

  /// Tên đang gõ đã có trong danh sách món có sẵn hay chưa.
  ///
  /// Nhận danh sách từ ngoài vào chứ không tự `ref.read`: danh sách nạp bất
  /// đồng bộ, nên đọc một phát lúc chưa xong thì luôn ra "chưa có" và nút mời
  /// lưu hiện cả với món đã có.
  bool _isInPresets(List<ItemPreset> presets) {
    final typed = VnText.normalize(_nameController.text.trim());
    if (typed.isEmpty) return false;

    return presets.any((preset) => preset.nameNorm == typed);
  }

  /// Mở bộ chọn món có sẵn, rồi điền tên và giá vào form.
  Future<void> _pickPreset() async {
    final preset = await ItemPresetPicker.show(context);
    if (preset == null || !mounted) return;

    setState(() {
      _nameController.text = preset.name;
      _unitPrice = preset.unitPrice;
      _priceController.text = preset.unitPrice == 0
          ? ''
          : preset.unitPrice.toVndPlain();
    });
  }

  /// Lưu món đang gõ vào danh sách để dùng lại.
  ///
  /// Lưu **đơn giá**, không lưu thành tiền: số lượng thuộc về lần ăn này, còn
  /// đơn giá mới là thứ lần sau dùng lại được.
  Future<void> _saveToPresets() async {
    final result = await ref
        .read(itemPresetsProvider.notifier)
        .saveFromBill(
          name: _nameController.text,
          unitPrice: _unitPrice,
        );
    if (!mounted) return;

    result.when(
      ok: (preset) => AppSnackBar.success(
        context,
        'Đã lưu "${preset.name}" vào món có sẵn',
      ),
      err: (error) => AppSnackBar.error(context, error.message),
    );
  }

  String _chipLabel(Member member) {
    final weight = _weights[member.id] ?? 1;
    return (weight > 1 && _users.contains(member.id))
        ? '${member.displayName} ×$weight'
        : member.displayName;
  }

  /// "Món này của riêng [tên]" — SPEC FR-4.2.
  Future<void> _pickOnlyOne() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Món này của riêng ai?'),
              dense: true,
            ),
            const Divider(height: 1),
            for (final member in widget.participants)
              ListTile(
                title: Text(member.displayName),
                onTap: () => Navigator.of(sheetContext).pop(member.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _users = {picked};
      _weights.clear();
    });
  }

  /// Bảng nhập số phần cho từng người trong món (SPEC FR-4.2, trọng số).
  ///
  /// Ví dụ quen thuộc: Bình uống 2 lon bia, An 1 lon.
  Future<void> _editWeights() async {
    final selected = widget.participants
        .where((member) => _users.contains(member.id))
        .toList();

    final result = await showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _WeightSheet(
        members: selected,
        weights: {
          for (final member in selected)
            member.id: _weights[member.id] ?? 1,
        },
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _weights = result);
  }

  void _save() {
    Navigator.of(context).pop(
      BillItem(
        id: widget.item?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        unitPrice: _unitPrice,
        // Số lượng chung của món không còn dùng tới; số phần nằm ở từng người.
        quantity: 1,
        sortOrder: widget.item?.sortOrder ?? 0,
        participants: [
          for (final id in _users)
            ItemParticipant(memberId: id, weightNum: _weights[id] ?? 1),
        ],
      ),
    );
  }
}

/// Bảng nhập số phần cho từng người trong một món (SPEC FR-4.2).
class _WeightSheet extends StatefulWidget {
  const _WeightSheet({required this.members, required this.weights});

  final List<Member> members;
  final Map<String, int> weights;

  @override
  State<_WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends State<_WeightSheet> {
  late Map<String, int> _weights;

  @override
  void initState() {
    super.initState();
    _weights = {...widget.weights};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _weights.values.fold(0, (sum, value) => sum + value);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Số phần trong món',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.s4),
            Text(
              'Ví dụ: Bình uống 2 lon bia, An 1 lon → Bình 2 phần, An 1 phần.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.s16),

            for (final member in widget.members)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.s4),
                child: Row(
                  children: [
                    Expanded(child: Text(member.displayName)),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: (_weights[member.id] ?? 1) > 1
                          ? () => setState(
                              () => _weights[member.id] =
                                  (_weights[member.id] ?? 1) - 1,
                            )
                          : null,
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${_weights[member.id] ?? 1}',
                        textAlign: TextAlign.center,
                        style: MoneyTextStyle.medium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(
                        () => _weights[member.id] =
                            (_weights[member.id] ?? 1) + 1,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: AppTheme.s8),
            Text(
              'Tổng $total phần',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.s16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: AppTheme.s12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_weights),
                    child: const Text('Xong'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Nhãn cảnh báo cho món chưa chọn ai dùng (SPEC FR-4.2).
///
/// Tiền của món đó **không** biến mất — engine chia đều cho cả nhóm — nhưng
/// người dùng cần biết điều đó đang xảy ra.
class _SharedItemWarning extends StatelessWidget {
  const _SharedItemWarning({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.s12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: Color(0xFF92400E),
          ),
          const SizedBox(width: AppTheme.s8),
          Expanded(
            child: Text(
              'Chưa chọn ai — món này sẽ chia đều cho cả $count người',
              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dòng hiển thị một món trong danh sách ở bước chia tiền.
class BillItemTile extends StatelessWidget {
  const BillItemTile({
    required this.item,
    required this.members,
    required this.participantCount,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  final BillItem item;
  final Map<String, Member> members;

  /// Số người tham gia hóa đơn, để giải thích món chung chia cho bao nhiêu người.
  final int participantCount;

  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final names = [
      for (final user in item.participants)
        members[user.memberId]?.displayName ?? '?',
    ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusButton),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.s12,
          vertical: AppTheme.s12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  item.amountFor(participantCount).toVnd(),
                  style: MoneyTextStyle.small,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Xóa món',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                ),
              ],
            ),
            // Luôn viết phép nhân ra, kể cả khi chỉ một phần: đây chính là chỗ
            // người dùng cần thấy rằng giá được **nhân** với số người.
            Text(
              '${MoneyFormatter.format(item.unitPrice)} × '
              '${item.portions == 0 ? participantCount : item.portions} phần',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.s4),
            if (item.hasNoParticipants)
              _SharedItemWarning(count: participantCount)
            else
              Text(
                names.join(', '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
