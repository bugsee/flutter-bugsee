import 'package:package_info_plus/package_info_plus.dart';

const String BUGSEE_VERSION = '2.1.2';

String _applicationVersion = '';

void setApplicationVersionInternal(String version) {
  _applicationVersion = version;
}

String getApplicationVersionInternal() {
  return _applicationVersion;
}

/// Automatically detects application version and uses it if version
/// was not previously set
Future<void> autoFillVersionInternal() async {
  if (_applicationVersion != '') {
    return;
  }

  try {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    _applicationVersion = packageInfo.version;
  } catch (ex) {
    // Ignore exception here
  }
}
