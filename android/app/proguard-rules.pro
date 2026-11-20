# kotlinx.serialization: keep generated serializers
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class kotlinx.serialization.json.** { kotlinx.serialization.KSerializer serializer(...); }
-keep,includedescriptorclasses class com.lukstrike.luksmusic.**$$serializer { *; }
-keepclassmembers class com.lukstrike.luksmusic.** { *** Companion; }
-keepclasseswithmembers class com.lukstrike.luksmusic.** { kotlinx.serialization.KSerializer serializer(...); }

# JavaScript bridge of the score viewer
-keepclassmembers class * { @android.webkit.JavascriptInterface <methods>; }

# OkHttp
-dontwarn okhttp3.internal.platform.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
