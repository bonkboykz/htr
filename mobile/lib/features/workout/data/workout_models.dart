import 'dart:convert';

import 'package:equatable/equatable.dart';

/// Muscle-group id → Russian label (matches the backend `muscle_group` values).
const _muscleRu = {
  'core': 'кор',
  'shoulders': 'плечи',
  'quads': 'квадрицепс',
  'chest': 'грудь',
  'back': 'спина',
  'hamstrings': 'бицепс бедра',
  'glutes': 'ягодицы',
  'arms': 'руки',
};

/// Equipment tag → Russian label.
const _equipmentRu = {
  'barbell': 'штанга',
  'bench': 'скамья',
  'db': 'гантели',
  'cable': 'блок',
  'rope': 'канат',
  'machine': 'тренажёр',
  'mat': 'коврик',
  'leg_press': 'жим ногами',
  'handle': 'рукоять',
  'bar': 'гриф',
  'sandbag': 'мешок',
};

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
  final bool isOptional;

  const RoutineExercise({
    required this.id,
    required this.exerciseId,
    required this.section,
    required this.targetSets,
    required this.repMin,
    required this.repMax,
    required this.targetRir,
    this.isOptional = false,
  });

  factory RoutineExercise.fromJson(Map<String, dynamic> j) => RoutineExercise(
        id: j['id'].toString(),
        exerciseId: j['exerciseId'].toString(),
        section: (j['section'] ?? 'main').toString(),
        targetSets: (j['targetSets'] as num?)?.toInt() ?? 1,
        repMin: (j['repMin'] as num?)?.toInt() ?? 0,
        repMax: (j['repMax'] as num?)?.toInt() ?? 0,
        targetRir: (j['targetRir'] as num?)?.toInt(),
        isOptional: j['isOptional'] == true || j['isOptional'] == 1,
      );

  /// "3×8-10" style target label.
  String get repsLabel =>
      repMin == repMax ? '$repMin' : '$repMin-$repMax';
  String get setsRepsLabel => '$targetSets×$repsLabel';

  @override
  List<Object?> get props =>
      [id, exerciseId, section, targetSets, repMin, repMax, targetRir, isOptional];
}

class Exercise extends Equatable {
  final String id;
  final String name;
  final String nameRu;
  final String? cuesRu;
  final int minIncrementG;
  final String muscleGroup;
  final List<String> equipment;
  final String? videoQuery;
  final String? videoUrl;

  const Exercise({
    required this.id,
    required this.name,
    required this.nameRu,
    required this.cuesRu,
    required this.minIncrementG,
    this.muscleGroup = '',
    this.equipment = const [],
    this.videoQuery,
    this.videoUrl,
  });

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        id: j['id'].toString(),
        name: (j['name'] ?? '').toString(),
        nameRu: (j['nameRu'] ?? j['name'] ?? '').toString(),
        cuesRu: j['cuesRu']?.toString(),
        minIncrementG: (j['minIncrementG'] as num?)?.toInt() ?? 2500,
        muscleGroup: (j['muscleGroup'] ?? '').toString(),
        equipment: _parseEquipment(j['equipment']),
        videoQuery: j['videoQuery']?.toString(),
        videoUrl: j['videoUrl']?.toString(),
      );

  String get displayName => nameRu.isNotEmpty ? nameRu : name;

  /// Whether this is a dumbbell movement → the UI clarifies "per dumbbell".
  bool get isDumbbell => equipment.contains('db');

  /// Russian muscle-group label, or null if unknown/empty.
  String? get muscleLabel => _muscleRu[muscleGroup];

  /// Russian equipment labels for display chips.
  List<String> get equipmentLabels =>
      equipment.map((e) => _equipmentRu[e] ?? e).toList();

  /// Curated video link when present, else a YouTube search for the movement.
  String get videoUrlOrSearch {
    final url = videoUrl?.trim() ?? '';
    if (url.isNotEmpty) return url;
    final q = (videoQuery?.trim().isNotEmpty ?? false)
        ? videoQuery!.trim()
        : '$name техника выполнения';
    return 'https://www.youtube.com/results?search_query='
        '${Uri.encodeQueryComponent(q)}';
  }

  bool get hasCuratedVideo => (videoUrl?.trim().isNotEmpty ?? false);

  @override
  List<Object?> get props =>
      [id, name, nameRu, cuesRu, minIncrementG, muscleGroup, equipment, videoUrl];
}

List<String> _parseEquipment(dynamic raw) {
  if (raw is List) return raw.map((e) => e.toString()).toList();
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {}
  }
  return const [];
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

/// GET /api/v1/training/sessions — one row in the history list.
/// Also used to detect the ACTIVE session (endedAt == null).
class SessionSummary extends Equatable {
  final String id;
  final String routineId;
  final String routineName;
  final int sessionIndex;
  final String startedAt;
  final String? endedAt;
  final int? durationS;
  final int totalSets;
  final int totalVolumeG;
  final String volumeFormatted;

  const SessionSummary({
    required this.id,
    required this.routineId,
    required this.routineName,
    required this.sessionIndex,
    required this.startedAt,
    required this.endedAt,
    required this.durationS,
    required this.totalSets,
    required this.totalVolumeG,
    required this.volumeFormatted,
  });

  bool get isActive => endedAt == null;

  factory SessionSummary.fromJson(Map<String, dynamic> j) => SessionSummary(
        id: j['id'].toString(),
        routineId: j['routineId'].toString(),
        routineName: (j['routineName'] ?? '').toString(),
        sessionIndex: (j['sessionIndex'] as num?)?.toInt() ?? 0,
        startedAt: (j['startedAt'] ?? '').toString(),
        endedAt: j['endedAt']?.toString(),
        durationS: (j['durationS'] as num?)?.toInt(),
        totalSets: (j['totalSets'] as num?)?.toInt() ?? 0,
        totalVolumeG: (j['totalVolumeG'] as num?)?.toInt() ?? 0,
        volumeFormatted: (j['volumeFormatted'] ?? '').toString(),
      );

  @override
  List<Object?> get props => [
        id,
        routineId,
        routineName,
        sessionIndex,
        startedAt,
        endedAt,
        durationS,
        totalSets,
        totalVolumeG,
        volumeFormatted,
      ];
}

/// One set inside a session detail (GET /sessions/:id → sets[]).
class SessionSet extends Equatable {
  final String id;
  final String exerciseId;
  final String exerciseName;
  final int setNumber;
  final int weightG;
  final String weightFormatted;
  final int reps;
  final int? rir;
  final int? durationS;
  final bool isWarmup;

  const SessionSet({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.setNumber,
    required this.weightG,
    required this.weightFormatted,
    required this.reps,
    required this.rir,
    required this.durationS,
    required this.isWarmup,
  });

  factory SessionSet.fromJson(Map<String, dynamic> j) => SessionSet(
        id: j['id'].toString(),
        exerciseId: j['exerciseId'].toString(),
        exerciseName: (j['exerciseName'] ?? '').toString(),
        setNumber: (j['setNumber'] as num?)?.toInt() ?? 0,
        weightG: (j['weightG'] as num?)?.toInt() ?? 0,
        weightFormatted: (j['weightFormatted'] ?? '').toString(),
        reps: (j['reps'] as num?)?.toInt() ?? 0,
        rir: (j['rir'] as num?)?.toInt(),
        durationS: (j['durationS'] as num?)?.toInt(),
        isWarmup: j['isWarmup'] == true || j['isWarmup'] == 1,
      );

  @override
  List<Object?> get props => [
        id,
        exerciseId,
        exerciseName,
        setNumber,
        weightG,
        weightFormatted,
        reps,
        rir,
        durationS,
        isWarmup,
      ];
}

/// GET /api/v1/training/sessions/:id — full detail (summary + its sets).
class SessionDetail extends Equatable {
  final String id;
  final String routineName;
  final int sessionIndex;
  final String startedAt;
  final String? endedAt;
  final int? durationS;
  final String? durationFormatted;
  final int totalSets;
  final int totalVolumeG;
  final String volumeFormatted;
  final List<SessionSet> sets;

  const SessionDetail({
    required this.id,
    required this.routineName,
    required this.sessionIndex,
    required this.startedAt,
    required this.endedAt,
    required this.durationS,
    required this.durationFormatted,
    required this.totalSets,
    required this.totalVolumeG,
    required this.volumeFormatted,
    required this.sets,
  });

  bool get isActive => endedAt == null;

  factory SessionDetail.fromJson(Map<String, dynamic> j) {
    final s = (j['session'] as Map<String, dynamic>?) ?? const {};
    return SessionDetail(
      id: s['id'].toString(),
      routineName: (s['routineName'] ?? '').toString(),
      sessionIndex: (s['sessionIndex'] as num?)?.toInt() ?? 0,
      startedAt: (s['startedAt'] ?? '').toString(),
      endedAt: s['endedAt']?.toString(),
      durationS: (s['durationS'] as num?)?.toInt(),
      durationFormatted: s['durationFormatted']?.toString(),
      totalSets: (s['totalSets'] as num?)?.toInt() ?? 0,
      totalVolumeG: (s['totalVolumeG'] as num?)?.toInt() ?? 0,
      volumeFormatted: (s['volumeFormatted'] ?? '').toString(),
      sets: ((j['sets'] as List?) ?? const [])
          .map((e) => SessionSet.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        routineName,
        sessionIndex,
        startedAt,
        endedAt,
        durationS,
        durationFormatted,
        totalSets,
        totalVolumeG,
        volumeFormatted,
        sets,
      ];
}

/// A set already logged this session (for the "Готово" chips).
/// [id] is the server set_id, so the pill can be edited/deleted live.
class LoggedSet extends Equatable {
  final String id;
  final int weightG;
  final int reps;
  final int? rir;

  const LoggedSet({
    required this.id,
    required this.weightG,
    required this.reps,
    this.rir,
  });

  LoggedSet copyWith({int? weightG, int? reps, int? rir, bool clearRir = false}) =>
      LoggedSet(
        id: id,
        weightG: weightG ?? this.weightG,
        reps: reps ?? this.reps,
        rir: clearRir ? null : (rir ?? this.rir),
      );

  @override
  List<Object?> get props => [id, weightG, reps, rir];
}
