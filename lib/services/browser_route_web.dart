// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:async';

String readBrowserRoute(String fallback) {
  final fragment = Uri.base.fragment;
  if (fragment.startsWith('/')) return _routeOrFallback(fragment, fallback);

  final path = html.window.location.pathname ?? '';
  final basePath = Uri.base.resolve('.').path;
  final routePath = _stripBasePath(path, basePath);
  if (routePath.length > 1) {
    return _routeOrFallback(routePath, fallback);
  }

  return fallback;
}

Stream<String> browserRouteChanges(String fallback) {
  final controller = StreamController<String>.broadcast();
  void emit(Object? _) => controller.add(readBrowserRoute(fallback));
  final popSub = html.window.onPopState.listen(emit);
  final hashSub = html.window.onHashChange.listen(emit);
  controller.onCancel = () {
    popSub.cancel();
    hashSub.cancel();
  };
  return controller.stream;
}

void pushBrowserRoute(String route) {
  final normalized = _normalizeRoute(route);
  if (Uri.base.fragment == normalized) return;
  html.window.history.pushState(null, '', '#$normalized');
}

void replaceBrowserRoute(String route) {
  final normalized = _normalizeRoute(route);
  if (Uri.base.fragment == normalized) return;
  html.window.history.replaceState(null, '', '#$normalized');
}

String _routeOrFallback(String route, String fallback) {
  final normalized = _normalizeRoute(route);
  return normalized == '/' ? fallback : normalized;
}

String _normalizeRoute(String route) {
  final trimmed = route.trim();
  if (trimmed.isEmpty) return '/';
  return trimmed.startsWith('/') ? trimmed : '/$trimmed';
}

String _stripBasePath(String path, String basePath) {
  final normalizedPath = _normalizeRoute(path);
  final normalizedBase = _normalizeRoute(basePath);
  if (normalizedPath == normalizedBase) return '/';
  if (normalizedPath.startsWith(normalizedBase)) {
    final rest = normalizedPath.substring(normalizedBase.length);
    return _normalizeRoute(rest);
  }
  return normalizedPath;
}
