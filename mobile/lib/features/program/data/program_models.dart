import 'package:equatable/equatable.dart';

/// A workout template (Тренировка A / B / ...).
/// GET /api/v1/training/routines
class Routine extends Equatable {
  final String id;
  final String name;
  final String nameRu;
  final String? notes;
  final int sortOrder;

  const Routine({
    required this.id,
    required this.name,
    required this.nameRu,
    required this.notes,
    required this.sortOrder,
  });

  factory Routine.fromJson(Map<String, dynamic> j) => Routine(
        id: j['id'].toString(),
        name: (j['name'] ?? '').toString(),
        nameRu: (j['nameRu'] ?? j['name'] ?? '').toString(),
        notes: j['notes']?.toString(),
        sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      );

  String get displayName => nameRu.isNotEmpty ? nameRu : name;

  /// Single-letter badge (e.g. "A" / "B"). Prefers the latin [name].
  String get badge {
    final source = name.isNotEmpty ? name : nameRu;
    final trimmed = source.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(trimmed.length - 1).toUpperCase();
  }

  @override
  List<Object?> get props => [id, name, nameRu, notes, sortOrder];
}

/// A position inside a routine (warmup / main / reab section).
/// GET /api/v1/training/routines/:id/exercises
class ProgramExercise extends Equatable {
  final String id;
  final String exerciseId;
  final String section; // warmup | main | reab
  final int sortOrder;
  final int targetSets;
  final int repMin;
  final int repMax;
  final int? targetRir;

  const ProgramExercise({
    required this.id,
    required this.exerciseId,
    required this.section,
    required this.sortOrder,
    required this.targetSets,
    required this.repMin,
    required this.repMax,
    required this.targetRir,
  });

  factory ProgramExercise.fromJson(Map<String, dynamic> j) => ProgramExercise(
        id: j['id'].toString(),
        exerciseId: j['exerciseId'].toString(),
        section: (j['section'] ?? 'main').toString(),
        sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
        targetSets: (j['targetSets'] as num?)?.toInt() ?? 1,
        repMin: (j['repMin'] as num?)?.toInt() ?? 0,
        repMax: (j['repMax'] as num?)?.toInt() ?? 0,
        targetRir: (j['targetRir'] as num?)?.toInt(),
      );

  /// "3×10–12 · RIR 1–2" style target label.
  String get targetLabel {
    final reps = repMin == repMax ? '$repMin' : '$repMin–$repMax';
    final base = '$targetSets×$reps';
    return targetRir == null ? base : '$base · RIR $targetRir';
  }

  @override
  List<Object?> get props =>
      [id, exerciseId, section, sortOrder, targetSets, repMin, repMax, targetRir];
}

/// Exercise catalog entry. GET /api/v1/training/exercises
class ProgramCatalogExercise extends Equatable {
  final String id;
  final String name;
  final String nameRu;
  final String? muscleGroup;

  const ProgramCatalogExercise({
    required this.id,
    required this.name,
    required this.nameRu,
    required this.muscleGroup,
  });

  factory ProgramCatalogExercise.fromJson(Map<String, dynamic> j) =>
      ProgramCatalogExercise(
        id: j['id'].toString(),
        name: (j['name'] ?? '').toString(),
        nameRu: (j['nameRu'] ?? j['name'] ?? '').toString(),
        muscleGroup: j['muscleGroup']?.toString(),
      );

  String get displayName => nameRu.isNotEmpty ? nameRu : name;

  @override
  List<Object?> get props => [id, name, nameRu, muscleGroup];
}
