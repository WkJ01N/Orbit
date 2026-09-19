enum SyncNetworkPolicy { any, unmetered }

enum SyncTrigger { manual, startup, appResume, localChange, networkRestored }

class AutoSyncSettings {
  const AutoSyncSettings({
    this.enabled = true,
    this.onStartup = true,
    this.onAppResume = true,
    this.onLocalChange = true,
    this.onNetworkRestored = true,
    this.networkPolicy = SyncNetworkPolicy.any,
  });

  final bool enabled;
  final bool onStartup;
  final bool onAppResume;
  final bool onLocalChange;
  final bool onNetworkRestored;
  final SyncNetworkPolicy networkPolicy;

  bool allows(SyncTrigger trigger) {
    if (trigger == SyncTrigger.manual) return true;
    if (!enabled) return false;
    return switch (trigger) {
      SyncTrigger.startup => onStartup,
      SyncTrigger.appResume => onAppResume,
      SyncTrigger.localChange => onLocalChange,
      SyncTrigger.networkRestored => onNetworkRestored,
      SyncTrigger.manual => true,
    };
  }

  AutoSyncSettings copyWith({
    bool? enabled,
    bool? onStartup,
    bool? onAppResume,
    bool? onLocalChange,
    bool? onNetworkRestored,
    SyncNetworkPolicy? networkPolicy,
  }) => AutoSyncSettings(
    enabled: enabled ?? this.enabled,
    onStartup: onStartup ?? this.onStartup,
    onAppResume: onAppResume ?? this.onAppResume,
    onLocalChange: onLocalChange ?? this.onLocalChange,
    onNetworkRestored: onNetworkRestored ?? this.onNetworkRestored,
    networkPolicy: networkPolicy ?? this.networkPolicy,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'onStartup': onStartup,
    'onAppResume': onAppResume,
    'onLocalChange': onLocalChange,
    'onNetworkRestored': onNetworkRestored,
    'networkPolicy': networkPolicy.name,
  };

  factory AutoSyncSettings.fromJson(Map<String, dynamic> json) =>
      AutoSyncSettings(
        enabled: json['enabled'] as bool? ?? true,
        onStartup: json['onStartup'] as bool? ?? true,
        onAppResume: json['onAppResume'] as bool? ?? true,
        onLocalChange: json['onLocalChange'] as bool? ?? true,
        onNetworkRestored: json['onNetworkRestored'] as bool? ?? true,
        networkPolicy: SyncNetworkPolicy.values.firstWhere(
          (value) => value.name == json['networkPolicy'],
          orElse: () => SyncNetworkPolicy.any,
        ),
      );
}
