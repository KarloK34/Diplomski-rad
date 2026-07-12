import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges one or more [Stream]s into go_router's `refreshListenable`, so
/// `redirect` callbacks re-run whenever any of them emits.
///
/// go_router 17.3.0 does not export a ready-made helper for this — the
/// standard "wrap a stream in a `ChangeNotifier`" recipe is hand-rolled here
/// instead.
class GoRouterRefreshStream extends ChangeNotifier {
  /// Starts listening to every stream in [streams] immediately.
  GoRouterRefreshStream(Iterable<Stream<dynamic>> streams) {
    _subscriptions = [
      for (final stream in streams) stream.listen((_) => notifyListeners()),
    ];
  }

  late final List<StreamSubscription<dynamic>> _subscriptions;

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
