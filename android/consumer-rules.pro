# ROOT-01: optional, unpublished UniFFI recovery methods are detected by name.
# Keep their names when a future qualified AAR provides them. Older artifacts
# intentionally have no such members and must continue to fail unsupported.
-keepclassmembers class org.utexo.rgblightningnode.SdkNode {
    public java.lang.String prepareOnchainSend(java.lang.String);
    public java.lang.String commitOnchainSend(java.lang.String);
    public java.lang.String onchainSendStatus(java.lang.String);
    public java.lang.String cancelOnchainSend(java.lang.String);
}
