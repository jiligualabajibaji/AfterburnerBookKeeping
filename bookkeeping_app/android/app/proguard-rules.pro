# Flutter specific
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.bookkeeping.** { *; }
-keep class * extends FlutterActivity

# Keep model classes used for JSON
-keep class * {
    *;
}

# Play Core (needed for Flutter deferred components)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
