import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../models/invoice.dart';
import '../../models/room.dart';
import '../../models/tenant.dart';
import '../../providers/app_state.dart';
import '../../utils/format_utils.dart';
import '../../widgets/location_selector.dart';
import '../../widgets/room_card.dart';
import '../invoices/invoice_create_screen.dart';
import '../locations/location_form_screen.dart';
import '../meter/meter_reading_screen.dart';
import '../rooms/room_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _month;
  late int _year;
  List<Invoice> _monthInvoices = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMonth());
  }

  Future<void> _loadMonth() async {
    final app = context.read<AppState>();
    final list = await app.invoicesOfMonth(_month, _year);
    if (mounted) setState(() => _monthInvoices = list);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final totalRevenue = _monthInvoices.fold<int>(0, (s, i) => s + i.total);
    final paidCount = _monthInvoices.where((i) => i.isPaid).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        actions: [
          LocationSelector(
            locations: app.locations,
            currentLocationId: app.currentLocationId,
            onChanged: (id) async {
              await app.switchLocation(id);
              await _loadMonth();
            },
            onAddNew: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const LocationFormScreen(),
              ));
              await _loadMonth();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await app.loadAll();
              await _loadMonth();
            },
          ),
        ],
      ),
      body: app.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await app.loadAll();
                await _loadMonth();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(app),
                  const SizedBox(height: 16),
                  _buildSummaryCard(totalRevenue, paidCount, app.rooms.length),
                  const SizedBox(height: 16),
                  _buildAlerts(app),
                  const SizedBox(height: 16),
                  _buildQuickActions(),
                  const SizedBox(height: 16),
                  Text('Danh sách phòng (${app.rooms.length})',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _buildRoomGrid(app),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(AppState app) {
    final building = app.currentLocation?.name ?? AppConstants.defaultBuildingName;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(building,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(FormatUtils.monthName(_month, _year),
              style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(int total, int paid, int totalRooms) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tổng thu tháng này',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text('${FormatUtils.money(total)}đ',
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
            const SizedBox(height: 12),
            Row(
              children: [
                _statChip('Hóa đơn',
                    '${_monthInvoices.length}/$totalRooms', Icons.receipt_long),
                const SizedBox(width: 8),
                _statChip('Đã thu', '$paid', Icons.check_circle,
                    color: AppColors.statusOccupied),
                const SizedBox(width: 8),
                _statChip('Chưa thu',
                    '${_monthInvoices.length - paid}', Icons.pending,
                    color: AppColors.statusExpiring),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, IconData icon, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color ?? AppColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlerts(AppState app) {
    final expiringTenants =
        app.currentTenantByRoom.values.where((t) => t.isExpiring).toList();
    final expiredTenants =
        app.currentTenantByRoom.values.where((t) => t.isExpired).toList();

    if (expiringTenants.isEmpty && expiredTenants.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      color: const Color(0xFFFFF8E1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100)),
                SizedBox(width: 8),
                Text('Cảnh báo hợp đồng',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            for (final t in expiredTenants)
              _alertLine(app, t, expired: true),
            for (final t in expiringTenants) _alertLine(app, t),
          ],
        ),
      ),
    );
  }

  Widget _alertLine(AppState app, Tenant t, {bool expired = false}) {
    final room = app.rooms.firstWhere(
      (r) => r.id == t.roomId,
      orElse: () => Room(roomNumber: '?', baseRent: 0),
    );
    final days = t.daysToExpire();
    final msg = expired
        ? 'HĐ đã hết hạn ${days != null ? '${-days} ngày trước' : ''}'
        : 'HĐ còn $days ngày';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(expired ? Icons.error : Icons.access_time,
              size: 16,
              color: expired ? AppColors.statusExpired : Colors.orange),
          const SizedBox(width: 6),
          Expanded(
              child: Text('Phòng ${room.roomNumber} - ${t.fullName}: $msg')),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _openMeterReading,
            icon: const Icon(Icons.electric_meter),
            label: const Text('Ghi số điện/nước'),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.primary),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _openCreateInvoice,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Tạo HĐ riêng'),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
      ],
    );
  }

  Future<void> _openMeterReading() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MeterReadingScreen(month: _month, year: _year),
    ));
    await _loadMonth();
  }

  Widget _buildRoomGrid(AppState app) {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      childAspectRatio: 0.95,
      physics: const NeverScrollableScrollPhysics(),
      children: app.rooms.map((room) {
        final tenant = app.tenantOf(room);
        final invoice =
            _monthInvoices.where((i) => i.roomId == room.id).cast<Invoice?>().firstWhere(
                  (i) => true,
                  orElse: () => null,
                );
        return RoomCard(
          room: room,
          tenant: tenant,
          invoice: invoice,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room)),
            );
            if (mounted) {
              await app.reloadRooms();
              await _loadMonth();
            }
          },
        );
      }).toList(),
    );
  }

  Future<void> _openCreateInvoice() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => InvoiceCreateScreen(month: _month, year: _year),
    ));
    await _loadMonth();
  }
}
