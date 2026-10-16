import 'package:flutter/material.dart';

const Map<String, IconData> kCategoryIcons = {
  'restaurant': Icons.restaurant,
  'directions_car': Icons.directions_car,
  'shopping_bag': Icons.shopping_bag,
  'receipt': Icons.receipt,
  'movie': Icons.movie,
  'local_hospital': Icons.local_hospital,
  'school': Icons.school,
  'more_horiz': Icons.more_horiz,
  'payments': Icons.payments,
  'card_giftcard': Icons.card_giftcard,
  'trending_up': Icons.trending_up,
  'redeem': Icons.redeem,
  'category': Icons.category,
  'home': Icons.home,
  'phone': Icons.phone,
  'wifi': Icons.wifi,
  'sports': Icons.sports,
  'pets': Icons.pets,
  'flight': Icons.flight,
  'hotel': Icons.hotel,
  'coffee': Icons.coffee,
  'fitness_center': Icons.fitness_center,
  'book': Icons.book,
  'music_note': Icons.music_note,
  'games': Icons.games,
  'child_care': Icons.child_care,
  'work': Icons.work,
  'savings': Icons.savings,
  'attach_money': Icons.attach_money,
  'account_balance': Icons.account_balance,
};

IconData iconFromString(String? name) =>
    kCategoryIcons[name] ?? Icons.category;
