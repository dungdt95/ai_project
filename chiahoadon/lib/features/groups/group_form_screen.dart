import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/result.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/member_avatar.dart';
import '../../domain/models/member_group.dart';
import '../members/member_picker_sheet.dart';
import '../members/members_provider.dart';
import 'groups_provider.dart';

/// S09 — Thêm hoặc sửa nhóm (SPEC FR-2.1, FR-2.2).
class GroupFormScreen extends ConsumerStatefulWidget {
  const GroupFormScreen({super.key, this.group});

  /// `null` nghĩa là thêm mới.
  final MemberGroup? group;

  static Future<void> push(BuildContext context, {MemberGroup? group}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => GroupFormScreen(group: group),
        ),
      );

  @override
  ConsumerState<GroupFormScreen> createState() => _GroupFormScreenState();
}

class _GroupFormScreenState extends ConsumerState<GroupFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late Set<String> _memberIds;

  bool _saving = false;

  bool get _isEditing => widget.group != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.group?.name ?? '');
    _description = TextEditingController(
      text: widget.group?.description ?? '',
    );
    _memberIds = {...?widget.group?.memberIds};
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allMembers = ref.watch(selectableMembersProvider);
    final selected = allMembers
        .where((member) => _memberIds.contains(member.id))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Sửa nhóm' : 'Tạo nhóm')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.s16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              autofocus: !_isEditing,
              decoration: const InputDecoration(
                labelText: 'Tên nhóm *',
                hintText: 'Team Dev, Phòng 302...',
                prefixIcon: Icon(Icons.group_outlined),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Tên nhóm không được để trống'
                  : null,
            ),
            const SizedBox(height: AppTheme.s12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Mô tả',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: AppTheme.s24),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Thành viên (${_memberIds.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickMembers,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(_memberIds.isEmpty ? 'Chọn' : 'Sửa'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.s8),

            if (selected.isEmpty)
              Card(
                child: InkWell(
                  onTap: _pickMembers,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.s24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_add_alt,
                          size: 32,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: AppTheme.s8),
                        Text(
                          'Chạm để chọn thành viên',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (final member in selected)
                      ListTile(
                        leading: MemberAvatar(
                          name: member.displayName,
                          color: member.avatarColor,
                          isSelf: member.isSelf,
                        ),
                        title: Text(member.displayName),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          tooltip: 'Bỏ khỏi nhóm',
                          onPressed: () =>
                              setState(() => _memberIds.remove(member.id)),
                        ),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: AppTheme.s16),
            Text(
              'Nhóm chỉ là lối tắt để chọn nhanh người tham gia. Xóa nhóm '
              'không ảnh hưởng các hóa đơn đã lưu.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: AppTheme.s32),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Lưu thay đổi' : 'Tạo nhóm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMembers() async {
    final picked = await MemberPickerSheet.show(
      context,
      initialSelection: _memberIds,
      title: 'Thành viên của nhóm',
      // Không hiện nút chọn theo nhóm khác: đang tạo nhóm thì chọn nhóm khác
      // chỉ gây lẫn.
      showGroupShortcuts: false,
    );
    if (picked == null || !mounted) return;

    setState(() => _memberIds = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_memberIds.isEmpty) {
      AppSnackBar.error(context, 'Nhóm cần có ít nhất một thành viên.');
      return;
    }

    setState(() => _saving = true);

    final notifier = ref.read(groupsProvider.notifier);
    final description = _description.text.trim();

    final Result<MemberGroup> result;
    if (_isEditing) {
      result = await notifier.save(
        widget.group!.copyWith(
          name: _name.text.trim(),
          description: description.isEmpty ? null : description,
          memberIds: _memberIds.toList(),
        ),
      );
    } else {
      result = await notifier.create(
        name: _name.text.trim(),
        memberIds: _memberIds.toList(),
        description: description.isEmpty ? null : description,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);

    result.when(
      ok: (group) {
        AppSnackBar.success(
          context,
          _isEditing ? 'Đã lưu nhóm ${group.name}' : 'Đã tạo nhóm ${group.name}',
        );
        Navigator.of(context).pop();
      },
      err: (error) => AppSnackBar.error(context, error.message),
    );
  }
}
