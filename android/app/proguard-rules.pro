# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Native Rust FFI & Haudiotagger
-keepclasseswithmembernames class * {
    native <methods>;
}
-keep class com.haudiotagger.** { *; }

# Suppress Play Core warnings in Flutter apps without dynamic features
-dontwarn com.google.android.play.core.**

# Keep annotations and line numbers for stack traces
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
