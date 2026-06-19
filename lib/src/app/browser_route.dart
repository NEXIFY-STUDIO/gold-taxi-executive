import 'browser_route_stub.dart'
    if (dart.library.js_interop) 'browser_route_web.dart';

String currentBrowserPath() => currentBrowserPathImpl();
