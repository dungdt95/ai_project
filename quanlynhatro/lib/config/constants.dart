import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Quản Lý Nhà Trọ';
  static const String appVersion = '1.0.0';

  // Default building info
  static const String defaultBuildingName = 'Nhà trọ 37 Đại Linh';
  static const String defaultOwnerName = 'Cô Huyền';
  static const String defaultOwnerPhone = '0975485428';
  static const String defaultBankAccount = '658746';
  static const String defaultBankName = 'ACB';
  static const String defaultTransferTemplate = 'Phòng [PHONG] nhà 37 Đại Linh';
  static const int defaultElecPrice = 3500;
  static const int defaultWaterPrice = 32000;

  // Settings keys
  static const String keyBuildingName = 'building_name';
  static const String keyBuildingAddress = 'building_address';
  static const String keyOwnerName = 'owner_name';
  static const String keyOwnerPhone = 'owner_phone';
  static const String keyBankAccount = 'bank_account';
  static const String keyBankName = 'bank_name';
  static const String keyBankHolder = 'bank_holder';
  static const String keyTransferTemplate = 'transfer_template';
  static const String keyElecPrice = 'elec_price';
  static const String keyWaterPrice = 'water_price';
  static const String keyInvoiceFooter = 'invoice_footer';
}

class AppColors {
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color secondary = Color(0xFF2E7D32);
  static const Color accent = Color(0xFFFFA726);

  static const Color statusOccupied = Color(0xFF43A047); // green
  static const Color statusVacant = Color(0xFFE53935); // red
  static const Color statusExpiring = Color(0xFFFFB300); // yellow
  static const Color statusExpired = Color(0xFFD32F2F); // dark red

  static const Color bgLight = Color(0xFFF5F7FA);
  static const Color cardLight = Colors.white;
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
}
