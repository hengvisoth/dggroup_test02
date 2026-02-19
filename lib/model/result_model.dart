class IpResult {
  final String ipv4;
  final String ipv6;
  final String connection; // wifi | mobile | none | any
  final bool ok;
  final String message;

  const IpResult({required this.ipv4, required this.ipv6, required this.connection, required this.ok, required this.message});

  factory IpResult.fromMap(Map<dynamic, dynamic> map) {
    final ok = (map['ok'] as bool?) ?? false;
    return IpResult(
      ipv4: (map['ipv4'] as String?) ?? '',
      ipv6: (map['ipv6'] as String?) ?? '',
      connection: (map['connection'] as String?) ?? 'none',
      ok: ok,
      message: (map['message'] as String?) ?? (ok ? 'OK' : 'No internet connection'),
    );
  }
}
