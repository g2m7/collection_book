/// The local destination selected by a strictly validated Android App Link.
enum AppLinkDestination { importWizard, referralOpen }

/// Parses the route values delivered by Flutter's Android embedding.
///
/// On a cold launch the Android engine passes the full intent URI to
/// `WidgetsApp`, so the route name is the complete `https://…` link. On a warm
/// launch the engine still sends the full URI, but `WidgetsApp` normalizes the
/// route information to `path[?query][#fragment]` before
/// `onGenerateRoute` sees it. That normalization forwards the query and
/// fragment, so both forms can carry them; they are intentionally rejected
/// here. Referral codes are intentionally not retained.
abstract final class AppLinkRouter {
  static final RegExp _fullUri = RegExp(
    r'https://cbk\.sarbaa\.com(?:/import|/r/[A-Z0-9]{6})',
  );
  static final RegExp _absolutePath = RegExp(r'(?:/import|/r/[A-Z0-9]{6})');

  /// Any link that already names the canonical host, at any path, shape, or
  /// casing. Used only to decide whether a route should degrade to a safe
  /// surface; it never selects a destination.
  static final RegExp _canonicalHostLink = RegExp(
    r'^https?://cbk\.sarbaa\.com(?::[0-9]+)?(?:/|$)',
    caseSensitive: false,
  );

  /// Warm route information whose path starts with a real App Link path.
  static final RegExp _warmLinkPath = RegExp(r'^/import(?:$|[/?#])|^/r/');

  static AppLinkDestination? parse(String route) {
    if (_fullUri.firstMatch(route)?.group(0) == route) {
      return route.endsWith('/import')
          ? AppLinkDestination.importWizard
          : AppLinkDestination.referralOpen;
    }
    if (_absolutePath.firstMatch(route)?.group(0) == route) {
      return route == '/import'
          ? AppLinkDestination.importWizard
          : AppLinkDestination.referralOpen;
    }
    return null;
  }

  /// Whether [route] is an App Link that [parse] rejected.
  ///
  /// Only canonical-host full links and warm `/import` or `/r/` paths qualify.
  /// Ordinary internal route names such as `/subscribers` or `/import-history`
  /// never qualify, so a mistyped internal `pushNamed` still fails through
  /// Flutter's normal route-generation behavior instead of being masked.
  static bool isPotentialAppLink(String route) =>
      _canonicalHostLink.hasMatch(route) || _warmLinkPath.hasMatch(route);
}
