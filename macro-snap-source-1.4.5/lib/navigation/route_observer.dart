import 'package:flutter/material.dart';

/// Global [RouteObserver] registered on the app's navigator so any screen
/// can subscribe with [RouteAware] and react to being covered or revealed.
///
/// Used by [HomeScreen] to re-read the user's name (and other prefs) when a
/// route pushed on top — Settings, etc. — is popped, so edits made there
/// appear on Home immediately instead of after an app restart.
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
