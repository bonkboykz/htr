import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibration/vibration.dart';

import '../../../core/network/api_client.dart';
import '../../../core/rest_timer/rest_alarm.dart';
import '../data/workout_models.dart';
import '../data/workout_repository.dart';

/// Default rest between working sets, in seconds.
const _kRestSeconds = 120;

enum WorkoutStatus { initial, loading, ready, error }

class WorkoutState extends Equatable {
  final WorkoutStatus status;
  final WorkoutPlan? plan;
  final TrainingToday? today;
  final String? error;
  final bool unauthorized;

  /// True → show the LIVE logging view (an active session is in progress).
  /// False → show the "Начать тренировку" card + history list.
  final bool live;

  /// Past sessions (endedAt != null), newest first — for the История list.
  final List<SessionSummary> history;

  /// Live session id. Set when resuming an active session or after "Начать".
  final String? sessionId;
  final int elapsedSeconds;

  /// Ephemeral per-exercise input, keyed by routineExercise.id.
  final Map<String, SetInput> inputs;

  /// Sets logged this session, keyed by routineExercise.id.
  final Map<String, List<LoggedSet>> logged;

  /// Which main-section exercise is expanded (routineExercise.id).
  final String? expandedId;

  /// Non-null right after finishing → drives the summary dialog.
  final int? summaryDurationS;

  /// True while a network write (set / finish) is in flight.
  final bool busy;

  /// Rest countdown between sets: seconds remaining (0 = no rest running) and
  /// the total the countdown started from (for the progress ring).
  final int restRemaining;
  final int restTotal;

  const WorkoutState({
    this.status = WorkoutStatus.initial,
    this.plan,
    this.today,
    this.error,
    this.unauthorized = false,
    this.live = false,
    this.history = const [],
    this.sessionId,
    this.elapsedSeconds = 0,
    this.inputs = const {},
    this.logged = const {},
    this.expandedId,
    this.summaryDurationS,
    this.busy = false,
    this.restRemaining = 0,
    this.restTotal = 0,
  });

  bool get sessionActive => sessionId != null;

  WorkoutState copyWith({
    WorkoutStatus? status,
    WorkoutPlan? plan,
    TrainingToday? today,
    String? error,
    bool? unauthorized,
    bool? live,
    List<SessionSummary>? history,
    String? sessionId,
    int? elapsedSeconds,
    Map<String, SetInput>? inputs,
    Map<String, List<LoggedSet>>? logged,
    String? expandedId,
    bool clearExpanded = false,
    int? summaryDurationS,
    bool clearSummary = false,
    bool? busy,
    int? restRemaining,
    int? restTotal,
  }) {
    return WorkoutState(
      status: status ?? this.status,
      plan: plan ?? this.plan,
      today: today ?? this.today,
      error: error,
      unauthorized: unauthorized ?? this.unauthorized,
      live: live ?? this.live,
      history: history ?? this.history,
      sessionId: sessionId ?? this.sessionId,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      inputs: inputs ?? this.inputs,
      logged: logged ?? this.logged,
      expandedId: clearExpanded ? null : (expandedId ?? this.expandedId),
      summaryDurationS:
          clearSummary ? null : (summaryDurationS ?? this.summaryDurationS),
      busy: busy ?? this.busy,
      restRemaining: restRemaining ?? this.restRemaining,
      restTotal: restTotal ?? this.restTotal,
    );
  }

  @override
  List<Object?> get props => [
        status,
        plan,
        today,
        error,
        unauthorized,
        live,
        history,
        sessionId,
        elapsedSeconds,
        inputs,
        logged,
        expandedId,
        summaryDurationS,
        busy,
        restRemaining,
        restTotal,
      ];
}

class WorkoutCubit extends Cubit<WorkoutState> {
  final WorkoutRepository _repo;
  final RestAlarm _restAlarm;
  Timer? _timer;

  /// Wall-clock anchors so timers stay correct across backgrounding.
  DateTime? _sessionStart;
  DateTime? _restEnd;
  bool _restVibrated = false;

  WorkoutCubit(this._repo, {RestAlarm? restAlarm})
      : _restAlarm = restAlarm ?? const NoopRestAlarm(),
        super(const WorkoutState());

  Future<void> load() async {
    _timer?.cancel();
    _sessionStart = null;
    _restEnd = null;
    _restAlarm.cancel();
    emit(const WorkoutState(status: WorkoutStatus.loading));
    try {
      final sessions = await _repo.sessions();
      final today = await _repo.today();

      SessionSummary? active;
      for (final s in sessions) {
        if (s.isActive) {
          active = s;
          break;
        }
      }

      if (active != null) {
        // Resume the in-progress session → LIVE view seeded with logged sets.
        final detail = await _repo.sessionDetail(active.id);
        final plan =
            await _repo.plan(active.routineId, active.sessionIndex);
        _sessionStart =
            DateTime.tryParse(active.startedAt) ?? DateTime.now();
        _restEnd = null;
        emit(state.copyWith(
          status: WorkoutStatus.ready,
          today: today,
          plan: plan,
          live: true,
          history: sessions.where((s) => !s.isActive).toList(),
          sessionId: active.id,
          elapsedSeconds: _elapsedSince(active.startedAt),
          inputs: _seedInputs(plan),
          logged: _loggedFromDetail(plan, detail),
          expandedId:
              plan.main.isNotEmpty ? plan.main.first.routineExercise.id : null,
        ));
        _startTimer();
      } else {
        // No active session → start card + history. Load today's plan for the card.
        final plan = await _repo.plan(today.routineId, today.sessionIndex);
        emit(state.copyWith(
          status: WorkoutStatus.ready,
          today: today,
          plan: plan,
          live: false,
          history: sessions.where((s) => !s.isActive).toList(),
          inputs: _seedInputs(plan),
          logged: const {},
          expandedId:
              plan.main.isNotEmpty ? plan.main.first.routineExercise.id : null,
        ));
      }
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: WorkoutStatus.error,
        error: e.message,
        unauthorized: e.isUnauthorized,
      ));
    } catch (e) {
      emit(state.copyWith(status: WorkoutStatus.error, error: e.toString()));
    }
  }

  int _elapsedSince(String startedAt) {
    final start = DateTime.tryParse(startedAt);
    if (start == null) return 0;
    final secs = DateTime.now().difference(start).inSeconds;
    return secs < 0 ? 0 : secs;
  }

  /// Seed the "Готово" map from a resumed session's already-logged sets,
  /// keyed by routineExercise.id (sets carry exerciseId → map via the plan).
  Map<String, List<LoggedSet>> _loggedFromDetail(
    WorkoutPlan plan,
    SessionDetail detail,
  ) {
    final reIdByExercise = <String, String>{};
    for (final item in plan.all) {
      reIdByExercise[item.exercise.id] = item.routineExercise.id;
    }
    final map = <String, List<LoggedSet>>{};
    for (final s in detail.sets) {
      final reId = reIdByExercise[s.exerciseId];
      if (reId == null) continue;
      (map[reId] ??= <LoggedSet>[]).add(
          LoggedSet(id: s.id, weightG: s.weightG, reps: s.reps, rir: s.rir));
    }
    return map;
  }

  /// Start a session from the "Начать" card and switch into live mode.
  Future<void> startWorkout() async {
    final today = state.today;
    if (today == null || state.busy) return;
    emit(state.copyWith(busy: true, error: null));
    try {
      final started =
          await _repo.startSession(today.routineId, today.sessionIndex);
      _sessionStart = DateTime.now();
      _restEnd = null;
      emit(state.copyWith(
        busy: false,
        live: true,
        sessionId: started.sessionId,
        elapsedSeconds: 0,
        logged: const {},
      ));
      _startTimer();
    } on ApiException catch (e) {
      emit(state.copyWith(
          busy: false, error: e.message, unauthorized: e.isUnauthorized));
    } catch (e) {
      emit(state.copyWith(busy: false, error: e.toString()));
    }
  }

  Map<String, SetInput> _seedInputs(WorkoutPlan plan) {
    final map = <String, SetInput>{};
    for (final item in plan.all) {
      final re = item.routineExercise;
      final s = item.suggestion;
      final last = item.last;
      final weightG = s?.weightG ?? last?.weightG ?? 0;
      final reps = s?.repsTarget ?? last?.reps ?? re.repMin;
      final rir = s?.rirTarget ?? re.targetRir;
      map[re.id] = SetInput(weightG: weightG, reps: reps, rir: rir);
    }
    return map;
  }

  void toggleExpanded(String id) {
    emit(state.expandedId == id
        ? state.copyWith(clearExpanded: true)
        : state.copyWith(expandedId: id));
  }

  SetInput _inputFor(String id) =>
      state.inputs[id] ?? const SetInput(weightG: 0, reps: 0);

  Map<String, SetInput> _withInput(String id, SetInput next) {
    final map = Map<String, SetInput>.from(state.inputs);
    map[id] = next;
    return map;
  }

  void stepWeight(String id, int deltaG) {
    final cur = _inputFor(id);
    final next = (cur.weightG + deltaG).clamp(0, 1 << 30);
    emit(state.copyWith(inputs: _withInput(id, cur.copyWith(weightG: next))));
  }

  /// Direct set from typed input (tap-to-type on the stepper value).
  void setWeightG(String id, int grams) {
    final cur = _inputFor(id);
    final next = grams.clamp(0, 1 << 30);
    emit(state.copyWith(inputs: _withInput(id, cur.copyWith(weightG: next))));
  }

  void setReps(String id, int reps) {
    final cur = _inputFor(id);
    final next = reps.clamp(0, 999);
    emit(state.copyWith(inputs: _withInput(id, cur.copyWith(reps: next))));
  }

  void setRir(String id, int? rir) {
    final cur = _inputFor(id);
    emit(state.copyWith(
      inputs: _withInput(
        id,
        rir == null ? cur.copyWith(clearRir: true) : cur.copyWith(rir: rir.clamp(0, 20)),
      ),
    ));
  }

  void stepReps(String id, int delta) {
    final cur = _inputFor(id);
    final next = (cur.reps + delta).clamp(0, 999);
    emit(state.copyWith(inputs: _withInput(id, cur.copyWith(reps: next))));
  }

  void stepRir(String id, int delta) {
    final cur = _inputFor(id);
    if (delta > 0) {
      final next = ((cur.rir ?? -1) + 1).clamp(0, 20);
      emit(state.copyWith(inputs: _withInput(id, cur.copyWith(rir: next))));
    } else {
      if (cur.rir == null) return;
      final next = cur.rir! - 1;
      emit(state.copyWith(
        inputs: _withInput(
          id,
          next < 0 ? cur.copyWith(clearRir: true) : cur.copyWith(rir: next),
        ),
      ));
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Single 1-second ticker. Everything is derived from wall-clock anchors so
  /// the elapsed clock and the rest countdown stay correct even after the app
  /// was backgrounded (Dart timers pause while suspended). [#9]
  void _tick() {
    final start = _sessionStart;
    if (start == null) return;
    final now = DateTime.now();

    var rest = state.restRemaining;
    if (_restEnd != null) {
      final left = _restEnd!.difference(now).inSeconds;
      if (left <= 0) {
        rest = 0;
        _restEnd = null;
        if (!_restVibrated) {
          _restVibrated = true;
          _vibrate(); // buzz on the start of the new set
        }
      } else {
        rest = left;
      }
    }

    final elapsed = now.difference(start).inSeconds;
    emit(state.copyWith(
      elapsedSeconds: elapsed < 0 ? 0 : elapsed,
      restRemaining: rest,
    ));
  }

  // ---------- rest timer between sets ----------

  /// Start (or restart) the rest countdown and arm the lock-screen alarm.
  void startRest(int seconds) {
    if (seconds <= 0) return;
    _restEnd = DateTime.now().add(Duration(seconds: seconds));
    _restVibrated = false;
    _restAlarm.schedule(seconds);
    emit(state.copyWith(restRemaining: seconds, restTotal: seconds));
  }

  /// Add time to a running rest countdown (e.g. "+30 s").
  void addRest(int seconds) {
    if (_restEnd == null) {
      startRest(seconds);
      return;
    }
    _restEnd = _restEnd!.add(Duration(seconds: seconds));
    _restVibrated = false;
    final left = _restEnd!.difference(DateTime.now()).inSeconds;
    _restAlarm.schedule(left);
    emit(state.copyWith(
      restRemaining: left < 0 ? 0 : left,
      restTotal: state.restTotal + seconds,
    ));
  }

  /// Skip the rest immediately.
  void skipRest() {
    _restEnd = null;
    _restVibrated = false;
    _restAlarm.cancel();
    emit(state.copyWith(restRemaining: 0));
  }

  Future<void> _vibrate() async {
    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: const [0, 350, 200, 350]);
      }
    } catch (_) {}
  }

  /// Log one set for [item]. Lazily starts the session (and timer) on the
  /// first set. Returns false on failure (error is placed in state).
  Future<bool> logSet(PlanItem item) async {
    if (state.busy) return false;
    final re = item.routineExercise;
    final input = _inputFor(re.id);
    final today = state.today;
    if (today == null) return false;

    emit(state.copyWith(busy: true, error: null));
    try {
      var sessionId = state.sessionId;
      if (sessionId == null) {
        final started =
            await _repo.startSession(today.routineId, today.sessionIndex);
        sessionId = started.sessionId;
        _sessionStart = DateTime.now();
        emit(state.copyWith(sessionId: sessionId, elapsedSeconds: 0));
        _startTimer();
      }

      final existing = state.logged[re.id] ?? const [];
      final setNumber = existing.length + 1;
      final setId = await _repo.logSet(
        sessionId,
        exerciseId: item.exercise.id,
        setNumber: setNumber,
        weightG: input.weightG,
        reps: input.reps,
        rir: input.rir,
        isWarmup: re.section == 'warmup',
      );

      final logged = Map<String, List<LoggedSet>>.from(state.logged);
      logged[re.id] = [
        ...existing,
        LoggedSet(
            id: setId,
            weightG: input.weightG,
            reps: input.reps,
            rir: input.rir),
      ];
      emit(state.copyWith(logged: logged, busy: false));

      // Rest between working sets (skip the warmup/reab quick-logs).
      if (re.section == 'main') startRest(_kRestSeconds);
      return true;
    } on ApiException catch (e) {
      emit(state.copyWith(
          busy: false, error: e.message, unauthorized: e.isUnauthorized));
      return false;
    } catch (e) {
      emit(state.copyWith(busy: false, error: e.toString()));
      return false;
    }
  }

  /// Edit an already-logged set (tap its pill during the live session). [#6]
  Future<void> editLoggedSet(
    String reId,
    int index, {
    int? weightG,
    int? reps,
    int? rir,
    bool clearRir = false,
  }) async {
    final sessionId = state.sessionId;
    final list = state.logged[reId];
    if (sessionId == null || list == null || index < 0 || index >= list.length) {
      return;
    }
    final set = list[index];
    emit(state.copyWith(busy: true, error: null));
    try {
      await _repo.updateSet(sessionId, set.id,
          weightG: weightG, reps: reps, rir: rir);
      final logged = Map<String, List<LoggedSet>>.from(state.logged);
      final next = List<LoggedSet>.from(list);
      next[index] = set.copyWith(
        weightG: weightG,
        reps: reps,
        rir: rir,
        clearRir: clearRir,
      );
      logged[reId] = next;
      emit(state.copyWith(logged: logged, busy: false));
    } on ApiException catch (e) {
      emit(state.copyWith(
          busy: false, error: e.message, unauthorized: e.isUnauthorized));
    } catch (e) {
      emit(state.copyWith(busy: false, error: e.toString()));
    }
  }

  /// Delete an already-logged set (e.g. the last one). [#6]
  Future<void> deleteLoggedSet(String reId, int index) async {
    final sessionId = state.sessionId;
    final list = state.logged[reId];
    if (sessionId == null || list == null || index < 0 || index >= list.length) {
      return;
    }
    final set = list[index];
    emit(state.copyWith(busy: true, error: null));
    try {
      await _repo.deleteSet(sessionId, set.id);
      final logged = Map<String, List<LoggedSet>>.from(state.logged);
      final next = List<LoggedSet>.from(list)..removeAt(index);
      logged[reId] = next;
      emit(state.copyWith(logged: logged, busy: false));
    } on ApiException catch (e) {
      emit(state.copyWith(
          busy: false, error: e.message, unauthorized: e.isUnauthorized));
    } catch (e) {
      emit(state.copyWith(busy: false, error: e.toString()));
    }
  }

  Future<void> finish() async {
    final sessionId = state.sessionId;
    if (sessionId == null || state.busy) return;
    emit(state.copyWith(busy: true, error: null));
    try {
      final duration = await _repo.finish(sessionId);
      _timer?.cancel();
      _sessionStart = null;
      _restEnd = null;
      _restAlarm.cancel();
      emit(state.copyWith(
          busy: false, summaryDurationS: duration, restRemaining: 0));
    } on ApiException catch (e) {
      emit(state.copyWith(
          busy: false, error: e.message, unauthorized: e.isUnauthorized));
    } catch (e) {
      emit(state.copyWith(busy: false, error: e.toString()));
    }
  }

  /// Dismiss the summary dialog and reload a fresh plan.
  Future<void> dismissSummaryAndReload() async {
    emit(state.copyWith(clearSummary: true));
    await load();
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _restAlarm.cancel();
    return super.close();
  }
}
