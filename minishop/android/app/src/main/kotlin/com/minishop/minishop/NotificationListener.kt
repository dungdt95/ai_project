package com.minishop.minishop

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/// Listens for notifications from the banking/wallet apps in
/// [Constants.WATCHED_PACKAGES] and hands matches off to [BackgroundExecutor]
/// so a headless Dart isolate can parse/match/confirm the invoice — this
/// keeps working even when the Flutter app itself isn't open.
class NotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val packageName = sbn.packageName
        if (packageName !in Constants.WATCHED_PACKAGES) return

        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
        val fullText = listOf(title, text, bigText).filter { it.isNotBlank() }.joinToString(" \n ")

        if (fullText.isBlank()) return

        BackgroundExecutor.executeNotification(applicationContext, packageName, fullText)
    }
}
