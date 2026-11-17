import 'package:flutter/widgets.dart';

/// True when the platform asks apps to avoid decorative motion.
///
/// Honours the OS "remove animations" setting so the dashboards, skeleton
/// shimmer and count-up figures fall still for users who need that.
bool reduceMotion(BuildContext context) {
  return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}
