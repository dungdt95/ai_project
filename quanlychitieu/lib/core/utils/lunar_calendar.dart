// Vietnamese lunar calendar conversion (theo thuật toán Hồ Ngọc Đức).
// Tham khảo: https://www.informatik.uni-leipzig.de/~duc/amlich/calrules_en.html

import 'dart:math';

class LunarDate {
  final int day;
  final int month;
  final int year;
  final bool isLeapMonth;

  const LunarDate(this.day, this.month, this.year, {this.isLeapMonth = false});

  String get formatted {
    final m = isLeapMonth ? '$month nhuận' : '$month';
    return '$day/$m';
  }

  String get short => '$day/$month';

  @override
  String toString() => '$day/$month/$year${isLeapMonth ? ' (nhuận)' : ''}';
}

/// Convert from Gregorian (DateTime) to Vietnamese Lunar.
LunarDate solarToLunar(DateTime date, {int timeZone = 7}) {
  final dayNumber = _jdFromDate(date.day, date.month, date.year);
  int k = ((dayNumber - 2415021.076998695) / 29.530588853).floor();
  int monthStart = _getNewMoonDay(k + 1, timeZone);
  if (monthStart > dayNumber) {
    monthStart = _getNewMoonDay(k, timeZone);
  }

  int a11 = _getLunarMonth11(date.year, timeZone);
  int b11 = a11;
  int lunarYear;
  if (a11 >= monthStart) {
    lunarYear = date.year;
    a11 = _getLunarMonth11(date.year - 1, timeZone);
  } else {
    lunarYear = date.year + 1;
    b11 = _getLunarMonth11(date.year + 1, timeZone);
  }

  int lunarDay = dayNumber - monthStart + 1;
  int diff = ((monthStart - a11) / 29).floor();
  bool leap = false;
  int lunarMonth = diff + 11;
  if (b11 - a11 > 365) {
    int leapMonthDiff = _getLeapMonthOffset(a11, timeZone);
    if (diff >= leapMonthDiff) {
      lunarMonth = diff + 10;
      if (diff == leapMonthDiff) leap = true;
    }
  }
  if (lunarMonth > 12) lunarMonth -= 12;
  if (lunarMonth >= 11 && diff < 4) lunarYear -= 1;

  return LunarDate(lunarDay, lunarMonth, lunarYear, isLeapMonth: leap);
}

int _jdFromDate(int dd, int mm, int yy) {
  final a = ((14 - mm) / 12).floor();
  final y = yy + 4800 - a;
  final m = mm + 12 * a - 3;
  int jd = dd +
      ((153 * m + 2) / 5).floor() +
      365 * y +
      (y / 4).floor() -
      (y / 100).floor() +
      (y / 400).floor() -
      32045;
  if (jd < 2299161) {
    jd = dd +
        ((153 * m + 2) / 5).floor() +
        365 * y +
        (y / 4).floor() -
        32083;
  }
  return jd;
}

int _getNewMoonDay(int k, int timeZone) {
  final t = k / 1236.85;
  final t2 = t * t;
  final t3 = t2 * t;
  final dr = pi / 180;
  double jd1 = 2415020.75933 +
      29.53058868 * k +
      0.0001178 * t2 -
      0.000000155 * t3;
  jd1 += 0.00033 * sin((166.56 + 132.87 * t - 0.009173 * t2) * dr);
  final m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
  final mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
  final f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;
  double c1 = (0.1734 - 0.000393 * t) * sin(m * dr) + 0.0021 * sin(2 * dr * m);
  c1 -= 0.4068 * sin(mpr * dr) + 0.0161 * sin(dr * 2 * mpr);
  c1 -= 0.0004 * sin(dr * 3 * mpr);
  c1 += 0.0104 * sin(dr * 2 * f) - 0.0051 * sin(dr * (m + mpr));
  c1 -= 0.0074 * sin(dr * (m - mpr)) + 0.0004 * sin(dr * (2 * f + m));
  c1 -= 0.0004 * sin(dr * (2 * f - m)) - 0.0006 * sin(dr * (2 * f + mpr));
  c1 += 0.0010 * sin(dr * (2 * f - mpr)) + 0.0005 * sin(dr * (2 * mpr + m));
  double deltat;
  if (t < -11) {
    deltat = 0.001 +
        0.000839 * t +
        0.0002261 * t2 -
        0.00000845 * t3 -
        0.000000081 * t * t3;
  } else {
    deltat = -0.000278 + 0.000265 * t + 0.000262 * t2;
  }
  final jdNew = jd1 + c1 - deltat;
  return (jdNew + 0.5 + timeZone / 24).floor();
}

int _getSunLongitude(int jdn, int timeZone) {
  final t = (jdn - 2451545.5 - timeZone / 24) / 36525;
  final t2 = t * t;
  final dr = pi / 180;
  final m = 357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2;
  final l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
  double dl = (1.914600 - 0.004817 * t - 0.000014 * t2) * sin(dr * m);
  dl += (0.019993 - 0.000101 * t) * sin(dr * 2 * m) +
      0.000290 * sin(dr * 3 * m);
  double l = l0 + dl;
  l = l * dr;
  l = l - pi * 2 * (l / (pi * 2)).floor();
  return (l / pi * 6).floor();
}

int _getLunarMonth11(int yy, int timeZone) {
  final off = _jdFromDate(31, 12, yy) - 2415021;
  final k = (off / 29.530588853).floor();
  int nm = _getNewMoonDay(k, timeZone);
  final sunLong = _getSunLongitude(nm, timeZone);
  if (sunLong >= 9) {
    nm = _getNewMoonDay(k - 1, timeZone);
  }
  return nm;
}

int _getLeapMonthOffset(int a11, int timeZone) {
  final k = ((a11 - 2415021.076998695) / 29.530588853 + 0.5).floor();
  int last = 0;
  int i = 1;
  int arc = _getSunLongitude(_getNewMoonDay(k + i, timeZone), timeZone);
  do {
    last = arc;
    i++;
    arc = _getSunLongitude(_getNewMoonDay(k + i, timeZone), timeZone);
  } while (arc != last && i < 14);
  return i - 1;
}
