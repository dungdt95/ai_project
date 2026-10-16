package com.dtd.chiahoadon

import io.flutter.embedding.android.FlutterFragmentActivity

/// `FlutterFragmentActivity` thay vì `FlutterActivity`: local_auth dựng hộp
/// thoại sinh trắc học bằng androidx BiometricPrompt, mà cái đó đòi activity
/// phải là FragmentActivity. Dùng FlutterActivity thì app chạy bình thường cho
/// tới đúng lúc bật khóa, rồi ném lỗi ngay trên máy thật.
class MainActivity : FlutterFragmentActivity()
