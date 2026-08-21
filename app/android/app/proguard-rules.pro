# Flutter Wrapper ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# SQLCipher rules
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }
-dontwarn net.sqlcipher.**

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Supabase / HTTP / OkHttp / WebSockets
-dontwarn okhttp3.**
-dontwarn okio.**
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# KeyFlow native Accessibility & capture plugin
-keep class com.keyflow.keyflow_app.** { *; }
