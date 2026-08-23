# Flutter Core & Engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# KeyFlow Native Accessibility Service, Capture Plugin & Main Activity
-keep class com.keyflow.keyflow_app.KeyflowAccessibilityService { *; }
-keep class com.keyflow.keyflow_app.KeyflowCapturePlugin { *; }
-keep class com.keyflow.keyflow_app.MainActivity { *; }
-keep class com.keyflow.keyflow_app.** { *; }

# AndroidX Core & FileProvider
-keep class androidx.core.content.FileProvider { *; }
-keep class androidx.core.** { *; }

# SQLCipher Database Engine
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }
-dontwarn net.sqlcipher.**

# Flutter Secure Storage & Platform Keystore
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Cryptography & BouncyCastle / PointyCastle / SpongyCastle
-keep class org.spongycastle.** { *; }
-keep class org.bouncycastle.** { *; }
-dontwarn org.spongycastle.**
-dontwarn org.bouncycastle.**

# JSON Serialization, Models & Keep Attributes
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,SourceFile,LineNumberTable
-keepclassmembers class * {
    @androidx.annotation.Keep <fields>;
    @androidx.annotation.Keep <methods>;
}

# General Networking & OkHttp & Play Core
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn com.google.android.play.core.**
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement
-dontwarn **
