# flutter_local_notifications stores scheduled notifications as JSON via Gson.
# R8 full mode strips TypeToken generics → RuntimeException: Missing type parameter.
# See https://github.com/MaikuB/flutter_local_notifications/issues/1490
-keepattributes Signature
-keepattributes *Annotation*
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
