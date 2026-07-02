import 'package:equatable/equatable.dart';

/// GET /api/v1/training/today
class TrainingToday extends Equatable {
  final String routineId;
  final int sessionIndex;
  final bool isRampup;

  const TrainingToday({
    required this.routineId,
    required this.sessionIndex,
    required this.isRampup,
  });

  factory TrainingToday.fromJson(Map<String, dynamic> j) => TrainingToday(
        routineId: j['routine_id'].toString(),
        sessionIndex: (j['session_index'] as num).toInt(),
        isRampup: j['is_rampup'] == true,
      );

  @override
  List<Object?> get props => [routineId, sessionIndex, isRampup];
}

class RoutineExercise extends Equatable {
  final String id;
  final String exerciseId;
  final String section; // warmup | main | reab
  final int targetSets;
  final int repMin;
  final int repMax;
  final int? targetRir;

  const RoutineExercise({
    required this.id,
    required this.exerciseId,
    required this.section,
    required this.targetSets,
    required this.repMin,
    required this.repMax,
    required this.targetRir,
  });

  factory RoutineExercise.fromJson(Map<String, dynamic> j) => RoutineExercise(
        id: j['id'].toString(),
        exerciseId: j['exerciseId'].toString(),
        section: (j['section'] ?? 'main').toString(),
        targetSets: (j['targetSets'] as num?)?.toInt() ?? 1,
        repMin: (j['repMin'] as num?)?.toInt() ?? 0,
        repMax: (j['repMax'] as num?)?.toInt() ?? 0,
        targetRir: (j['targetRir'] as num?)?.toInt(),
      );

  /// "3×8-10" style target label.
  String get repsLabel =>
      repMin == repMax ? '$repMin' : '$repMin-$repMax';
  String get setsRepsLabel => '$targetSets×$repsLabel';

  @override
  List<Object?> get props =>
      [id, exerciseId, section, targetSets, repMin, repMax, targetRir];
}

class Exercise extends Equatable {
  final String id;
  final String name;
  final String nameRu;
  final String? cuesRu;
  final int minIncrementG;

  const Exercise({
    required this.id,
    required this.name,
    required this.nameRu,
    required this.cuesRu,
    required this.minIncrementG,
  });

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        id: j['id'].toString(),
        name: (j['name'] ?? '').toString(),
        nameRu: (j['nameRu'] ?? j['name'] ?? '').toString(),
        cuesRu: j['cuesRu']?.toString(),
        minIncrementG: (j['minIncrementG'] as num?)?.toInt() ?? 2500,
      );

  String get displayName => nameRu.isNotEmpty ? nameRu : name;

  @override
  List<Object?> get props => [id, name, nameRu, cuesRu, minIncrementG];
}

class LastPerformance extends Equatable {
  final int weightG;
  final String weightFormatted;
  final int reps;
  final int? rir;

  const LastPerformance({
    required this.weightG,
    required this.weightFormatted,
    required this.reps,
    required this.rir,
  });

  factory LastPerformance.fromJson(Map<String, dynamic> j) => LastPerformance(
        weightG: (j['weightG'] as num?)?.toInt() ?? 0,
        weightFormatted: (j['weightFormatted'] ?? '').toString(),
        reps: (j['reps'] as num?)?.toInt() ?? 0,
        rir: (j['rir'] as num?)?.toInt(),
      );

  @override
  List<Object?> get props => [weightG, weightFormatted, reps, rir];
}

class Suggestion extends Equatable {
  final String action;
  final int weightG;
  final String weightFormatted;
  final int repsTarget;
  final int? rirTarget;
  final String rationale;

  const Suggestion({
    required this.action,
    required this.weightG,
    required this.weightFormatted,
    required this.repsTarget,
    required this.rirTarget,
    required this.rationale,
  });

  factory Suggestion.fromJson(Map<String, dynamic> j) => Suggestion(
        action: (j['action'] ?? '').toString(),
        weightG: (j['weightG'] as num?)?.toInt() ?? 0,
        weightFormatted: (j['weightFormatted'] ?? '').toString(),
        repsTarget: (j['repsTarget'] as num?)?.toInt() ?? 0,
        rirTarget: (j['rirTarget'] as num?)?.toInt(),
        rationale: (j['rationale'] ?? '').toString(),
      );

  @override
  List<Object?> get props =>
      [action, weightG, weightFormatted, repsTarget, rirTarget, rationale];
}

class PlanItem extends Equatable {
  final RoutineExercise routineExercise;
  final Exercise exercise;
  final List<LastPerformance> lastPerformance;
  final Suggestion? suggestion;

  const PlanItem({
    required this.routineExercise,
    required this.exercise,
    required this.lastPerformance,
    required this.suggestion,
  });

  factory PlanItem.fromJson(Map<String, dynamic> j) => PlanItem(
        routineExercise:
            RoutineExercise.fromJson(j['routineExercise'] as Map<String, dynamic>),
        exercise: Exercise.fromJson(j['exercise'] as Map<String, dynamic>),
        lastPerformance: ((j['lastPerformance'] as List?) ?? const [])
            .map((e) => LastPerformance.fromJson(e as Map<String, dynamic>))
            .toList(),
        suggestion: j['suggestion'] == null
            ? null
            : Suggestion.fromJson(j['suggestion'] as Map<String, dynamic>),
      );

  LastPerformance? get last =>
      lastPerformance.isNotEmpty ? lastPerformance.first : null;

  @override
  List<Object?> get props =>
      [routineExercise, exercise, lastPerformance, suggestion];
}

class WorkoutPlan extends Equatable {
  final String routineName;
  final String routineNameRu;
  final int sessionIndex;
  final bool isRampup;
  final List<PlanItem> warmup;
  final List<PlanItem> main;
  final List<PlanItem> reab;

  const WorkoutPlan({
    required this.routineName,
    required this.routineNameRu,
    required this.sessionIndex,
    required this.isRampup,
    required this.warmup,
    required this.main,
    required this.reab,
  });

  factory WorkoutPlan.fromJson(Map<String, dynamic> j) {
    final routine = (j['routine'] as Map<String, dynamic>?) ?? const {};
    final sections = (j['sections'] as Map<String, dynamic>?) ?? const {};
    List<PlanItem> parse(String key) => ((sections[key] as List?) ?? const [])
        .map((e) => PlanItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return WorkoutPlan(
      routineName: (routine['name'] ?? '').toString(),
      routineNameRu: (routine['nameRu'] ?? routine['name'] ?? '').toString(),
      sessionIndex: (j['sessionIndex'] as num?)?.toInt() ?? 0,
      isRampup: j['isRampup'] == true,
      warmup: parse('warmup'),
      main: parse('main'),
      reab: parse('reab'),
    );
  }

  String get displayName =>
      routineNameRu.isNotEmpty ? routineNameRu : routineName;

  List<PlanItem> get all => [...warmup, ...main, ...reab];

  @override
  List<Object?> get props =>
      [routineName, routineNameRu, sessionIndex, isRampup, warmup, main, reab];
}

/// POST /api/v1/training/sessions
class SessionStart extends Equatable {
  final String sessionId;
  final int sessionIndex;

  const SessionStart({required this.sessionId, required this.sessionIndex});

  factory SessionStart.fromJson(Map<String, dynamic> j) => SessionStart(
        sessionId: j['session_id'].toString(),
        sessionIndex: (j['session_index'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [sessionId, sessionIndex];
}

/// Ephemeral per-exercise input (weight/reps/rir), kept in cubit state.
class SetInput extends Equatable {
  final int weightG;
  final int reps;
  final int? rir;

  const SetInput({required this.weightG, required this.reps, this.rir});

  SetInput copyWith({int? weightG, int? reps, int? rir, bool clearRir = false}) =>
      SetInput(
        weightG: weightG ?? this.weightG,
        reps: reps ?? this.reps,
        rir: clearRir ? null : (rir ?? this.rir),
      );

  @override
  List<Object?> get props => [weightG, reps, rir];
}

/// A set already logged this session (for the "Готово" chips).
class LoggedSet extends Equatable {
  final int weightG;
  final int reps;
  final int? rir;

  const LoggedSet({required this.weightG, required this.reps, this.rir});

  @override
  List<Object?> get props => [weightG, reps, rir];
}
