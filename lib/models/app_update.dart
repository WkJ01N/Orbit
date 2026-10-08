class AppRelease {
  const AppRelease({
    required this.version,
    required this.buildNumber,
    required this.notes,
    required this.assets,
    required this.releaseUrl,
  });
  final String version;
  final int buildNumber;
  final String notes;
  final String releaseUrl;
  final List<UpdateAsset> assets;
  bool newerThan(String version, int build) =>
      compareVersions(this.version, version) > 0 ||
      (compareVersions(this.version, version) == 0 && buildNumber > build);
  static int compareVersions(String a, String b) {
    List<int> parts(String s) => s
        .replaceFirst(RegExp(r'^v'), '')
        .split('+')
        .first
        .split('.')
        .map(int.parse)
        .toList();
    final aa = parts(a), bb = parts(b);
    for (var i = 0; i < 3; i++) {
      final c = aa[i].compareTo(bb[i]);
      if (c != 0) return c;
    }
    return 0;
  }

  factory AppRelease.fromGitHub(Map<String, dynamic> json) {
    if (json['draft'] == true || json['prerelease'] == true) {
      throw const FormatException('Not a stable release');
    }
    final tag = (json['tag_name'] as String? ?? '').replaceFirst(
      RegExp(r'^v'),
      '',
    );
    if (!RegExp(r'^\d+\.\d+\.\d+(\+\d+)?$').hasMatch(tag)) {
      throw const FormatException('Invalid stable version');
    }
    final manifest = json['orbitManifest'] as Map? ?? {};
    final manifestMatches = manifest['version'] == tag.split('+').first;
    return AppRelease(
      version: tag.split('+').first,
      buildNumber: manifestMatches
          ? (manifest['buildNumber'] as num? ?? 0).toInt()
          : (int.tryParse(tag.split('+').last) ?? 0),
      notes: json['body'] as String? ?? '',
      releaseUrl:
          'https://github.com/WkJ01N/Orbit/releases/tag/v${tag.split('+').first}',
      assets: [
        for (final item in json['assets'] as List? ?? [])
          if (_platform(item['name'] as String? ?? '') != null)
            UpdateAsset.fromGitHub(
              Map<String, dynamic>.from(item),
              manifestMatches
                  ? (manifest['assets'] as Map? ?? {})[_platform(item['name'])]
                        as Map?
                  : null,
            ),
      ],
    );
  }
  static String? _platform(String name) => name.endsWith('.apk')
      ? 'android'
      : name.toLowerCase().contains('windows') && name.endsWith('.zip')
      ? 'windows'
      : null;
}

class UpdateAsset {
  const UpdateAsset({
    required this.platform,
    required this.name,
    required this.url,
    required this.size,
    this.sha256,
  });
  final String platform, name, url;
  final int size;
  final String? sha256;
  bool get verifiable =>
      size > 0 && sha256 != null && RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256!);
  factory UpdateAsset.fromGitHub(Map<String, dynamic> json, Map? manifest) {
    final name = json['name'] as String;
    final url = json['browser_download_url'] as String;
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        !uri.path.startsWith('/WkJ01N/Orbit/releases/download/') ||
        uri.userInfo.isNotEmpty ||
        !RegExp(r'^[\w.+-]+$').hasMatch(name)) {
      throw const FormatException('Untrusted official asset');
    }
    final size = (json['size'] as num? ?? 0).toInt();
    final digest = json['digest'] as String?;
    final hash = digest?.startsWith('sha256:') == true
        ? digest!.substring(7).toLowerCase()
        : manifest?['name'] == name && manifest?['size'] == size
        ? (manifest?['sha256'] as String?)?.toLowerCase()
        : null;
    return UpdateAsset(
      platform: name.endsWith('.apk') ? 'android' : 'windows',
      name: name,
      url: url,
      size: size,
      sha256: hash,
    );
  }
}

class DownloadSource {
  const DownloadSource(this.name, this.prefix);
  final String name, prefix;
  static const builtIn = [
    DownloadSource('GitHub', ''),
    DownloadSource('GHFast', 'https://ghfast.top/'),
    DownloadSource('GH-Proxy', 'https://gh-proxy.com/'),
    DownloadSource('ghproxy.net', 'https://ghproxy.net/'),
  ];
  static bool validPrefix(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        uri.fragment.isEmpty &&
        uri.query.isEmpty;
  }

  Uri assetUri(UpdateAsset asset) => Uri.parse(
    prefix.isEmpty
        ? asset.url
        : '${prefix.endsWith('/') ? prefix : '$prefix/'}${asset.url}',
  );
}

class SourceLatency {
  const SourceLatency({
    required this.source,
    required this.testedAt,
    this.milliseconds,
    this.error,
  });
  final DownloadSource source;
  final DateTime testedAt;
  final int? milliseconds;
  final String? error;
}
