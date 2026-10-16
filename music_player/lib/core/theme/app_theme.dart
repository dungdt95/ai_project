import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFF1DB954),
      secondary: const Color(0xFF1DB954),
      surface: const Color(0xFF121212),
      background: const Color(0xFF121212),
      onBackground: Colors.white,
      onSurface: Colors.white,
      surfaceVariant: const Color(0xFF282828),
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF282828),
    dividerColor: Colors.white12,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF121212),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Colors.white70,
      textColor: Colors.white,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF181818),
      selectedItemColor: Color(0xFF1DB954),
      unselectedItemColor: Colors.white54,
    ),
  );
}
