# ROOT-01: optional, unpublished UniFFI recovery methods are detected by name.
# Keep their names when a future qualified AAR provides them. Older artifacts
# intentionally have no such members and must continue to fail unsupported.
-keepclassmembers class org.utexo.rgblightningnode.SdkNode {
    public java.lang.String prepareOnchainSend(java.lang.String);
    public java.lang.String commitOnchainSend(java.lang.String);
    public java.lang.String onchainSendStatus(java.lang.String);
    public java.lang.String cancelOnchainSend(java.lang.String);
}

# RGB Lib's generated exception names are stable cross-platform error codes.
-keepnames class com.utexo.RgbLibException$*
# JNA direct mapping and integrity checks use their generated native methods.
-keep class com.utexo.UniffiLib { native <methods>; }
-keep class com.utexo.IntegrityCheckingUniffiLib { native <methods>; }

# JNA keeps desktop AWT helpers that cannot be reached on Android.
-dontwarn java.awt.Component
-dontwarn java.awt.GraphicsEnvironment
-dontwarn java.awt.HeadlessException
-dontwarn java.awt.Window
