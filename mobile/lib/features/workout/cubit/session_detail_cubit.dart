import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';
import '../data/workout_models.dart';
import '../data/workout_repository.dart';

enum SessionDetailStatus { initial, loading, ready, error }

class SessionDetailState extends Equatable {
  final SessionDetailStatus status;
  final SessionDetail? detail;

  /// exerciseId → weight increment (grams). Falls back to 2500g.
  final Map<String, int> incrementByExercise;

  final String? error;
  final bool unauthorized;
  final bool busy;

  /// Flips true once the whole session was deleted → the page pops.
  final bool deleted;

  const SessionDetailState({
    this.status = SessionDetailStatus.initial,
    this.detail,
    this.incrementByExercise = const {},
    this.error,
    this.unauthorized = false,
    this.busy = false,
    this.deleted = false,
  });

  int incrementFor(String exerciseId) =>
      incrementByExercise[exerciseId] ?? 2500;

  SessionDetailState copyWith({
    SessionDetailStatus? status,
    SessionDetail? detail,
    Map<String, int>? incrementByExercise,
    String? error,
    bool? unauthorized,
    bool? busy,
    bool? deleted,
  }) {
    return SessionDetailState(
      status: status ?? this.status,
      detail: detail ?? this.detail,
      incrementByExercise: incrementByExercise ?? this.incrementByExercise,
      error: error,
      unauthorized: unauthorized ?? this.unauthorized,
      busy: busy ?? this.busy,
      deleted: deleted ?? this.deleted,
    );
  }

  @override
  List<Object?> get props =>
      [status, detail, incrementByExercise, error, unauthorized, busy, deleted];
}

class SessionDetailCubit extends Cubit<SessionDetailState> {
  final WorkoutRepository _repo;
  final String sessionId;

  SessionDetailCubit(this._repo, this.sessionId)
      : super(const SessionDetailState());

  Future<void> load() async {
    emit(state.copyWith(status: SessionDetailStatus.loading));
    try {
      final detail = await _repo.sessionDetail(sessionId);
      Map<String, int> increments = state.incrementByExercise;
      if (increments.isEmpty) {
        try {
          final exercises = await _repo.exercises();
          increments = {for (final e in exercises) e.id: e.minIncrementG};
        } catch (_) {
          // Increments are a nicety; the sheet falls back to 2500g.
        }
      }
      emit(state.copyWith(
        status: SessionDetailStatus.ready,
        detail: detail,
        incrementByExercise: increments,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: SessionDetailStatus.error,
        error: e.message,
        unauthorized: e.isUnauthorized,
      ));
    } catch (e) {
      emit(state.copyWith(
          status: SessionDetailStatus.error, error: e.toString()));
    }
  }

  Future<void> editSet(
    String setId, {
    required int weightG,
    required int reps,
    int? rir,
  }) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, error: null));
    try {
      await _repo.updateSet(sessionId, setId,
          weightG: weightG, reps: reps, rir: rir);
      emit(state.copyWith(busy: false));
      await load();
    } on ApiException catch (e) {
      emit(state.copyWith(
          busy: false, error: e.message, unauthorized: e.isUnauthorized));
    } catch (e) {
      emit(state.copyWith(busy: false, error: e.toString()));
    }
  }

  Future<void> deleteSet(String setId) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, error: null));
    try {
      await _repo.deleteSet(sessionId, setId);
      emit(state.copyWith(busy: false));
      await load();
    } on ApiException catch (e) {
      emit(state.copyWith(
          busy: false, error: e.message, unauthorized: e.isUnauthorized));
    } catch (e) {
      emit(state.copyWith(busy: false, error: e.toString()));
    }
  }

  Future<void> deleteSession() async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, error: null));
    try {
      await _repo.deleteSession(sessionId);
      emit(state.copyWith(busy: false, deleted: true));
    } on ApiException catch (e) {
      emit(state.copyWith(
          busy: false, error: e.message, unauthorized: e.isUnauthorized));
    } catch (e) {
      emit(state.copyWith(busy: false, error: e.toString()));
    }
  }
}
