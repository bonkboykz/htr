import 'package:get_it/get_it.dart';

import '../network/api_client.dart';
import '../rest_timer/notification_rest_alarm.dart';
import '../rest_timer/rest_alarm.dart';
import '../storage/token_storage.dart';

final sl = GetIt.instance;

/// Registers shared singletons. Features build their own repository/cubit from
/// `sl<ApiClient>()` in their page (so feature code never edits this file).
Future<void> setupDependencies() async {
  final tokens = TokenStorage();
  sl.registerSingleton<TokenStorage>(tokens);

  final api = ApiClient(tokens);
  final override = await tokens.baseUrlOverride();
  if (override != null && override.isNotEmpty) api.baseUrl = override;
  sl.registerSingleton<ApiClient>(api);

  // Rest-timer alarm (local notification that fires when the phone is locked).
  sl.registerSingleton<RestAlarm>(await initRestAlarm());
}
