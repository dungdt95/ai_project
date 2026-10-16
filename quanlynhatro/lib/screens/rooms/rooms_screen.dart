import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../widgets/location_selector.dart';
import '../../widgets/room_card.dart';
import '../locations/location_form_screen.dart';
import 'room_detail_screen.dart';
import 'room_form_screen.dart';

class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý phòng'),
        actions: [
          LocationSelector(
            locations: app.locations,
            currentLocationId: app.currentLocationId,
            onChanged: (id) => context.read<AppState>().switchLocation(id),
            onAddNew: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const LocationFormScreen(),
            )),
          ),
          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RoomFormScreen(
                  locationId: app.currentLocationId,
                ),
              ));
              if (context.mounted) await context.read<AppState>().reloadRooms();
            },
            icon: const Icon(Icons.add),
            tooltip: 'Thêm phòng',
          ),
        ],
      ),
      body: app.rooms.isEmpty
          ? const Center(child: Text('Chưa có phòng nào.'))
          : RefreshIndicator(
              onRefresh: () => context.read<AppState>().reloadRooms(),
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.95,
                ),
                itemCount: app.rooms.length,
                itemBuilder: (context, idx) {
                  final room = app.rooms[idx];
                  final tenant = app.tenantOf(room);
                  return RoomCard(
                    room: room,
                    tenant: tenant,
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => RoomDetailScreen(room: room),
                      ));
                      if (context.mounted) {
                        await context.read<AppState>().reloadRooms();
                      }
                    },
                  );
                },
              ),
            ),
    );
  }
}
