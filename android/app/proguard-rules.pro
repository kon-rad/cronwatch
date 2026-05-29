# Keep Firebase model classes (reflective access for Firestore deserialization).
-keep class app.cronwatch.model.** { *; }
-keepclassmembers class app.cronwatch.model.** { *; }

# Keep kotlinx.serialization metadata.
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keep,includedescriptorclasses class app.cronwatch.**$$serializer { *; }
-keepclassmembers class app.cronwatch.** { *** Companion; }
-keepclasseswithmembers class app.cronwatch.** { kotlinx.serialization.KSerializer serializer(...); }

# Hilt
-keep class dagger.hilt.** { *; }
-keep class androidx.hilt.** { *; }

# Compose
-keepclassmembers class androidx.compose.runtime.** { *; }
