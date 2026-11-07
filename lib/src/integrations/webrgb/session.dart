import 'errors.dart';
import 'types.dart';
import 'wallet.dart';

/// Internal authorization owner. Revision checks also reject revoke/re-enable
/// races, not just the simpler disconnected-at-completion case.
class WebRgbSession {
  WebRgbSession(this.wallet, this.options)
    : authorized = options.sessionApproved {
    final uri = Uri.tryParse(options.origin);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const WebRgbError(
        'INVALID_PARAMS',
        'An authenticated session origin is required.',
      );
    }
  }
  final WebRgbWallet wallet;
  final WebRgbOptions options;
  bool authorized;
  int revision = 0;
  Future<void>? _enabling;
  bool get enabled => authorized && !wallet.isDisposed();

  void revoke() {
    authorized = false;
    revision++;
  }

  void check([int? expectedRevision]) {
    try {
      options.assertAuthorized?.call();
    } catch (_) {
      throw const WebRgbError('NOT_ENABLED', 'Session is no longer active.');
    }
    if (!enabled ||
        (expectedRevision != null && revision != expectedRevision)) {
      throw const WebRgbError('NOT_ENABLED', 'Connect the wallet first.');
    }
  }

  Future<void> enable() {
    if (enabled) {
      try {
        check();
      } catch (error, stack) {
        return Future.error(error, stack);
      }
      return Future.value();
    }
    final current = _enabling;
    if (current != null) return current;
    final initialRevision = revision;
    final action = webRgbWalletCall(() async {
      final approved = await options.confirm(
        WebRgbApproval(
          origin: options.origin,
          method: 'enable',
          params: const {},
        ),
      );
      if (!approved) {
        throw const WebRgbError('USER_REJECTED', 'Connection declined.');
      }
      if (initialRevision != revision || wallet.isDisposed()) {
        throw const WebRgbError('NOT_ENABLED', 'Session is no longer active.');
      }
      try {
        options.assertAuthorized?.call();
      } catch (_) {
        throw const WebRgbError('NOT_ENABLED', 'Session is no longer active.');
      }
      authorized = true;
    });
    _enabling = action.whenComplete(() => _enabling = null);
    return _enabling!;
  }

  Future<T> call<T>(int expectedRevision, Future<T> Function() action) =>
      webRgbWalletCall(() async {
        check(expectedRevision);
        final result = await action();
        check(expectedRevision);
        return result;
      });

  Future<void> confirm(
    int expectedRevision,
    String method,
    Map<String, Object?> params,
  ) async {
    final approved = await call(
      expectedRevision,
      () => options.confirm(
        WebRgbApproval(origin: options.origin, method: method, params: params),
      ),
    );
    if (!approved) {
      throw const WebRgbError('USER_REJECTED', 'Request declined.');
    }
  }
}
