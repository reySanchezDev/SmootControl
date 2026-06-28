import 'package:flutter/widgets.dart';
import 'package:smoo_control/core/app/smoo_control_app.dart';
import 'package:smoo_control/core/di/service_locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const SmooControlApp());
}
