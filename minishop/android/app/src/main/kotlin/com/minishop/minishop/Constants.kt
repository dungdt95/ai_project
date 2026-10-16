package com.minishop.minishop

object Constants {
    const val PREFS_NAME = "vn.minishop.notification_prefs"
    const val KEY_CALLBACK_HANDLE = "callback_handle"
    const val ACCESS_CHANNEL = "vn.minishop/notification_access"
    const val BG_CHANNEL = "vn.minishop/notification_bg"

    // Best-known package names for the banks/wallets this app targets (see
    // SPEC.md). Kept here as a cheap pre-filter so the listener doesn't spin
    // up a background Flutter engine for unrelated apps; the per-app
    // enabled/disabled toggle in Settings is enforced Dart-side against the
    // DB once that engine is running, since these IDs may need correcting
    // per-device and shouldn't require a native rebuild to fix.
    val WATCHED_PACKAGES = setOf(
        "com.mbmobile",
        "com.VCB",
        "com.techcombank.bb.app.te",
        "com.mservice.momotransfer"
    )
}
