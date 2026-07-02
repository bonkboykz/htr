import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../data/today_models.dart';
import '../data/today_repository.dart';

enum TodayStatus { initial, loading, ready, error }

class TodayState extends Equatable {
  final TodayStatus status;
  final TodayData? data;
  final String? error;
  final bool unauthorized;

  const TodayState({
    this.status = TodayStatus.initial,
    this.data,
    this.error,
    this.unauthorized = false,
  });

  TodayState copyWith({
    TodayStatus? status,
    TodayData? data,
    String? error,
    bool? unauthorized,
  }) =>
      TodayState(
        status: status ?? this.status,
        data: data ?? this.data,
        error: error,
        unauthorized: unauthorized ?? this.unauthorized,
      );

  @override
  List<Object?> get props => [status, data, error, unauthorized];
}

class TodayCubit extends Cubit<TodayState> {
  final TodayRepository _repo;
  TodayCubit(this._repo) : super(const TodayState());

  static String _todayStr() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> load() async {
    emit(state.copyWith(status: TodayStatus.loading));
    try {
      final data = await _repo.load(_todayStr());
      emit(state.copyWith(status: TodayStatus.ready, data: data));
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: TodayStatus.error,
        error: e.message,
        unauthorized: e.isUnauthorized,
      ));
    } catch (e) {
      emit(state.copyWith(status: TodayStatus.error, error: e.toString()));
    }
  }
}
