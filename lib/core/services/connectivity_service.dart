import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits `true` while the device has some network connection.
///
/// Firestore has offline persistence enabled (see `main.dart`), so the app is
/// fully usable without connectivity: reads come from the local cache and
/// writes are queued and replayed when the network returns.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  final initial = await connectivity.checkConnectivity();
  yield _hasNetwork(initial);
  yield* connectivity.onConnectivityChanged.map(_hasNetwork);
});

bool _hasNetwork(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);
