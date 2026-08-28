/// Who is using THIS phone — the label of `handoff §10`, and nothing more.
///
/// It is not an account and not a login: there is no password, no sign-up and
/// no server-side identity anywhere in this app (decision 6). The label lives
/// in Hive, on the device, and its only trip to the database is as the
/// `registered_by` text copied onto a purchase — which is why changing it is
/// one tap with no confirmation, and why it only affects purchases registered
/// from here onwards.
final class DeviceUser {
  /// Throws [EmptyDeviceUserName] when there is nothing left after trimming:
  /// a label made of blanks would show up as an empty column on the purchase
  /// history months later, with nobody able to say whose it was.
  factory DeviceUser(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const EmptyDeviceUserName();
    return DeviceUser._(trimmed);
  }

  const DeviceUser._(this.name);

  factory DeviceUser.fromJson(Map<String, dynamic> json) =>
      DeviceUser(json['name'] as String);

  /// The two people this app was built for (`handoff §H1`: "Quem está usando?
  /// ( ) Leandro ( ) esposa"). They are suggestions on the screen, not a
  /// closed set: [DeviceUser] accepts any non-blank name, so a third phone or
  /// a different household needs no change here.
  static const suggestedNames = ['Leandro', 'Esposa'];

  /// Already trimmed, never blank.
  final String name;

  Map<String, dynamic> toJson() => {'name': name};

  DeviceUser copyWith({String? name}) => DeviceUser(name ?? this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is DeviceUser && other.name == name);

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'DeviceUser($name)';
}

/// A rule of the domain saying no — not a technical failure. The sentence is
/// pt-BR because it is shown to the person who typed the name.
final class EmptyDeviceUserName implements Exception {
  const EmptyDeviceUserName();

  String get message => 'Escolha quem está usando este aparelho.';

  @override
  String toString() => 'EmptyDeviceUserName: $message';
}
