import 'src/binding/rln_binding.dart';
import 'src/native_artifact_info.dart';
import 'src/native_artifact_provider.dart';
import 'src/release_baseline.g.dart';
import 'src/wallet/rgb_lib/config.dart';
import 'src/wallet/rln_signers.dart';
import 'src/wallet/utexo_wallet.dart';
import 'src/wallet/utexo_wallet_types.dart';
import 'src/wallet/wallet_engine.dart';

export 'src/binding/rln_binding.dart' show RlnOperationTimeoutPolicy;
export 'src/crypto/constants.dart'
    show
        DEFAULT_API_TIMEOUT,
        DEFAULT_INDEXER_URLS,
        DEFAULT_LOG_LEVEL,
        DEFAULT_MAX_RETRIES,
        DEFAULT_NETWORK,
        DEFAULT_TRANSPORT_ENDPOINTS,
        DEFAULT_VSS_SERVER_URL,
        Network,
        NetworkVersions,
        PsbtType,
        accountDerivationPath,
        getNetworkVersions;
export 'src/crypto/keys.dart'
    show
        AccountXpubs,
        GeneratedKeys,
        WalletInitParams,
        accountXpubsFromMnemonic,
        createWallet,
        deriveKeysFromMnemonic,
        deriveKeysFromMnemonicOrSeed,
        deriveKeysFromSeed,
        deriveKeysFromXpriv,
        generateKeys,
        getXprivFromMnemonic,
        getXpubFromXpriv,
        normalizeSeedInput,
        restoreKeys,
        seedFromMnemonic,
        wipeSecretBytes;
export 'src/crypto/message.dart'
    show
        SignMessageParams,
        SchnorrSigningMode,
        VerifyMessageParams,
        signMessage,
        signSchnorr,
        verifyMessage,
        verifySchnorr,
        xOnlyPointFromPoint;
export 'src/crypto/validation.dart'
    hide toBigInt, toNumber, toUnitsBigInt, fromUnitsBigInt;
export 'src/errors/rgb_sdk_exception.dart';
export 'src/lsp/lsp_address_types.dart';
export 'src/lsp/lsp_errors.dart';
export 'src/lsp/lsp_flow_types.dart';
export 'src/lsp/lsp_relay_types.dart' hide LspRelayQuoteVerifier;
export 'src/lsp/lsp_types.dart';
export 'src/lsp/lsp_wallet.dart' show ILspWallet;
export 'src/lsp/utexo_lsp.dart';
export 'src/lsp/utexo_lsp_client.dart'
    show IUtexoLspClient, LspError, UtexoLspClient;
export 'src/models/burn_models.dart'
    show BfaCapabilities, BurnParams, BurnResult;
export 'src/models/imported_rgb_contract.dart' show ImportedRgbContract;
export 'src/models/utexo_core_models.dart'
    show
        Assignment,
        CoreAsset,
        CoreAssetBfa,
        CoreAssetBalance,
        CoreAssetCfa,
        CoreAssetIfa,
        CoreAssetNia,
        CoreAssetToken,
        CoreAssetUda,
        CoreBalance,
        CoreBlockTime,
        CoreBtcBalance,
        CoreInvoiceData,
        CoreInvoiceReceiveData,
        CoreListAssets,
        CoreMedia,
        CoreRgbAllocation,
        CoreTokenAttachment,
        CoreTransaction,
        CoreTransfer,
        CoreTransferTransportEndpoint,
        CoreUnspent,
        CoreUtxo,
        DecodedLightningInvoice,
        LightningChannel,
        LightningChannelOpenResult,
        LightningPayment,
        LightningPeer,
        SendPaymentResult,
        TransferAmount,
        Outpoint,
        WalletNetworkInfo,
        WalletNodeInfo,
        parseCoreAssignment,
        parseCoreOutpoint;
export 'src/native_artifact_info.dart';
export 'src/wallet/burn_operations.dart';
export 'src/wallet/network_defaults.dart'
    show NetworkEndpoints, getNetworkDefaults;
export 'src/wallet/rgb_lib/config.dart'
    show
        RgbLibIndexer,
        RgbLibEvmChain,
        RgbLibIndexerKind,
        RgbLibKeys,
        RgbLibMintLockBlocks,
        RgbLibMnemonicReader,
        RgbLibPublicKeys,
        RgbLibUnlockParams,
        RgbLibWalletException,
        RgbLibWalletParams,
        RgbLibWitnessVersion,
        defaultRgbLibEvmMintLockBlocks,
        getRgbLibNetworkDefaults;
export 'src/wallet/rgb_lib/rgb_lib_wallet.dart'
    show
        RgbLibWallet,
        RgbLibDurableOperations,
        RgbLibPendingOnchainOperation,
        RgbLibOnchainSendReceipt,
        RgbLibOnchainSendReceiptPage,
        restoreBackupFromFile;
export 'src/wallet/rgb_lib/wire.dart'
    show
        RgbLibAssetMetadata,
        RgbLibAssetSchema,
        RgbLibBackupRecoveryCapabilities,
        RgbLibIndexerCheck,
        RgbLibInvoiceData,
        RgbLibMedia,
        RgbLibNetworkInfo,
        RgbLibReceiveAssignment,
        RgbLibReceiveData,
        RgbLibReceivedMint,
        RgbLibRuntimeInfo,
        RgbLibTransfer,
        RgbLibWalletIdentity;
export 'src/wallet/rln_signers.dart'
    show
        NativeExternalRlnSigner,
        PasswordRlnSigner,
        RlnKeyMaterial,
        RlnMnemonicKeyMaterial,
        RlnSeedBytesKeyMaterial,
        RlnSeedHexKeyMaterial,
        RlnSigner,
        RlnSignerHost;
export 'src/wallet/rln_wallet.dart' show RlnWallet;
export 'src/wallet/utexo_wallet.dart'
    show
        UtexoWallet,
        resolveUnlockParams,
        RecoverableOnchainSendCommand,
        RecoverableOnchainSendKind,
        RecoverableOnchainSendPhase,
        RecoverableOnchainSendStatus,
        UtexoWalletEngineAccess;
export 'src/wallet/utexo_wallet_types.dart';
export 'src/wallet/wallet_engine.dart' show WalletEngine;

/// Flutter entry point for Bitcoin, RGB and RGB Lightning Node wallets.
///
/// [wallet] defaults to the on-chain RGB_L1 engine. Use [rlnWallet]
/// to select RGB Lightning Node explicitly, or supply an existing engine.
/// Low-level RN/native parity APIs live in `rgb_sdk_flutter_advanced.dart`.
class RgbSdkFlutter {
  const RgbSdkFlutter();

  /// Dart package name.
  static const packageName = 'rgb_sdk_flutter';

  /// React Native package used as the parity reference.
  static const reactNativePackageName = '@utexo/rgb-sdk-rn';

  /// React Native package version this bridge targets.
  static const reactNativeParityVersion = ReleaseBaseline.reactNativeVersion;

  /// RGB Lightning Node artifact version pinned by this package.
  static const rlnVersion = ReleaseBaseline.rlnVersion;

  /// Returns native artifact metadata for diagnostics and support reports.
  Future<NativeArtifactInfo> nativeArtifactInfo() {
    return NativeArtifactInfoReader().getNativeArtifactInfo();
  }

  /// Creates a typed wallet facade for app-level wallet workflows.
  UtexoWallet wallet({
    WalletEngine? engine,
    RgbLibWalletParams? params,
    RgbLibKeys? keys,
    RgbLibUnlockParams? online,
  }) => UtexoWallet(engine: engine, params: params, keys: keys, online: online);

  /// Selects the independent RLN engine explicitly.
  UtexoWallet rlnWallet({
    required RlnWalletConfig config,
    RlnOperationTimeoutPolicy? operationTimeouts,
    RlnSigner? signer,
  }) => UtexoWallet.rln(
    config: config,
    operationTimeouts: operationTimeouts,
    signer: signer,
  );
}
