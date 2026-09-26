import 'package:flutter/foundation.dart';

/// Exposed by the role router to the active role app, so the user can return to
/// the "choose school and role" screen without signing out.
class RoleController {
  RoleController(this.backToChooser);

  /// Return to the school/role chooser.
  final VoidCallback backToChooser;
}
