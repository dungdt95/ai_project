import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../models/invoice.dart';
import '../models/room.dart';
import '../models/tenant.dart';
import '../utils/format_utils.dart';

class RoomCard extends StatelessWidget {
  final Room room;
  final Tenant? tenant;
  final Invoice? invoice;
  final VoidCallback? onTap;

  const RoomCard({
    super.key,
    required this.room,
    this.tenant,
    this.invoice,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel;
    if (!room.isOccupied) {
      statusColor = AppColors.statusVacant;
      statusLabel = 'Trống';
    } else if (tenant?.isExpired ?? false) {
      statusColor = AppColors.statusExpired;
      statusLabel = 'HĐ hết hạn';
    } else if (tenant?.isExpiring ?? false) {
      statusColor = AppColors.statusExpiring;
      statusLabel = 'Sắp hết HĐ';
    } else {
      statusColor = AppColors.statusOccupied;
      statusLabel = 'Đang thuê';
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(room.roomNumber,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (invoice != null)
                    Icon(
                      invoice!.isPaid
                          ? Icons.check_circle
                          : Icons.receipt_long,
                      size: 16,
                      color: invoice!.isPaid
                          ? AppColors.statusOccupied
                          : Colors.grey,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                tenant?.fullName ?? 'Trống',
                style: TextStyle(
                  fontSize: 13,
                  color: tenant != null
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Text('${FormatUtils.money(room.baseRent)}đ',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(statusLabel,
                  style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
