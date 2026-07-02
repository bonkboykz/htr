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

  /// True while a create/update/delete mutation is in flight.
  final bool mutating;

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
    this.mutating = false,
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
    bool? mutating,
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
      mutating: mutating ?? this.mutating,
      error: error,
      unauthorized: unauthorized ?? this.unauthorized,
    );
  }

  String exerciseName(String exerciseId) =>
      exercisesById[exerciseId]?.displayName ?? 'Упражнение';

  /// Catalog as a list sorted by Russian display name (for the picker).
  List<ProgramCatalogExercise> get catalog {
    final list = exercisesById.values.toList();
    list.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return list;
  }

  @override
  List<Object?> get props => [
        status,
        routines,
        exercisesById,
        composition,
        expandedRoutines,
        expandedSections,
        loadingRoutines,
        mutating,
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

  // ---------- catalog ----------

  /// Ensure the exercise catalog is loaded (used by the picker).
  Future<void> loadCatalog() async {
    if (state.exercisesById.isNotEmpty) return;
    try {
      final exercises = await _repo.exercisesById();
      emit(state.copyWith(exercisesById: exercises));
    } on ApiException catch (e) {
      _emitError(e);
    } catch (e) {
      _emitError(e);
    }
  }

  // ---------- mutations ----------

  Future<void> createRoutine({required String nameRu, String? notes}) async {
    await _mutate(() async {
      final r = await _repo.createRoutine(
        name: nameRu,
        nameRu: nameRu,
        notes: notes,
      );
      return {r.id};
    });
  }

  Future<void> updateRoutine(
    String id, {
    required String nameRu,
    String? notes,
  }) async {
    await _mutate(() async {
      await _repo.updateRoutine(id, nameRu: nameRu, notes: notes ?? '');
      return const <String>{};
    });
  }

  Future<void> deleteRoutine(String id) async {
    await _mutate(() async {
      await _repo.deleteRoutine(id);
      return const <String>{};
    });
  }

  Future<void> addExercise(
    String routineId, {
    required String exerciseId,
    required String section,
    required int targetSets,
    required int repMin,
    required int repMax,
    int? targetRir,
  }) async {
    await _mutate(() async {
      await _repo.addExercise(
        routineId,
        exerciseId: exerciseId,
        section: section,
        targetSets: targetSets,
        repMin: repMin,
        repMax: repMax,
        targetRir: targetRir,
      );
      return {routineId};
    });
  }

  Future<void> updateExercise(
    String routineId,
    String reId, {
    String? exerciseId,
    String? section,
    int? targetSets,
    int? repMin,
    int? repMax,
    int? targetRir,
  }) async {
    await _mutate(() async {
      await _repo.updateExercise(
        routineId,
        reId,
        exerciseId: exerciseId,
        section: section,
        targetSets: targetSets,
        repMin: repMin,
        repMax: repMax,
        targetRir: targetRir,
      );
      return {routineId};
    });
  }

  Future<void> deleteExercise(String routineId, String reId) async {
    await _mutate(() async {
      await _repo.deleteExercise(routineId, reId);
      return {routineId};
    });
  }

  /// Runs [action] (which returns routine ids to keep expanded), then reloads.
  Future<void> _mutate(Future<Set<String>> Function() action) async {
    emit(state.copyWith(mutating: true, error: null));
    try {
      final expand = await action();
      await _reload(expandRoutineIds: expand);
    } on ApiException catch (e) {
      _emitError(e);
    } catch (e) {
      _emitError(e);
    }
  }

  /// Refetch routines + catalog, preserving (and optionally extending) the set
  /// of expanded routines, and re-fetch their compositions.
  Future<void> _reload({Set<String> expandRoutineIds = const {}}) async {
    final routines = await _repo.routines();
    final exercises = await _repo.exercisesById();
    final existingIds = routines.map((r) => r.id).toSet();
    final expanded = <String>{...state.expandedRoutines, ...expandRoutineIds}
        .where(existingIds.contains)
        .toSet();

    final composition = <String, List<ProgramExercise>>{};
    for (final id in expanded) {
      composition[id] = await _repo.routineExercises(id);
    }

    final sections = state.expandedSections
        .where((k) => expanded.contains(k.split('::').first))
        .toSet();
    for (final id in expandRoutineIds) {
      if (existingIds.contains(id)) sections.add('$id::main');
    }

    emit(state.copyWith(
      status: ProgramStatus.ready,
      mutating: false,
      routines: routines,
      exercisesById: exercises,
      composition: composition,
      expandedRoutines: expanded,
      expandedSections: sections,
      loadingRoutines: const {},
      error: null,
    ));
  }

  void _emitError(Object e) {
    if (e is ApiException) {
      emit(state.copyWith(
        mutating: false,
        error: e.message,
        unauthorized: e.isUnauthorized,
      ));
    } else {
      emit(state.copyWith(mutating: false, error: e.toString()));
    }
  }
}
