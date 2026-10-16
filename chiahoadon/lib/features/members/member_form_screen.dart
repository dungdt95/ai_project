import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/result.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/member_avatar.dart';
import '../../domain/models/member.dart';
import 'bank_picker_sheet.dart';
import 'members_provider.dart';

/// S06 — Thêm hoặc sửa thành viên (SPEC FR-1.1 → FR-1.6).
class MemberFormScreen extends ConsumerStatefulWidget {
  const MemberFormScreen({super.key, this.member});

  /// `null` nghĩa là thêm mới.
  final Member? member;

  static Future<void> push(BuildContext context, {Member? member}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => MemberFormScreen(member: member),
        ),
      );

  @override
  ConsumerState<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends ConsumerState<MemberFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _nickname;
  late final TextEditingController _phone;
  late final TextEditingController _bankName;
  late final TextEditingController _bankAccount;
  late final TextEditingController _bankHolder;
  late final TextEditingController _note;

  bool _saving = false;
  bool _showBankSection = false;

  /// Mã BIN của ngân hàng đã chọn. Tên ngân hàng nằm trong [_bankName], nhưng
  /// chỉ mã này mới sinh được QR.
  String? _bankBin;

  bool get _isEditing => widget.member != null;

  @override
  void initState() {
    super.initState();
    final member = widget.member;

    _name = TextEditingController(text: member?.name ?? '');
    _nickname = TextEditingController(text: member?.nickname ?? '');
    _phone = TextEditingController(text: member?.phone ?? '');
    _bankName = TextEditingController(text: member?.bankName ?? '');
    _bankAccount = TextEditingController(text: member?.bankAccount ?? '');
    _bankHolder = TextEditingController(text: member?.bankHolder ?? '');
    _note = TextEditingController(text: member?.note ?? '');

    _bankBin = member?.bankBin;
    _showBankSection = member?.hasBankInfo ?? false;

    // Avatar đổi màu theo tên nên phải vẽ lại khi người dùng gõ.
    _name.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _name
      ..removeListener(_onNameChanged)
      ..dispose();
    _nickname.dispose();
    _phone.dispose();
    _bankName.dispose();
    _bankAccount.dispose();
    _bankHolder.dispose();
    _note.dispose();
    super.dispose();
  }

  void _onNameChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewName = _name.text.trim().isEmpty ? '?' : _name.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa thành viên' : 'Thêm thành viên'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.s16),
          children: [
            Center(
              child: MemberAvatar.large(
                name: previewName,
                // Khi thêm mới, màu được tính từ tên đang gõ nên người dùng
                // thấy ngay avatar của mình sẽ trông thế nào.
                color: _isEditing ? widget.member!.avatarColor : null,
                isSelf: widget.member?.isSelf ?? false,
              ),
            ),
            const SizedBox(height: AppTheme.s24),

            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofocus: !_isEditing,
              decoration: const InputDecoration(
                labelText: 'Tên *',
                hintText: 'Nguyễn Văn An',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Tên không được để trống'
                  : null,
            ),
            const SizedBox(height: AppTheme.s12),

            TextFormField(
              controller: _nickname,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Biệt danh',
                hintText: 'An — tên nhóm thường gọi',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: AppTheme.s12),

            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Số điện thoại',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: AppTheme.s16),

            // Thông tin ngân hàng gập lại vì phần lớn lần thêm người không cần
            // tới nó; chỉ cần khi muốn sinh QR chuyển khoản (SPEC FR-1.2).
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: _showBankSection,
                    onChanged: (value) =>
                        setState(() => _showBankSection = value),
                    title: const Text('Thông tin nhận tiền'),
                    subtitle: const Text('Dùng để chia sẻ khi cần chuyển khoản'),
                    secondary: const Icon(Icons.account_balance_outlined),
                  ),
                  if (_showBankSection)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.s16,
                        0,
                        AppTheme.s16,
                        AppTheme.s16,
                      ),
                      child: Column(
                        children: [
                          // Chọn trong danh sách chứ không gõ tay: QR cần mã
                          // BIN, mà mã BIN thì không gõ ra được từ tên.
                          TextFormField(
                            controller: _bankName,
                            readOnly: true,
                            onTap: _pickBank,
                            decoration: InputDecoration(
                              labelText: 'Ngân hàng',
                              hintText: 'Chạm để chọn',
                              prefixIcon: const Icon(
                                Icons.account_balance_outlined,
                              ),
                              suffixIcon: _bankBin == null
                                  ? const Icon(Icons.arrow_drop_down)
                                  : IconButton(
                                      icon: const Icon(Icons.clear),
                                      tooltip: 'Bỏ chọn ngân hàng',
                                      onPressed: _clearBank,
                                    ),
                            ),
                          ),
                          const SizedBox(height: AppTheme.s12),
                          TextFormField(
                            controller: _bankAccount,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Số tài khoản',
                            ),
                          ),
                          const SizedBox(height: AppTheme.s12),
                          TextFormField(
                            controller: _bankHolder,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Chủ tài khoản',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.s16),

            TextFormField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Ghi chú',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),

            if (_isEditing && !widget.member!.isSelf) ...[
              const SizedBox(height: AppTheme.s16),
              OutlinedButton.icon(
                onPressed: _saving ? null : _setAsSelf,
                icon: const Icon(Icons.star_outline_rounded),
                label: const Text('Đặt người này là "Tôi"'),
              ),
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.s8),
                child: Text(
                  'Thành viên "Tôi" được chọn sẵn làm người trả trước và được '
                  'làm nổi bật trong thống kê.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppTheme.s32),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Lưu thay đổi' : 'Thêm thành viên'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setAsSelf() async {
    setState(() => _saving = true);
    final result = await ref
        .read(membersProvider.notifier)
        .setSelf(widget.member!.id);
    if (!mounted) return;

    setState(() => _saving = false);
    result.when(
      ok: (_) {
        AppSnackBar.success(context, 'Đã đặt ${widget.member!.name} là "Tôi"');
        Navigator.of(context).pop();
      },
      err: (error) => AppSnackBar.error(context, error.message),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(membersProvider.notifier);
    final name = _name.text.trim();

    // Trùng tên chỉ là cảnh báo, không phải lỗi: nhóm có thể thật sự có hai
    // bạn tên "Anh" (SPEC FR-1, quy tắc nghiệp vụ).
    final duplicates = await ref
        .read(membersProvider.notifier)
        .checkDuplicates(name, excludeId: widget.member?.id);
    if (!mounted) return;

    if (duplicates.isNotEmpty) {
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Tên đã tồn tại',
        message: 'Đã có ${duplicates.length == 1 ? 'thành viên' : '${duplicates.length} thành viên'} '
            'tên "${duplicates.first.name}". Vẫn thêm người này?',
        confirmLabel: 'Vẫn thêm',
      );
      if (!mounted || !confirmed) return;
    }

    setState(() => _saving = true);

    final Result<Member> result;
    if (_isEditing) {
      // Dựng bản ghi tường minh chứ không dùng `copyWith`: ở đó mọi trường
      // đều là `giá trị ?? giá trị cũ`, nên xóa trắng một ô rồi lưu lại ra
      // `null` và bị hiểu là "không đổi" — số cũ ở lại mãi.
      final current = widget.member!;
      result = await notifier.save(
        Member(
          id: current.id,
          name: name,
          nameNorm: current.nameNorm,
          nickname: _textOrNull(_nickname),
          phone: _textOrNull(_phone),
          bankName: _textOrNull(_bankName),
          bankBin: _bankBin,
          bankAccount: _textOrNull(_bankAccount),
          bankHolder: _textOrNull(_bankHolder),
          note: _textOrNull(_note),
          avatarColor: current.avatarColor,
          isSelf: current.isSelf,
          isActive: current.isActive,
          createdAt: current.createdAt,
          updatedAt: current.updatedAt,
          deletedAt: current.deletedAt,
        ),
      );
    } else {
      result = await notifier.create(
        name: name,
        nickname: _textOrNull(_nickname),
        phone: _textOrNull(_phone),
        bankName: _textOrNull(_bankName),
        bankBin: _bankBin,
        bankAccount: _textOrNull(_bankAccount),
        bankHolder: _textOrNull(_bankHolder),
        note: _textOrNull(_note),
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);

    result.when(
      ok: (member) {
        AppSnackBar.success(
          context,
          _isEditing ? 'Đã lưu ${member.name}' : 'Đã thêm ${member.name}',
        );
        Navigator.of(context).pop();
      },
      err: (error) => AppSnackBar.error(context, error.message),
    );
  }

  Future<void> _pickBank() async {
    final bank = await BankPickerSheet.show(context);
    if (bank == null) return;

    setState(() {
      _bankBin = bank.bin;
      _bankName.text = bank.shortName;
    });
  }

  void _clearBank() => setState(() {
    _bankBin = null;
    _bankName.clear();
  });

  /// Chuỗi rỗng được lưu thành `null`, để cột cho phép NULL không chứa chuỗi
  /// rỗng — hai thứ đó khác nhau khi hiển thị.
  String? _textOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }
}
