# HTR mobile — architecture (follow this exactly)

Aligned with the team's `qmeta` app: **flutter_bloc/Cubit + get_it**, dio, go_router,
manual `fromJson`, feature-first. Material 3, light theme.

## Structure
```
lib/
  app/        app.dart · router.dart · theme.dart
  core/
    env/env.dart              # Env.apiBaseUrl (compile-time --dart-define)
    storage/token_storage.dart # secure storage: apiKey, baseUrl override
    network/api_client.dart   # ApiClient(dio) + ApiException; Bearer via interceptor
    di/di.dart                # get_it `sl`; registers TokenStorage + ApiClient
    widgets/                  # shared widgets (placeholder.dart, add reusable ones)
  features/<feature>/
    data/<feature>_models.dart      # plain Dart models + fromJson
    data/<feature>_repository.dart   # takes ApiClient, returns models
    cubit/<feature>_cubit.dart       # Cubit + State (status enum + copyWith, Equatable)
    presentation/<feature>_page.dart # BlocProvider + BlocBuilder
    presentation/widgets/            # screen-local widgets
```

## Canonical pattern (copy this shape per screen)

**Repository** — construct from `sl<ApiClient>()`; parse JSON here:
```dart
class TodayRepository {
  final ApiClient _api;
  TodayRepository(this._api);
  Future<TodayData> load(String date) async {
    final json = await _api.get('/api/v1/daily/$date');
    return TodayData.fromJson(json as Map<String, dynamic>);
  }
}
```

**Cubit + State** — status enum, immutable state, `copyWith`, Equatable:
```dart
enum Status { initial, loading, ready, error }

class TodayState extends Equatable {
  final Status status;
  final TodayData? data;
  final String? error;
  final bool unauthorized;
  const TodayState({this.status = Status.initial, this.data, this.error, this.unauthorized = false});
  TodayState copyWith({...}) => ...;
  @override List<Object?> get props => [status, data, error, unauthorized];
}

class TodayCubit extends Cubit<TodayState> {
  final TodayRepository _repo;
  TodayCubit(this._repo) : super(const TodayState());
  Future<void> load() async {
    emit(state.copyWith(status: Status.loading));
    try {
      final data = await _repo.load(_todayStr());
      emit(state.copyWith(status: Status.ready, data: data));
    } on ApiException catch (e) {
      emit(state.copyWith(status: Status.error, error: e.message, unauthorized: e.isUnauthorized));
    } catch (e) {
      emit(state.copyWith(status: Status.error, error: e.toString()));
    }
  }
}
```

**Page** — provide the cubit, build from state:
```dart
class TodayPage extends StatelessWidget {          // KEEP this class name (router imports it)
  const TodayPage({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => TodayCubit(TodayRepository(sl<ApiClient>()))..load(),
    child: const _TodayView(),
  );
}

class _TodayView extends StatelessWidget {
  const _TodayView();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<TodayCubit, TodayState>(
        builder: (context, state) {
          switch (state.status) {
            case Status.loading:
            case Status.initial:
              return const Center(child: CircularProgressIndicator());
            case Status.error:
              return _ErrorView(state: state, onRetry: () => context.read<TodayCubit>().load());
            case Status.ready:
              return _Content(data: state.data!);
          }
        },
      ),
    );
  }
}
```

## Rules
- **Keep page class names** exactly as the router imports (`TodayPage`, `WorkoutPage`, …).
- Colors/radii ONLY from `app/theme.dart` (`AppColors`, `AppRadii`). Red (`AppColors.danger`) is reserved for the реаб block / negative correlations / disclaimers.
- Network via `sl<ApiClient>()`. Never read the API key directly — the interceptor adds it.
- Error UX: on `unauthorized` (401), show "Нужен API-ключ" + a button → `context.push('/settings')`; otherwise message + Retry.
- Weights are integer **grams**; display the API's `*Formatted` fields ("52.5 kg"); step by `minIncrementG` grams.
- Dates: `DateFormat('yyyy-MM-dd').format(DateTime.now())` (package:intl).
- Do NOT edit `core/di/di.dart` from a feature. Do NOT `flutter pub add`. Only touch your `features/<feature>/` folder.
- Design references live in `../design-exports/NN-*.png`.
- **Icons: use `package:lucide_icons/lucide_icons.dart` (`LucideIcons.*`)** — the design uses the Lucide set. Do NOT use Material `Icons.*`. Common: `droplet`, `moon`, `scale`, `dumbbell`, `sparkles`, `utensils`, `trendingUp`, `calendarDays`, `clipboardList`, `arrowRight`, `chevronRight`, `settings`, `timer`, `listChecks`, `plus`, `minus`, `check`.
- **Runtime gotcha:** `flutter analyze` does NOT catch layout errors. A `Row`/`Column` with `crossAxisAlignment: stretch` inside a scrollable needs an `IntrinsicHeight` wrapper, and `Row`s with flexible children need `Expanded`. Sanity-check on device.
```
