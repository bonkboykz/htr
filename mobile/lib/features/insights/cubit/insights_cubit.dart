import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../data/insights_models.dart';
import '../data/insights_repository.dart';

enum InsightsStatus { initial, loading, ready, error }

/// Range control: Неделя / Месяц / 3 мес → 7 / 30 / 90 days back.
enum InsightsRange { week, month, quarter }

extension InsightsRangeX on InsightsRange {
  int get days {
    switch (this) {
      case InsightsRange.week:
        return 7;
      case InsightsRange.month:
        return 30;
      case InsightsRange.quarter:
        return 90;
    }
  }

  String get label {
    switch (this) {
      case InsightsRange.week:
        return 'Неделя';
      case InsightsRange.month:
        return 'Месяц';
      case InsightsRange.quarter:
        return '3 мес';
    }
  }
}

class InsightsState extends Equatable {
  final InsightsStatus status;
  final InsightsRange range;
  final List<Insight> insights;
  final String? error;
  final bool unauthorized;

  const InsightsState({
    this.status = InsightsStatus.initial,
    this.range = InsightsRange.month,
    this.insights = const [],
    this.error,
    this.unauthorized = false,
  });

  InsightsState copyWith({
    InsightsStatus? status,
    InsightsRange? range,
    List<Insight>? insights,
    String? error,
    bool? unauthorized,
  }) =>
      InsightsState(
        status: status ?? this.status,
        range: range ?? this.range,
        insights: insights ?? this.insights,
        error: error,
        unauthorized: unauthorized ?? this.unauthorized,
      );

  @override
  List<Object?> get props => [status, range, insights, error, unauthorized];
}

class InsightsCubit extends Cubit<InsightsState> {
  final InsightsRepository _repo;
  InsightsCubit(this._repo) : super(const InsightsState());

  static final _fmt = DateFormat('yyyy-MM-dd');

  Future<void> load() => _fetch(state.range);

  Future<void> setRange(InsightsRange range) {
    if (range == state.range && state.status == InsightsStatus.ready) {
      return Future.value();
    }
    return _fetch(range);
  }

  Future<void> _fetch(InsightsRange range) async {
    emit(state.copyWith(status: InsightsStatus.loading, range: range));
    final now = DateTime.now();
    final from = _fmt.format(now.subtract(Duration(days: range.days)));
    final to = _fmt.format(now);
    try {
      final insights = await _repo.load(from, to);
      emit(state.copyWith(status: InsightsStatus.ready, insights: insights));
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: InsightsStatus.error,
        error: e.message,
        unauthorized: e.isUnauthorized,
      ));
    } catch (e) {
      emit(state.copyWith(status: InsightsStatus.error, error: e.toString()));
    }
  }
}
