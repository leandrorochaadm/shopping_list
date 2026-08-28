import '../../../domain/models/device_user.dart';
import 'device_user_repository.dart';

/// In-memory fake: debug without --dart-define, and every test.
///
/// It forgets everything when the tab is reloaded, which is the honest
/// behaviour for a fake — nothing typed on the fakes is supposed to survive,
/// and the screen carries the DADOS FAKE banner to say so.
/// Not `final`: the ViewModel tests extend it with a spy that fails the next
/// call, which is how both error paths get exercised without mocktail.
class DeviceUserRepositoryLocal implements DeviceUserRepository {
  DeviceUserRepositoryLocal({
    DeviceUser? initial,
    this.latency = const Duration(milliseconds: 400),
  }) : _user = initial;

  /// Roughly what the real thing costs, so the loading state is exercised
  /// while developing instead of being discovered on the phone. Tests pass
  /// [Duration.zero].
  final Duration latency;

  DeviceUser? _user;

  @override
  Future<DeviceUser?> read() async {
    await Future<void>.delayed(latency);
    return _user;
  }

  @override
  DeviceUser? readNow() => _user;

  @override
  Future<void> save(DeviceUser user) async {
    await Future<void>.delayed(latency);
    _user = user;
  }
}
