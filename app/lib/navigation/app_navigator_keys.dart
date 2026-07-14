import 'package:flutter/widgets.dart';

/// Root navigator key, shared between `createAppRouter` and the shell
/// branches. Subpages that should cover the whole shell — including its
/// bottom navigation bar — attach here via `parentNavigatorKey` instead of
/// stacking on their branch's own navigator underneath the shell's Scaffold.
final rootNavigatorKey = GlobalKey<NavigatorState>();
