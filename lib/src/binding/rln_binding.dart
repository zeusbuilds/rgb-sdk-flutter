// ignore_for_file: unused_element

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../client/rln_client.dart';
import '../crypto/constants.dart';
import '../errors/native_bridge_error_mapper.dart';
import '../errors/rgb_sdk_exception.dart';
import '../models/burn_models.dart';
import '../models/imported_rgb_contract.dart';
import '../models/rln_models.dart';

part 'rln_binding_types.dart';
part 'rln_binding_lifecycle.dart';
part 'rln_binding_lightning.dart';
part 'rln_binding_onchain.dart';
part 'rln_binding_asset_media.dart';
part 'rln_binding_bfa.dart';

enum _RlnLifecycleState { idle, active, shuttingDown, destroying, timedOut }

abstract class _RlnBindingInternals {
  RlnClient get _client;
  Future<void> get _nodeOperationQueue;
  set _nodeOperationQueue(Future<void> value);
  int? get _rlnNodeId;
  set _rlnNodeId(int? value);
  List<int> get _retiredRlnNodeIds;
  bool get _unlockConflictNormalized;
  set _unlockConflictNormalized(bool value);
  _RlnLifecycleState get _lifecycleState;
  set _lifecycleState(_RlnLifecycleState value);

  Future<T> _withNodeQueue<T>(
    String operationName,
    Future<T> Function() operation,
  );
  Future<T> _withNodeOperation<T>(
    String operationName,
    Future<T> Function(int nodeId) operation,
  );
  Future<T> _withNodeInspection<T>(
    String operationName,
    Future<T> Function(int nodeId) operation,
  );
  int _requireNodeId();
  void _assertRegularOpsAllowed();
  bool _isConflictError(Object error);
  Future<bool> _probeNodeReady(int nodeId);
}

class RLNBinding extends _RlnBindingInternals
    with
        _RlnBindingLifecycle,
        _RlnBindingLightning,
        _RlnBindingOnchain,
        _RlnBindingAssetMedia,
        _RlnBindingBfa {
  RLNBinding({
    RlnClient? client,
    RlnOperationTimeoutPolicy operationTimeouts =
        const RlnOperationTimeoutPolicy(),
  }) : _client = client ?? RlnClient(),
       _operationTimeouts = operationTimeouts;

  @override
  final RlnClient _client;
  final RlnOperationTimeoutPolicy _operationTimeouts;
  @override
  Future<void> _nodeOperationQueue = Future<void>.value();
  @override
  int? _rlnNodeId;
  @override
  final List<int> _retiredRlnNodeIds = <int>[];
  @override
  bool _unlockConflictNormalized = false;
  @override
  _RlnLifecycleState _lifecycleState = _RlnLifecycleState.idle;

  RlnClient get client => _client;

  int? get rlnNodeId => _rlnNodeId;

  /// Runs a whole signer strategy under the node's queue and deadline.
  ///
  /// The callback must use the supplied client directly, not enqueue another
  /// binding operation (which would deadlock). Native completion continues to
  /// own the queue after a Dart timeout; cleanup must wait for it.
  Future<T> runSignerOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) => _withNodeQueue(operationName, () {
    if (!operationName.contains('Destroy')) _assertRegularOpsAllowed();
    return operation();
  });

  @override
  Future<T> _withNodeQueue<T>(
    String operationName,
    Future<T> Function() operation,
  ) {
    // Rejected policy must never enqueue an operation with side effects.
    final timeout = _operationTimeouts.timeoutFor(operationName);
    if (timeout != null && timeout <= Duration.zero) {
      throw const ValidationError('timeout must be positive', 'timeout');
    }
    final previous = _nodeOperationQueue;
    var timedOut = false;
    final nativeCompletion = previous.then((_) {
      // A deadline reached while waiting is not permission to dispatch later.
      if (timedOut) {
        throw RlnOperationTimeoutException(
          operation: operationName,
          timeout: timeout!,
        );
      }
      return operation();
    });
    _nodeOperationQueue = nativeCompletion.then<void>(
      (_) {
        if (timedOut && _lifecycleState != _RlnLifecycleState.destroying) {
          _lifecycleState = _RlnLifecycleState.timedOut;
        }
      },
      onError: (_) {
        if (timedOut && _lifecycleState != _RlnLifecycleState.destroying) {
          _lifecycleState = _RlnLifecycleState.timedOut;
        }
      },
    );
    if (timeout == null) return nativeCompletion;
    return nativeCompletion.timeout(
      timeout,
      onTimeout: () {
        timedOut = true;
        _lifecycleState = _RlnLifecycleState.timedOut;
        throw RlnOperationTimeoutException(
          operation: operationName,
          timeout: timeout,
        );
      },
    );
  }

  @override
  Future<T> _withNodeOperation<T>(
    String operationName,
    Future<T> Function(int nodeId) operation,
  ) {
    return _withNodeQueue(operationName, () {
      final nodeId = _requireNodeId();
      _assertRegularOpsAllowed();
      return operation(nodeId);
    });
  }

  // Only native identity, pure RGB invoice decoding and durable send status
  // use this path. The same
  // queue waits for an in-flight operation after its Dart deadline; inspection
  // never races native mutation and never re-enables ordinary operations.
  // Destroy/shutdown still own lifecycle teardown and cannot be bypassed.
  @override
  Future<T> _withNodeInspection<T>(
    String operationName,
    Future<T> Function(int nodeId) operation,
  ) => _withNodeQueue(operationName, () {
    final nodeId = _requireNodeId();
    if (_lifecycleState == _RlnLifecycleState.shuttingDown ||
        _lifecycleState == _RlnLifecycleState.destroying) {
      throw const WalletError('RLN node is shutting down or destroying');
    }
    return operation(nodeId);
  });

  @override
  int _requireNodeId() {
    final nodeId = _rlnNodeId;
    if (nodeId == null) {
      throw const WalletError('RLN node is not created');
    }
    return nodeId;
  }

  @override
  void _assertRegularOpsAllowed() {
    if (_lifecycleState == _RlnLifecycleState.shuttingDown ||
        _lifecycleState == _RlnLifecycleState.destroying ||
        _lifecycleState == _RlnLifecycleState.timedOut) {
      throw const WalletError(
        'RLN node is shutting down, destroying, or timed out',
      );
    }
  }

  @override
  bool _isConflictError(Object error) {
    if (error is ConflictError) return true;
    if (error is! RgbSdkException) return false;
    final cause = error.cause;
    if (cause is! NativeBridgeFailure) return false;
    return cause.nativeCode == 'Conflict' ||
        cause.nativeCode == 'AlreadyExists' ||
        cause.nativeCode == 'ResourceBusy';
  }

  @override
  Future<bool> _probeNodeReady(int nodeId) async {
    try {
      await _client.nodeInfo(nodeId);
      return true;
    } on RgbSdkException {
      return false;
    }
  }
}
