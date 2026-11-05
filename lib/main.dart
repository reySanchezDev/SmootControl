import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:smoo_control/core/app/smoo_control_app.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/features/sync/domain/services/sync_scheduler_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  // Browser Backoffice is remote-first; never run the POS offline sync queue.
  if (!kIsWeb) {
    await serviceLocator<SyncSchedulerService>().start();
  }
  runApp(const SmooControlApp());
}
