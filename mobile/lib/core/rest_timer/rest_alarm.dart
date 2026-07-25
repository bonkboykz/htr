/// Fires an alert when the rest countdown ends — even if the app is
/// backgrounded or the phone is locked.
///
/// Wave A ships the no-op default (foreground vibration is handled directly by
/// the cubit). Wave B provides a `flutter_local_notifications`-backed
/// implementation that schedules an OS notification so the alert survives lock.
abstract class RestAlarm {
  /// Schedule an alert [seconds] from now.
  Future<void> schedule(int seconds);

  /// Cancel any pending alert (rest skipped / a new set logged / finished).
  Future<void> cancel();
}

/// Default: does nothing. The in-app countdown + vibration still work while the
/// workout screen is in the foreground.
class NoopRestAlarm implements RestAlarm {
  const NoopRestAlarm();

  @override
  Future<void> schedule(int seconds) async {}

  @override
  Future<void> cancel() async {}
}
