import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/app_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/money_field.dart';
import '../../../data/data_providers.dart';
import '../../../domain/models/bill.dart';
import '../../../domain/models/bill_item.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/expense_category.dart';
import '../../../domain/models/member.dart';
import '../../../domain/split/split_engine.dart';
import '../../../domain/split/split_result.dart';
import '../../groups/groups_provider.dart';
import '../../members/member_picker_sheet.dart';
import '../../members/members_provider.dart';
import '../bills_provider.dart';
import 'bill_form_state.dart';
import 'bill_image_picker.dart';
import 'item_editor.dart';
import 'split_params_editor.dart';
import 'split_preview_card.dart';
import 'surcharge_panel.dart';

/// S03 — Wizard nhập hóa đơn ba bước (PLAN §5.3).
///
/// Trạng thái form nằm trong `State` của widget chứ không trong Riverpod.
/// `BillFormState` là lớp bất biến với các phương thức thuần, nên phần logic
/// vẫn test được độc lập; còn vòng đời thì đơn giản hơn hẳn — không phải lo
/// provider bị dựng lại giữa chừng và xóa mất thứ người dùng đang gõ.
class BillFormScreen extends ConsumerStatefulWidget {
  const BillFormScreen({super.key, this.bill});

  /// `null` nghĩa là tạo mới.
  final Bill? bill;

  /// Khóa của danh sách cuộn ở bước "Chia tiền", dùng trong widget test.
  static const String splitStepListKey = 'split-step-list';

  static Future<void> push(BuildContext context, {Bill? bill}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => BillFormScreen(bill: bill),
        ),
      );

  @override
  ConsumerState<BillFormScreen> createState() => _BillFormScreenState();
}

class _BillFormScreenState extends ConsumerState<BillFormScreen> {
  late final PageController _pageController;
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  final _totalController = TextEditingController();

  late BillFormState _form;
  Timer? _draftTimer;
  int _step = 0;
  bool _saving = false;
  bool _dirty = false;

  bool get _isEditing => widget.bill != null;

  bool get _isDraft => widget.bill?.status == BillStatus.draft;

  /// Nháp không phải "sửa": nó là việc nhập dở đang được nhặt lại.
  String get _screenTitle => switch ((_isEditing, _isDraft)) {
    (_, true) => 'Tiếp tục nháp',
    (true, _) => 'Sửa hóa đơn',
    _ => 'Tạo hóa đơn',
  };

  @override
  void initState() {
    super.initState();

    final bill = widget.bill;
    if (bill != null) {
      _form = BillFormState.edit(bill);
      _titleController.text = _form.title;
      _noteController.text = _form.note;
      _totalController.text = _form.manualTotal == 0
          ? ''
          : _form.manualTotal.toVndPlain();
      // Sửa hóa đơn thì mở thẳng bước cuối, vì phần lớn lần sửa là sửa số
      // tiền. Nhưng nháp thì mở lại từ đầu: người dùng đang nhập dở ở bước
      // nào không rõ, và nháp thường còn thiếu cả tên lẫn người tham gia.
      _step = bill.status == BillStatus.draft ? 0 : 2;
    } else {
      _form = BillFormState.create(date: DateTime.now());
    }

    // `initialPage` phải khớp `_step`, nếu không thanh bước và trang đang hiện
    // sẽ nói hai điều khác nhau.
    _pageController = PageController(initialPage: _step);
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _pageController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  /// Áp giá trị mặc định đọc từ DB vào hóa đơn mới.
  ///
  /// Chỉ chạy một lần, và chỉ khi người dùng chưa đụng vào gì — nếu không thì
  /// dữ liệu tới muộn sẽ ghi đè lên thứ họ vừa chọn.
  void _applyDefaults(Member? self, int roundingUnit) {
    if (_isEditing || _dirty) return;
    if (self == null) return;
    if (_form.payerId == self.id && _form.roundingUnit == roundingUnit) return;

    _form = _form.copyWith(
      payerId: _form.payerId ?? self.id,
      participantIds: _form.participantIds.isEmpty
          ? [self.id]
          : _form.participantIds,
      roundingUnit: roundingUnit,
    );
  }

  void _update(BillFormState next) {
    setState(() {
      _form = next;
      _dirty = true;
    });
    _scheduleDraftSave();
  }

  /// Tự lưu nháp sau mỗi khoảng lặng (NFR-10).
  ///
  /// Hẹn lại giờ sau mỗi lần gõ, nên chỉ ghi khi người dùng dừng tay — tránh
  /// ghi DB theo từng ký tự.
  void _scheduleDraftSave() {
    if (_isEditing) return;

    _draftTimer?.cancel();
    _draftTimer = Timer(AppConstants.draftAutoSaveInterval, () {
      if (!mounted || !_form.hasParticipants) return;
      unawaited(
        ref
            .read(billListProvider.notifier)
            .saveDraft(_form.toDraft(_memberNames())),
      );
    });
  }

  Map<String, String> _memberNames() {
    final members = ref.read(membersProvider).value ?? const <Member>[];
    return {for (final member in members) member.id: member.name};
  }

  @override
  Widget build(BuildContext context) {
    final self = ref.watch(selfMemberProvider).value;
    final defaultUnit = ref.watch(defaultRoundingUnitProvider).value ?? 1000;
    _applyDefaults(self, defaultUnit);

    final allMembers = ref.watch(membersProvider).value ?? const <Member>[];
    final byId = {for (final member in allMembers) member.id: member};

    // Trái tim của màn hình này: tính lại ngay trong frame, không async.
    final preview = computeSplit(_form.toSplitInput());

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await ConfirmDialog.show(
          context,
          title: 'Thoát mà không lưu?',
          message: _isEditing
              ? 'Các thay đổi sẽ bị bỏ.'
              : 'Hóa đơn đang nhập dở sẽ được giữ làm nháp.',
          confirmLabel: 'Thoát',
          isDestructive: true,
        );
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_screenTitle),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: _StepIndicator(
              step: _step,
              onTap: (index) => _goToStep(index),
            ),
          ),
        ),
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _step = index),
          children: [
            _StepInfo(
              form: _form,
              titleController: _titleController,
              noteController: _noteController,
              onChanged: _update,
            ),
            _StepParticipants(
              form: _form,
              members: byId,
              onChanged: _update,
            ),
            _StepSplit(
              form: _form,
              members: byId,
              preview: preview,
              totalController: _totalController,
              onChanged: _update,
            ),
          ],
        ),
        bottomNavigationBar: _BottomBar(
          step: _step,
          form: _form,
          preview: preview,
          saving: _saving,
          isEditing: _isEditing,
          onBack: () => _goToStep(_step - 1),
          onNext: () => _goToStep(_step + 1),
          onSave: () => _save(preview),
        ),
      ),
    );
  }

  void _goToStep(int index) {
    if (index < 0 || index > 2) return;
    unawaited(
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      ),
    );
  }

  Future<void> _save(SplitResult preview) async {
    final reason = _form.blockingReason;
    if (reason != null) {
      AppSnackBar.error(context, reason);
      return;
    }
    if (!preview.isValid) {
      AppSnackBar.error(context, preview.errors.first.message);
      return;
    }

    // Sửa hóa đơn đã có người trả thì cảnh báo trước (SPEC FR-3.13).
    if (_isEditing && widget.bill!.totalSettled > 0) {
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Hóa đơn đã có người trả',
        message: 'Sửa hóa đơn sẽ tính lại phần của mọi người. Số tiền đã ghi '
            'nhận là đã trả vẫn được giữ, nên có thể thành trả thừa hoặc '
            'thiếu.',
        confirmLabel: 'Vẫn sửa',
      );
      if (!mounted || !confirmed) return;
    }

    _draftTimer?.cancel();
    setState(() => _saving = true);

    final result = await ref
        .read(billListProvider.notifier)
        .save(_form.toBill(preview, _memberNames()));

    if (!mounted) return;
    setState(() => _saving = false);

    result.when(
      ok: (bill) {
        _dirty = false;
        AppSnackBar.success(
          context,
          _isEditing ? 'Đã lưu "${bill.title}"' : 'Đã tạo "${bill.title}"',
        );
        Navigator.of(context).pop();
      },
      err: (error) => AppSnackBar.error(context, error.message),
    );
  }
}

// ───────────────────────────── bước 1 ─────────────────────────────

class _StepInfo extends ConsumerWidget {
  const _StepInfo({
    required this.form,
    required this.titleController,
    required this.noteController,
    required this.onChanged,
  });

  final BillFormState form;
  final TextEditingController titleController;
  final TextEditingController noteController;
  final ValueChanged<BillFormState> onChanged;

  /// Chọn hoặc bỏ chọn một danh mục, và điền tên hóa đơn theo nó.
  ///
  /// Chỉ ghi đè tên khi tên đang trống hoặc đang chính là tên của danh mục
  /// trước đó — tức là tên do máy điền. Người dùng đã gõ tên riêng thì đổi
  /// danh mục không được xóa công của họ.
  void _selectCategory(
    ExpenseCategory category,
    bool selected,
    List<ExpenseCategory> categories,
  ) {
    ExpenseCategory? previous;
    for (final each in categories) {
      if (each.id == form.categoryId) previous = each;
    }

    final typed = titleController.text.trim();
    final titleIsAuto = typed.isEmpty || typed == previous?.name;

    var next = form.withCategory(selected ? category.id : null);

    if (titleIsAuto) {
      // Bỏ chọn thì xóa luôn cái tên do nó điền, để không còn tên thừa của
      // một danh mục không còn được chọn.
      final title = selected ? category.name : '';
      titleController.text = title;
      next = next.withTitle(title);
    }

    onChanged(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).value ?? const [];

    return ListView(
      padding: const EdgeInsets.all(AppTheme.s16),
      children: [
        // Danh mục đứng trước ô tên vì đây mới là thao tác chính: chọn một
        // danh mục là hóa đơn đã có tên, không phải gõ gì thêm.
        Text(
          'Danh mục',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppTheme.s8),
        Wrap(
          spacing: AppTheme.s8,
          runSpacing: AppTheme.s8,
          children: [
            for (final category in categories)
              FilterChip(
                label: Text('${category.icon ?? ''} ${category.name}'.trim()),
                selected: form.categoryId == category.id,
                onSelected: (selected) =>
                    _selectCategory(category, selected, categories),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.s16),

        TextField(
          controller: titleController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Tên hóa đơn *',
            hintText: 'Chọn danh mục hoặc gõ tên riêng',
            prefixIcon: Icon(Icons.receipt_long_outlined),
            helperText: 'Chọn danh mục là tự có tên',
          ),
          onChanged: (value) => onChanged(form.withTitle(value)),
        ),
        const SizedBox(height: AppTheme.s12),

        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          ),
          tileColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          leading: const Icon(Icons.calendar_today_outlined),
          title: const Text('Ngày'),
          trailing: Text(
            DateFormatter.short(form.date),
            style: MoneyTextStyle.small,
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: form.date,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) onChanged(form.withDate(picked));
          },
        ),
        const SizedBox(height: AppTheme.s16),

        TextField(
          controller: noteController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Ghi chú',
            prefixIcon: Icon(Icons.notes_outlined),
            alignLabelWithHint: true,
          ),
          onChanged: (value) => onChanged(form.withNote(value)),
        ),
        const SizedBox(height: AppTheme.s16),

        BillImagePicker(
          imagePath: form.imagePath,
          onChanged: (path) => onChanged(
            form.copyWith(imagePath: path, clearImage: path == null),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────── bước 2 ─────────────────────────────

class _StepParticipants extends ConsumerWidget {
  const _StepParticipants({
    required this.form,
    required this.members,
    required this.onChanged,
  });

  final BillFormState form;
  final Map<String, Member> members;
  final ValueChanged<BillFormState> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectable = ref.watch(selectableMembersProvider);
    final groups = ref.watch(groupsProvider).value ?? const [];

    return ListView(
      padding: const EdgeInsets.all(AppTheme.s16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Người tham gia (${form.participantCount})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final picked = await MemberPickerSheet.show(
                  context,
                  initialSelection: form.participantIds.toSet(),
                  title: 'Ai cùng chia hóa đơn này?',
                );
                if (picked != null) onChanged(form.withParticipants(picked));
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Chọn'),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.s8),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ActionChip(
                avatar: const Icon(Icons.done_all, size: 18),
                label: const Text('Tất cả'),
                onPressed: () => onChanged(
                  form.withParticipants(
                    selectable.map((member) => member.id).toSet(),
                  ),
                ),
              ),
              for (final group in groups) ...[
                const SizedBox(width: AppTheme.s8),
                ActionChip(
                  avatar: const Icon(Icons.group, size: 18),
                  label: Text('${group.name} (${group.memberCount})'),
                  onPressed: () => onChanged(
                    form.withGroup(
                      group.id,
                      memberIds: group.memberIds.toSet(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppTheme.s12),

        if (form.participantIds.isEmpty)
          const EmptyState(
            icon: Icons.group_outlined,
            title: 'Chưa chọn ai',
            message: 'Chọn những người cùng chia hóa đơn này.',
          )
        else
          Card(
            child: Column(
              children: [
                for (final id in form.participantIds)
                  ListTile(
                    leading: MemberAvatar(
                      name: members[id]?.displayName ?? '?',
                      color: members[id]?.avatarColor,
                      isSelf: members[id]?.isSelf ?? false,
                    ),
                    title: Text(members[id]?.displayName ?? '?'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      tooltip: 'Bỏ khỏi hóa đơn',
                      onPressed: () => onChanged(form.toggleParticipant(id)),
                    ),
                  ),
              ],
            ),
          ),

        const SizedBox(height: AppTheme.s24),
        Text(
          'Người trả trước',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.s4),
        Text(
          'Người đã ứng tiền trả cho cả nhóm. Không bắt buộc phải là người '
          'tham gia ăn.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppTheme.s8),
        Wrap(
          spacing: AppTheme.s8,
          runSpacing: AppTheme.s8,
          children: [
            for (final member in selectable)
              ChoiceChip(
                avatar: MemberAvatar.small(
                  name: member.displayName,
                  color: member.avatarColor,
                ),
                label: Text(member.displayName),
                selected: form.payerId == member.id,
                onSelected: (selected) =>
                    onChanged(form.withPayer(selected ? member.id : null)),
              ),
          ],
        ),
      ],
    );
  }
}

// ───────────────────────────── bước 3 ─────────────────────────────

class _StepSplit extends StatelessWidget {
  const _StepSplit({
    required this.form,
    required this.members,
    required this.preview,
    required this.totalController,
    required this.onChanged,
  });

  final BillFormState form;
  final Map<String, Member> members;
  final SplitResult preview;
  final TextEditingController totalController;
  final ValueChanged<BillFormState> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      key: const Key(BillFormScreen.splitStepListKey),
      padding: const EdgeInsets.all(AppTheme.s16),
      children: [
        Text('Cách chia', style: theme.textTheme.labelLarge),
        const SizedBox(height: AppTheme.s8),
        Wrap(
          spacing: AppTheme.s8,
          runSpacing: AppTheme.s8,
          children: [
            for (final type in SplitType.values)
              ChoiceChip(
                label: Text(type.label),
                selected: form.splitType == type,
                onSelected: (_) => _changeSplitType(context, type),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.s24),

        if (form.splitType == SplitType.itemized)
          _ItemList(form: form, members: members, onChanged: onChanged)
        else ...[
          Text('Tổng tiền', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppTheme.s8),
          MoneyField(
            controller: totalController,
            large: true,
            autofocus: form.manualTotal == 0,
            onChanged: (value) => onChanged(form.withTotal(value)),
          ),
        ],

        if (form.splitType != SplitType.equal &&
            form.splitType != SplitType.itemized) ...[
          const SizedBox(height: AppTheme.s24),
          SplitParamsEditor(
            form: form,
            members: members,
            onChanged: onChanged,
          ),
        ],

        const SizedBox(height: AppTheme.s16),
        SurchargePanel(form: form, preview: preview, onChanged: onChanged),
        const SizedBox(height: AppTheme.s12),
        RoundingPanel(form: form, preview: preview, onChanged: onChanged),
        const SizedBox(height: AppTheme.s24),

        SplitPreviewCard(
          result: preview,
          members: members,
          payerId: form.payerId,
        ),
        const SizedBox(height: AppTheme.s32),
      ],
    );
  }

  /// Đổi kiểu chia, hỏi xác nhận nếu việc đó làm mất dữ liệu đã nhập.
  ///
  /// Mỗi kiểu chia có tham số riêng (%, số phần, số tiền chỉ định, danh sách
  /// món). Đổi kiểu là những tham số đó không còn nghĩa, nên phải báo trước
  /// chứ không im lặng bỏ đi (SPEC FR-4, quy tắc chuyển đổi).
  Future<void> _changeSplitType(BuildContext context, SplitType type) async {
    if (type == form.splitType) return;

    final losesItems =
        form.splitType == SplitType.itemized && form.items.isNotEmpty;
    final losesParams =
        (form.splitType == SplitType.percentage && form.totalPercentBp > 0) ||
        (form.splitType == SplitType.exact && form.totalExactAmount > 0);

    if (losesItems || losesParams) {
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Đổi sang ${type.label}?',
        message: losesItems
            ? 'Danh sách ${form.items.length} món sẽ không còn được dùng để '
                  'chia. Bạn vẫn quay lại được bằng cách chọn lại "Theo món".'
            : 'Các số đã nhập cho cách chia hiện tại sẽ không còn được dùng.',
        confirmLabel: 'Đổi',
      );
      if (!confirmed) return;
    }

    onChanged(form.withSplitType(type));
  }
}

/// Danh sách món ở bước chia tiền (SPEC FR-3.6, FR-3.7, FR-4.2).
class _ItemList extends StatelessWidget {
  const _ItemList({
    required this.form,
    required this.members,
    required this.onChanged,
  });

  final BillFormState form;
  final Map<String, Member> members;
  final ValueChanged<BillFormState> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final participants = [
      for (final id in form.participantIds)
        if (members[id] != null) members[id]!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Các món (${form.items.length})',
                style: theme.textTheme.labelLarge,
              ),
            ),
            if (form.items.isNotEmpty)
              Text(
                'Tạm tính ${form.subtotal.toVnd()}',
                style: MoneyTextStyle.small.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.s8),

        if (form.items.isEmpty)
          Card(
            child: InkWell(
              onTap: () => _addItem(context, participants),
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.s24),
                child: Column(
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 32,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: AppTheme.s8),
                    Text(
                      'Chạm để thêm món đầu tiên',
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
                for (final item in form.items)
                  BillItemTile(
                    item: item,
                    members: members,
                    participantCount: form.participantCount,
                    onTap: () => _editItem(context, participants, item),
                    onDelete: () => onChanged(form.removeItem(item.id)),
                  ),
              ],
            ),
          ),

        const SizedBox(height: AppTheme.s12),
        OutlinedButton.icon(
          onPressed: () => _addItem(context, participants),
          icon: const Icon(Icons.add),
          label: const Text('Thêm món'),
        ),
      ],
    );
  }

  Future<void> _addItem(
    BuildContext context,
    List<Member> participants,
  ) async {
    final item = await ItemEditorSheet.show(
      context,
      participants: participants,
    );
    if (item != null) onChanged(form.addItem(item));
  }

  Future<void> _editItem(
    BuildContext context,
    List<Member> participants,
    BillItem item,
  ) async {
    final edited = await ItemEditorSheet.show(
      context,
      participants: participants,
      item: item,
    );
    if (edited != null) onChanged(form.updateItem(edited));
  }
}

// ──────────────────────── khung và thanh dưới ────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step, required this.onTap});

  static const List<String> _labels = ['Thông tin', 'Người', 'Chia tiền'];

  final int step;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.s16,
        0,
        AppTheme.s16,
        AppTheme.s8,
      ),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: Column(
                  children: [
                    Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= step
                            ? scheme.primary
                            : scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: AppTheme.s4),
                    Text(
                      _labels[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: i == step
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: i <= step
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.step,
    required this.form,
    required this.preview,
    required this.saving,
    required this.isEditing,
    required this.onBack,
    required this.onNext,
    required this.onSave,
  });

  final int step;
  final BillFormState form;
  final SplitResult preview;
  final bool saving;
  final bool isEditing;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = step == 2;
    final reason = form.blockingReason;

    return SafeArea(
      minimum: const EdgeInsets.all(AppTheme.s16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLast && reason != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.s8),
              child: Text(
                reason,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          Row(
            children: [
              if (step > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: saving ? null : onBack,
                    child: const Text('Quay lại'),
                  ),
                ),
                const SizedBox(width: AppTheme.s12),
              ],
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: saving ? null : (isLast ? onSave : onNext),
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          isLast
                              ? (isEditing ? 'Lưu thay đổi' : 'Tạo hóa đơn')
                              : 'Tiếp tục',
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
