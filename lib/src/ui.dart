import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class BugseeViewManager {
  final MethodChannel _channel;

  BugseeViewManager(MethodChannel channel) : _channel = channel;

  bool _areViewsTracked = false;
  double _devicePixelRatio = 1.0;
  // Stopwatch _stopwatch = Stopwatch();

  bool _checkElement(Element element, List<double> boundsData) {
    // we use an optimization here: once we hit the BugseeSecureView widget
    // which is in an enabled state, we stop further (deeper) traversal.
    // There is no need to go deeper, as parent element will be already
    // obscured in video.
    if (element.widget is BugseeSecureView) {
      BugseeSecureView bugseeElement = element.widget as BugseeSecureView;
      if (bugseeElement.enabled) {
        RenderBox? renderBox = element.renderObject as RenderBox?;
        if (renderBox != null) {
          Offset widgetOffset = renderBox.localToGlobal(Offset.zero);
          Size? widgetSize = element.size;
          if (widgetSize != null) {
            var x = widgetOffset.dx * _devicePixelRatio;
            var y = widgetOffset.dy * _devicePixelRatio;
            var width = widgetSize.width * _devicePixelRatio;
            var height = widgetSize.height * _devicePixelRatio;

            boundsData.add(x);
            boundsData.add(y);
            boundsData.add(width);
            boundsData.add(height);

            return true;
          }
        }
      }
    }

    return false;
  }

  void _visitChildElements(Element parentElement, List<double> boundsData) {
    if (!_checkElement(parentElement, boundsData)) {
      parentElement.visitChildren((element) {
        if (!_checkElement(element, boundsData)) {
          _visitChildElements(element, boundsData);
        }
      });
    }
  }

  void _onFrameUpdated(timeStamp) {
    // _stopwatch.reset();
    // _stopwatch.start();

    if (WidgetsBinding.instance != null) {
      this._devicePixelRatio = WidgetsBinding.instance!.window.devicePixelRatio;

      List<double> boundsData = [];

      // start widgets tree traversal
      WidgetsBinding.instance?.renderViewElement?.visitChildren((element) {
        _visitChildElements(element, boundsData);
      });

      _channel.invokeMethod("setSecureRectsInternal", {'bounds': boundsData});

      if (this._areViewsTracked) {
        // schedule next run
        WidgetsBinding.instance!.addPostFrameCallback(_onFrameUpdated);
      }
    }

    // print("View tracking complete. It took: ${_stopwatch.elapsedMilliseconds}");
    // _stopwatch.stop();
  }

  void startViewTracking() {
    if (!_areViewsTracked) {
      this._areViewsTracked = true;
      // TODO: enable this once we have stable implementation
      // _onFrameUpdated(DateTime.now());
    }
  }

  void stopViewTracking() {
    this._areViewsTracked = false;
  }
}

class BugseeSecureView extends MetaData {
  const BugseeSecureView({Key? key, Widget? child, bool? enabled})
      : this.enabled = enabled ?? true,
        super(key: key, child: child);

  final bool enabled;
}
