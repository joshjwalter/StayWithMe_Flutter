import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stay_with_me_flutter/domain/entities/connectivity_status.dart';
import 'package:stay_with_me_flutter/presentation/providers/connectivity_notifier.dart';

void main() {
  group('ConnectivityNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is checking', () {
      final state = container.read(connectivityNotifierProvider);

      expect(state.isChecking, true);
      expect(state.isConnected, false);
    });

    test('updateFromCheck with true sets connected', () {
      container
          .read(connectivityNotifierProvider.notifier)
          .updateFromCheck(true);

      final state = container.read(connectivityNotifierProvider);
      expect(state.isConnected, true);
      expect(state.isChecking, false);
    });

    test('updateFromCheck with false sets disconnected', () {
      container
          .read(connectivityNotifierProvider.notifier)
          .updateFromCheck(true);
      container
          .read(connectivityNotifierProvider.notifier)
          .updateFromCheck(false);

      final state = container.read(connectivityNotifierProvider);
      expect(state.isConnected, false);
      expect(state.isChecking, false);
    });

    test('setChecking returns to checking state', () {
      container
          .read(connectivityNotifierProvider.notifier)
          .updateFromCheck(true);
      container.read(connectivityNotifierProvider.notifier).setChecking();

      final state = container.read(connectivityNotifierProvider);
      expect(state.isChecking, true);
      expect(state.isConnected, false);
    });
  });
}
