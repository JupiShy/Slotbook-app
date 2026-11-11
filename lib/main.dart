import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:livecoding/api/slotbook_api.dart';
import 'package:livecoding/data/slotbook_repository.dart';
import 'package:livecoding/firebase_options.dart';
import 'package:livecoding/services/app_crash_monitor.dart';
import 'package:livecoding/services/booking_storage_service.dart';
import 'package:livecoding/services/error_logger_service.dart';
import 'package:livecoding/state/booking_cubit.dart';
import 'package:livecoding/ui/router/app_router.dart';
import 'package:livecoding/ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppCrashMonitor? crashMonitor;
  final isMobileFirebaseSupported = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (isMobileFirebaseSupported) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    crashMonitor = AppCrashMonitor.instance;
    _attachGlobalCrashHandlers(crashMonitor);
    crashMonitor.log('Firebase & AppCrashMonitor initialized');
  } else {
    debugPrint('Firebase Crashlytics disabled on $defaultTargetPlatform');
  }

  runApp(SlotBookApp(crashMonitor: crashMonitor));
}

void _attachGlobalCrashHandlers(AppCrashMonitor crashMonitor) {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    crashMonitor.log('Flutter fatal error: ${details.exceptionAsString()}');
    unawaited(
      crashMonitor.recordError(
        details.exception,
        details.stack ?? StackTrace.current,
        reason: 'FlutterError.onError',
        fatal: true,
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    crashMonitor.log('Uncaught platform error: $error');
    unawaited(
      crashMonitor.recordError(
        error,
        stack,
        reason: 'PlatformDispatcher.onError',
        fatal: true,
      ),
    );
    return true;
  };
}

class SlotBookApp extends StatefulWidget {
  const SlotBookApp({
    super.key,
    this.cubit,
    this.crashMonitor,
  });

  final BookingCubit? cubit;
  final AppCrashMonitor? crashMonitor;

  @override
  State<SlotBookApp> createState() => _SlotBookAppState();
}

class _SlotBookAppState extends State<SlotBookApp> {
  late final BookingCubit _cubit =
      widget.cubit ?? _createDefaultCubit(widget.crashMonitor);
  late final bool _ownsCubit = widget.cubit == null;
  late final GoRouter _router = createAppRouter();
  String? _lastTrackedScreen;

  @override
  void initState() {
    super.initState();
    _router.routeInformationProvider.addListener(_onRouteChanged);
    _onRouteChanged();
  }

  void _onRouteChanged() {
    final location = _router.routeInformationProvider.value.uri.path;
    if (location.isEmpty || location == _lastTrackedScreen) return;
    _lastTrackedScreen = location;
    _cubit.setCurrentScreen(location);
  }

  static BookingCubit _createDefaultCubit(AppCrashMonitor? crashMonitor) {
    const initialScenario = ApiScenario.incident;
    final storage = InMemoryBookingStorageService();
    final logger = AppErrorLoggerService(
      onLog: debugPrint,
      crashMonitor: crashMonitor,
    );
    final cubit = BookingCubit(
      repository: ApiSlotBookRepository(
        SlotBookApi(scenario: initialScenario),
        storage: storage,
        errorLogger: logger,
      ),
      repositoryFactory: (scenario) => ApiSlotBookRepository(
        SlotBookApi(scenario: scenario),
        storage: storage,
        errorLogger: logger,
      ),
      errorLogger: logger,
      initialScenario: initialScenario,
    );
    unawaited(cubit.loadSpecialists());
    return cubit;
  }

  @override
  void dispose() {
    _router.routeInformationProvider.removeListener(_onRouteChanged);
    _router.dispose();
    if (_ownsCubit) {
      unawaited(_cubit.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BookingCubit>.value(
      value: _cubit,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'SlotBook',
        theme: AppTheme.light(),
        routerConfig: _router,
      ),
    );
  }
}
