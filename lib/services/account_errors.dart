class AccountSyncException implements Exception {
  const AccountSyncException(this.code, [this.detail]);

  final String code;
  final String? detail;

  /// True when the rejection targets the entity itself, so resending the same
  /// mutation can never succeed and the queue must move past it.
  bool get quarantinesEntity => const {
    'sync_item_too_large',
    'entity_too_large',
    'payload_too_large',
    'invalid_entity',
  }.contains(code);

  @override
  String toString() => detail == null ? code : '$code: $detail';
}
