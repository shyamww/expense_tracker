import 'package:flutter/foundation.dart';

/// Signals the home screen to run the same navigation as the bottom bar "Home" action.
class AppNavigationHub extends ChangeNotifier {
  void requestHomeDashboard() {
    notifyListeners();
  }
}
