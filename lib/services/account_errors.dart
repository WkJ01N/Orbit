class AccountSyncException implements Exception {
  const AccountSyncException(this.code, [this.detail]);

  final String code;
  final String? detail;

  @override
  String toString() => detail == null ? code : '$code: $detail';
}
