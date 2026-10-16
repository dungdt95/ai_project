/// Returns a deterministic seed for the daily puzzle based on date.
/// All users get the same puzzle on the same UTC day.
int dailySeed(DateTime date) =>
    '${date.toUtc().year}-${date.toUtc().month.toString().padLeft(2, '0')}-${date.toUtc().day.toString().padLeft(2, '0')}'
        .hashCode
        .abs();

/// Today's daily seed.
int todaysDailySeed() => dailySeed(DateTime.now());
