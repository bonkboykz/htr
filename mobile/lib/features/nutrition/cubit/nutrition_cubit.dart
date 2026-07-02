import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../data/nutrition_models.dart';
import '../data/nutrition_repository.dart';

enum NutritionStatus { initial, loading, ready, error }

class NutritionState extends Equatable {
  final NutritionStatus status;
  final NutritionDay? data;
  final String? error;
  final bool unauthorized;

  /// True while a mutation (quick-log / delete) is in flight.
  final bool mutating;

  const NutritionState({
    this.status = NutritionStatus.initial,
    this.data,
    this.error,
    this.unauthorized = false,
    this.mutating = false,
  });

  NutritionState copyWith({
    NutritionStatus? status,
    NutritionDay? data,
    String? error,
    bool? unauthorized,
    bool? mutating,
  }) =>
      NutritionState(
        status: status ?? this.status,
        data: data ?? this.data,
        error: error,
        unauthorized: unauthorized ?? this.unauthorized,
        mutating: mutating ?? this.mutating,
      );

  @override
  List<Object?> get props => [status, data, error, unauthorized, mutating];
}

class NutritionCubit extends Cubit<NutritionState> {
  final NutritionRepository _repo;
  NutritionCubit(this._repo) : super(const NutritionState());

  static String _todayStr() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> load() async {
    emit(state.copyWith(status: NutritionStatus.loading));
    try {
      final data = await _repo.load(_todayStr());
      emit(state.copyWith(status: NutritionStatus.ready, data: data));
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: NutritionStatus.error,
        error: e.message,
        unauthorized: e.isUnauthorized,
      ));
    } catch (e) {
      emit(state.copyWith(status: NutritionStatus.error, error: e.toString()));
    }
  }

  Future<void> quickLog(QuickLogInput input) async {
    emit(state.copyWith(mutating: true));
    try {
      await _repo.quickLog(_todayStr(), input);
    } catch (_) {
      // reload below reflects the true state either way
    }
    emit(state.copyWith(mutating: false));
    await load();
  }

  Future<void> deleteEntry(String id) async {
    emit(state.copyWith(mutating: true));
    try {
      await _repo.deleteEntry(id);
    } catch (_) {
      // ignore; reload reflects the true state
    }
    emit(state.copyWith(mutating: false));
    await load();
  }
}
