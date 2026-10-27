# MediaPipe's generated protobuf messages access fields by name at runtime.
# Without this rule, R8 removes fields such as SystemInfo.platform_ and camera
# startup fails before CameraX can open the preview.
# https://github.com/protocolbuffers/protobuf/blob/main/java/lite.md
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }

# MediaPipe's JNI bridge looks up Java types, methods and packet callbacks.
# Its current Maven AARs do not bundle the upstream framework keep rules.
# https://github.com/google-ai-edge/mediapipe/blob/master/mediapipe/java/com/google/mediapipe/framework/proguard.pgcfg
-keep public interface com.google.mediapipe.framework.* { public *; }
-keep class com.google.mediapipe.framework.Packet {
    public static *** create(...);
    public long getNativeHandle();
    public void release();
}
-keep class com.google.mediapipe.framework.PacketCreator {
    *** releaseWithSyncToken(...);
}
-keep class com.google.mediapipe.framework.MediaPipeException {
    <init>(int, byte[]);
}
-keep class com.google.mediapipe.framework.ProtoUtil$SerializedMessage { *; }

# Graph's Flogger 0.6 logger and caller-finder helpers inspect the call stack.
# Preserve their frames together: protecting only forEnclosingClass() still
# fails with "no caller found on the stack" after R8 inlines helper methods.
-keep class com.google.common.flogger.** { *; }
