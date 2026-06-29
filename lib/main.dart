import 'package:flutter/widgets.dart';
import 'package:smoo_control/core/app/smoo_control_app.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/features/sync/domain/services/sync_scheduler_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  await serviceLocator<SyncSchedulerService>().start();
  runApp(const SmooControlApp());
}
