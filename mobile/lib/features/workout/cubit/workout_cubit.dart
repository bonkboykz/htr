import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';
import '../data/workout_models.dart';
import '../data/workout_repository.dart';

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
      ];
}

class WorkoutCubit extends Cubit<WorkoutState> {
  final WorkoutRepository _repo;
  Timer? _timer;

  WorkoutCubit(this._repo) : super(const WorkoutState());

  Future<void> load() async {
    _timer?.cancel();
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
      (map[reId] ??= <LoggedSet>[])
          .add(LoggedSet(weightG: s.weightG, reps: s.reps, rir: s.rir));
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
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.sessionActive) return;
      emit(state.copyWith(elapsedSeconds: state.elapsedSeconds + 1));
    });
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
        emit(state.copyWith(sessionId: sessionId, elapsedSeconds: 0));
        _startTimer();
      }

      final existing = state.logged[re.id] ?? const [];
      final setNumber = existing.length + 1;
      await _repo.logSet(
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
        LoggedSet(weightG: input.weightG, reps: input.reps, rir: input.rir),
      ];
      emit(state.copyWith(logged: logged, busy: false));
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

  Future<void> finish() async {
    final sessionId = state.sessionId;
    if (sessionId == null || state.busy) return;
    emit(state.copyWith(busy: true, error: null));
    try {
      final duration = await _repo.finish(sessionId);
      _timer?.cancel();
      emit(state.copyWith(busy: false, summaryDurationS: duration));
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
    return super.close();
  }
}
