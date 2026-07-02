import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../data/factors_models.dart';
import '../data/factors_repository.dart';

enum FactorsStatus { initial, loading, ready, error }

class FactorsState extends Equatable {
  final FactorsStatus status;
  final List<FactorGroup> groups;

  /// Working values keyed by factorId (seeded from existing logs).
  final Map<String, int> values;

  final String? error;
  final bool unauthorized;

  /// True while a bulk-save is in flight.
  final bool saving;

  /// Non-null right after a successful save → drives the success snackbar.
  final String? savedMessage;

  const FactorsState({
    this.status = FactorsStatus.initial,
    this.groups = const [],
    this.values = const {},
    this.error,
    this.unauthorized = false,
    this.saving = false,
    this.savedMessage,
  });

  FactorsState copyWith({
    FactorsStatus? status,
    List<FactorGroup>? groups,
    Map<String, int>? values,
    String? error,
    bool? unauthorized,
    bool? saving,
    String? savedMessage,
    bool clearError = false,
    bool clearSavedMessage = false,
  }) {
    return FactorsState(
      status: status ?? this.status,
      groups: groups ?? this.groups,
      values: values ?? this.values,
      error: clearError ? null : (error ?? this.error),
      unauthorized: unauthorized ?? this.unauthorized,
      saving: saving ?? this.saving,
      savedMessage:
          clearSavedMessage ? null : (savedMessage ?? this.savedMessage),
    );
  }

  @override
  List<Object?> get props =>
      [status, groups, values, error, unauthorized, saving, savedMessage];
}

class FactorsCubit extends Cubit<FactorsState> {
  final FactorsRepository _repo;
  FactorsCubit(this._repo) : super(const FactorsState());

  static String todayStr() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> load() async {
    emit(state.copyWith(
        status: FactorsStatus.loading, unauthorized: false, clearError: true));
    try {
      final groups = await _repo.load(todayStr());
      final values = <String, int>{};
      for (final g in groups) {
        for (final f in g.factors) {
          if (f.value != null) values[f.factor.id] = f.value!;
        }
      }
      emit(state.copyWith(
        status: FactorsStatus.ready,
        groups: groups,
        values: values,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: FactorsStatus.error,
        error: e.message,
        unauthorized: e.isUnauthorized,
      ));
    } catch (e) {
      emit(state.copyWith(status: FactorsStatus.error, error: e.toString()));
    }
  }

  /// Set a rating chip value (idempotent).
  void setValue(String factorId, int value) {
    final next = Map<String, int>.from(state.values)..[factorId] = value;
    emit(state.copyWith(values: next));
  }

  /// Step a count value by [delta], clamped to [min] (no upper cap).
  void step(String factorId, int delta, {int min = 0}) {
    final current = state.values[factorId] ?? 0;
    final value = (current + delta).clamp(min, 1 << 30);
    final next = Map<String, int>.from(state.values)..[factorId] = value;
    emit(state.copyWith(values: next));
  }

  Future<void> save() async {
    if (state.saving) return;
    if (state.values.isEmpty) {
      emit(state.copyWith(savedMessage: 'Нет значений для сохранения'));
      emit(state.copyWith(clearSavedMessage: true));
      return;
    }
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await _repo.saveBulk(todayStr(), state.values);
      final groups = await _repo.load(todayStr());
      emit(state.copyWith(
        saving: false,
        groups: groups,
        savedMessage: 'Сохранено',
      ));
      emit(state.copyWith(clearSavedMessage: true));
    } on ApiException catch (e) {
      emit(state.copyWith(
        saving: false,
        error: e.message,
        unauthorized: e.isUnauthorized,
      ));
      emit(state.copyWith(clearError: true));
    } catch (e) {
      emit(state.copyWith(saving: false, error: e.toString()));
      emit(state.copyWith(clearError: true));
    }
  }
}
