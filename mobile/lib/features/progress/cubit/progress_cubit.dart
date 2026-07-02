import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';
import '../data/progress_models.dart';
import '../data/progress_repository.dart';

enum ProgressStatus { initial, loading, ready, error }

class ProgressState extends Equatable {
  final ProgressStatus status;
  final ProgressData? data;
  final ProgressRange range;
  final String exerciseId;
  final String? error;
  final bool unauthorized;

  const ProgressState({
    this.status = ProgressStatus.initial,
    this.data,
    this.range = ProgressRange.month,
    this.exerciseId = 'ex-bench_press',
    this.error,
    this.unauthorized = false,
  });

  ProgressState copyWith({
    ProgressStatus? status,
    ProgressData? data,
    ProgressRange? range,
    String? exerciseId,
    String? error,
    bool? unauthorized,
  }) {
    return ProgressState(
      status: status ?? this.status,
      data: data ?? this.data,
      range: range ?? this.range,
      exerciseId: exerciseId ?? this.exerciseId,
      error: error,
      unauthorized: unauthorized ?? this.unauthorized,
    );
  }

  @override
  List<Object?> get props =>
      [status, data, range, exerciseId, error, unauthorized];
}

class ProgressCubit extends Cubit<ProgressState> {
  final ProgressRepository _repo;

  ProgressCubit(this._repo) : super(const ProgressState());

  Future<void> load() async {
    emit(state.copyWith(status: ProgressStatus.loading, error: null));
    try {
      final data = await _repo.load(state.range, state.exerciseId);
      emit(state.copyWith(status: ProgressStatus.ready, data: data));
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: ProgressStatus.error,
        error: e.message,
        unauthorized: e.isUnauthorized,
      ));
    } catch (e) {
      emit(state.copyWith(status: ProgressStatus.error, error: e.toString()));
    }
  }

  Future<void> selectRange(ProgressRange range) async {
    if (range == state.range) return;
    emit(state.copyWith(range: range));
    await load();
  }

  Future<void> selectLift(String exerciseId) async {
    if (exerciseId == state.exerciseId) return;
    emit(state.copyWith(exerciseId: exerciseId));
    // Only the progression card depends on the lift; reloading all is cheap
    // and keeps the state consistent.
    await load();
  }
}
