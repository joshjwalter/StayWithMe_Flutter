import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/connectivity_status.dart';

part 'connectivity_notifier.g.dart';

@riverpod
class ConnectivityNotifier extends _$ConnectivityNotifier {
  @override
  ConnectivityStatus build() {
    return ConnectivityStatus.checking();
  }

  void updateFromCheck(bool isConnected) {
    state = isConnected
        ? ConnectivityStatus.connected()
        : ConnectivityStatus.disconnected();
  }

  void setChecking() {
    state = ConnectivityStatus.checking();
  }
}
