import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';
import '../data/program_models.dart';
import '../data/program_repository.dart';

enum ProgramStatus { initial, loading, ready, error }

/// Section render order (warmup → main → reab).
const List<String> kSectionOrder = ['warmup', 'main', 'reab'];

class ProgramState extends Equatable {
  final ProgramStatus status;
  final List<Routine> routines;
  final Map<String, ProgramCatalogExercise> exercisesById;

  /// Loaded compositions, keyed by routineId.
  final Map<String, List<ProgramExercise>> composition;

  /// Expanded routine cards (routineId).
  final Set<String> expandedRoutines;

  /// Expanded sections, keyed "routineId::section".
  final Set<String> expandedSections;

  /// Routines whose composition is currently being fetched.
  final Set<String> loadingRoutines;

  final String? error;
  final bool unauthorized;

  const ProgramState({
    this.status = ProgramStatus.initial,
    this.routines = const [],
    this.exercisesById = const {},
    this.composition = const {},
    this.expandedRoutines = const {},
    this.expandedSections = const {},
    this.loadingRoutines = const {},
    this.error,
    this.unauthorized = false,
  });

  ProgramState copyWith({
    ProgramStatus? status,
    List<Routine>? routines,
    Map<String, ProgramCatalogExercise>? exercisesById,
    Map<String, List<ProgramExercise>>? composition,
    Set<String>? expandedRoutines,
    Set<String>? expandedSections,
    Set<String>? loadingRoutines,
    String? error,
    bool? unauthorized,
  }) {
    return ProgramState(
      status: status ?? this.status,
      routines: routines ?? this.routines,
      exercisesById: exercisesById ?? this.exercisesById,
      composition: composition ?? this.composition,
      expandedRoutines: expandedRoutines ?? this.expandedRoutines,
      expandedSections: expandedSections ?? this.expandedSections,
      loadingRoutines: loadingRoutines ?? this.loadingRoutines,
      error: error,
      unauthorized: unauthorized ?? this.unauthorized,
    );
  }

  String exerciseName(String exerciseId) =>
      exercisesById[exerciseId]?.displayName ?? 'Упражнение';

  @override
  List<Object?> get props => [
        status,
        routines,
        exercisesById,
        composition,
        expandedRoutines,
        expandedSections,
        loadingRoutines,
        error,
        unauthorized,
      ];
}

class ProgramCubit extends Cubit<ProgramState> {
  final ProgramRepository _repo;
  ProgramCubit(this._repo) : super(const ProgramState());

  Future<void> load() async {
    emit(const ProgramState(status: ProgramStatus.loading));
    try {
      final routines = await _repo.routines();
      final exercises = await _repo.exercisesById();
      emit(state.copyWith(
        status: ProgramStatus.ready,
        routines: routines,
        exercisesById: exercises,
        composition: const {},
        expandedRoutines: const {},
        expandedSections: const {},
        loadingRoutines: const {},
      ));
      // Auto-expand the first routine (matches the design).
      if (routines.isNotEmpty) {
        await toggleRoutine(routines.first.id);
      }
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: ProgramStatus.error,
        error: e.message,
        unauthorized: e.isUnauthorized,
      ));
    } catch (e) {
      emit(state.copyWith(status: ProgramStatus.error, error: e.toString()));
    }
  }

  Future<void> toggleRoutine(String routineId) async {
    if (state.expandedRoutines.contains(routineId)) {
      final next = Set<String>.from(state.expandedRoutines)..remove(routineId);
      emit(state.copyWith(expandedRoutines: next));
      return;
    }
    final next = Set<String>.from(state.expandedRoutines)..add(routineId);
    emit(state.copyWith(expandedRoutines: next));
    if (!state.composition.containsKey(routineId)) {
      await _fetchComposition(routineId);
    }
  }

  Future<void> _fetchComposition(String routineId) async {
    emit(state.copyWith(
      loadingRoutines: {...state.loadingRoutines, routineId},
    ));
    try {
      final items = await _repo.routineExercises(routineId);
      final composition =
          Map<String, List<ProgramExercise>>.from(state.composition);
      composition[routineId] = items;
      // Expand the main section by default; keep warmup/reab collapsed.
      final sections = Set<String>.from(state.expandedSections)
        ..add('$routineId::main');
      final loading = Set<String>.from(state.loadingRoutines)
        ..remove(routineId);
      emit(state.copyWith(
        composition: composition,
        expandedSections: sections,
        loadingRoutines: loading,
      ));
    } on ApiException catch (e) {
      final loading = Set<String>.from(state.loadingRoutines)
        ..remove(routineId);
      emit(state.copyWith(
        loadingRoutines: loading,
        error: e.message,
        unauthorized: e.isUnauthorized,
      ));
    } catch (e) {
      final loading = Set<String>.from(state.loadingRoutines)
        ..remove(routineId);
      emit(state.copyWith(loadingRoutines: loading, error: e.toString()));
    }
  }

  void toggleSection(String routineId, String section) {
    final key = '$routineId::$section';
    final next = Set<String>.from(state.expandedSections);
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    emit(state.copyWith(expandedSections: next));
  }
}
