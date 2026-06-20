String readBrowserRoute(String fallback) => fallback;

Stream<String> browserRouteChanges(String fallback) => const Stream.empty();

void pushBrowserRoute(String route) {}

void replaceBrowserRoute(String route) {}
