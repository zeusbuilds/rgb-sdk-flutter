/// Optional WebRGB receiving/read and BFA burn provider for approved dApp sessions.
///
/// Transport, durable storage, user consent and independent burn-proof recovery
/// belong to the host. This library does not install a browser provider or
/// implement unsupported WebRGB issuance, send or Lightning methods.
library;

export 'src/integrations/webrgb/errors.dart'
    show WebRgbError, encodeEvmBurnRecipient, encodeTronBurnRecipient;
export 'src/integrations/webrgb/provider.dart';
export 'src/integrations/webrgb/types.dart' hide payoutJson;
export 'src/integrations/webrgb/walletconnect.dart';
export 'src/wallet/burn_destination.dart';
export 'src/wallet/burn_operations.dart';
