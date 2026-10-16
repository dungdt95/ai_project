import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../models/location.dart';

class LocationSelector extends StatelessWidget {
  final List<Location> locations;
  final int? currentLocationId;
  final ValueChanged<int> onChanged;
  final VoidCallback onAddNew;

  const LocationSelector({
    super.key,
    required this.locations,
    required this.currentLocationId,
    required this.onChanged,
    required this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    final current = currentLocationId == null
        ? null
        : locations.where((l) => l.id == currentLocationId).firstOrNull;

    return PopupMenuButton<int>(
      tooltip: 'Chọn địa điểm',
      offset: const Offset(0, 40),
      onSelected: (id) {
        if (id == -1) {
          onAddNew();
        } else {
          onChanged(id);
        }
      },
      itemBuilder: (_) => [
        for (final loc in locations)
          PopupMenuItem<int>(
            value: loc.id,
            child: Row(
              children: [
                Icon(
                  loc.id == currentLocationId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 18,
                  color: loc.id == currentLocationId
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(loc.name)),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<int>(
          value: -1,
          child: Row(
            children: [
              Icon(Icons.add_location_alt_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Thêm địa điểm', style: TextStyle(color: AppColors.primary)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_outlined, size: 16, color: Colors.white),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                current?.name ?? '—',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
