/// Una versione pubblicata dell'app, come la descrive version.json sul sito
/// (generato dal workflow di release a partire dalla GitHub Release vera).
///
/// ```json
/// {"version": "0.2.0", "apk": {"url": "https://...", "size": 122746467, "sha256": "fb3f..."}}
/// ```
class AppRelease {
  final String version;
  final Uri apkUrl;
  final int apkSize;
  final String sha256; // esadecimale minuscolo

  const AppRelease({required this.version, required this.apkUrl, required this.apkSize, required this.sha256});

  /// Lancia [FormatException] se manca qualcosa: meglio non proporre un
  /// aggiornamento che non si potrebbe verificare.
  factory AppRelease.fromJson(Map<String, dynamic> json) {
    final apk = json['apk'];
    final version = json['version'];
    if (version is! String || parseVersion(version) == null || apk is! Map) {
      throw const FormatException('version.json senza versione o APK');
    }
    final url = Uri.tryParse('${apk['url']}');
    final size = apk['size'];
    final sha = '${apk['sha256']}'.toLowerCase().replaceFirst('sha256:', '');
    if (url == null || url.scheme != 'https' || size is! int || !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) {
      throw const FormatException('version.json con APK non valido');
    }
    return AppRelease(version: version, apkUrl: url, apkSize: size, sha256: sha);
  }
}

/// "v1.2.3+4" -> [1, 2, 3]; null se non è una versione. Il numero di build
/// dopo "+" non conta: le release si distinguono per la versione.
List<int>? parseVersion(String v) {
  final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:\+\d+)?$').firstMatch(v.trim());
  return m == null ? null : [for (var i = 1; i <= 3; i++) int.parse(m[i]!)];
}

/// <0 se [a] è più vecchia di [b], 0 se uguali, >0 se più nuova.
/// Una versione illeggibile vale come la più vecchia.
int compareVersions(String a, String b) {
  final pa = parseVersion(a), pb = parseVersion(b);
  if (pa == null || pb == null) return (pa == null ? 0 : 1) - (pb == null ? 0 : 1);
  for (var i = 0; i < 3; i++) {
    if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
  }
  return 0;
}
