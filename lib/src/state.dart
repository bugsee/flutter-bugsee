import 'options.dart';

BugseeLaunchOptions? _lastLaunchOptions;

void setLaunchOptions(BugseeLaunchOptions? launchOptions) {
  _lastLaunchOptions = launchOptions;
}

BugseeLaunchOptions? getLaunchOptions() {
  return _lastLaunchOptions;
}
