import 'dart:io';

import '../errors/rgb_sdk_exception.dart';

Future<void> requireRecoverableStorage(
  String storageDirPath, {
  bool allowMissingOutbox = false,
}) async {
  try {
    if (await FileSystemEntity.type(storageDirPath, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const RecoverableSendStorageException();
    }
    final type = await FileSystemEntity.type(
      '$storageDirPath/durable-onchain-v1',
      followLinks: false,
    );
    if (type == FileSystemEntityType.directory ||
        (allowMissingOutbox && type == FileSystemEntityType.notFound)) {
      return;
    }
  } on FileSystemException {
    // Paths and arbitrary operating-system messages remain private.
  }
  throw const RecoverableSendStorageException();
}
