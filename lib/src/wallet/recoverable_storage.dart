import 'recoverable_storage_stub.dart'
    if (dart.library.io) 'recoverable_storage_io.dart'
    as platform;

Future<void> requireRecoverableStorage(
  String storageDirPath, {
  bool allowMissingOutbox = false,
}) => platform.requireRecoverableStorage(
  storageDirPath,
  allowMissingOutbox: allowMissingOutbox,
);
