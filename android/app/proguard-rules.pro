-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.** { *; }

# 原生监控相关类（MethodChannel 与系统组件入口）
-keep class com.demo.screen_time_monitor.** { *; }

# 本应用不使用 Play 动态组件，忽略 flutter_embedding 里对 Play Core 的可选引用
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
