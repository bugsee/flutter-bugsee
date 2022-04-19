import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:bugsee_flutter/src/types_internal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:io';
import './callbacks.dart';

class BugseeViewManager {
  final MethodChannel _channel;

  BugseeViewManager(MethodChannel channel) : _channel = channel;

  bool _isCollecting = false;
  bool _boundsWasFilled = false;
  bool _areViewsTracked = false;
  double _devicePixelRatio = 1.0;
  int lastUpdateTimestamp = 0;
  // Stopwatch _stopwatch = Stopwatch();

  List<double> _rectToList(Rect? bounds) {
    if (bounds != null) {
      return [bounds.left, bounds.top, bounds.width, bounds.height];
    }

    return [0, 0, 0, 0];
  }

  void _updateDevicePixelRatio() {
    if (WidgetsBinding.instance != null) {
      if (Platform.isAndroid) {
        this._devicePixelRatio =
            WidgetsBinding.instance!.window.devicePixelRatio;
      } else if (Platform.isIOS) {
        this._devicePixelRatio = 1;
      }
    }
  }

  bool _addElementBounds(Element element, List<int> boundsData) {
    Size? widgetSize = element.size;
    if (widgetSize != null) {
      if (widgetSize.width <= 0 || widgetSize.height <= 0) {
        // if widget dimensions are less or equal zero,
        // then there is no need to check it further.
        return true;
      }

      RenderBox? renderBox = element.renderObject as RenderBox?;
      if (renderBox != null) {
        Offset widgetOffset = renderBox.localToGlobal(Offset.zero);
        var x = (widgetOffset.dx * _devicePixelRatio).round();
        var y = (widgetOffset.dy * _devicePixelRatio).round();
        var width = (widgetSize.width * _devicePixelRatio).round();
        var height = (widgetSize.height * _devicePixelRatio).round();

        if (x + width < 0 || y + height < 0) {
          // element is outside the viewport, skip it
          return true;
        }

        boundsData.add(element.hashCode);
        boundsData.add(x);
        boundsData.add(y);
        boundsData.add(width);
        boundsData.add(height);

        return true;
      }
    }

    return false;
  }

  bool _checkIfElementSecure(Element element, List<int> boundsData) {
    // we use an optimization here: once we hit the BugseeSecureView widget
    // which is in an enabled state, we stop further (deeper) traversal.
    // There is no need to go deeper, as parent element will be already
    // obscured in video.
    if (element.widget is BugseeSecureView) {
      BugseeSecureView bugseeElement = element.widget as BugseeSecureView;
      if (bugseeElement.enabled) {
        return _addElementBounds(element, boundsData);
      }
    } else if (element.widget is BugseeIgnoreSecureView) {
      BugseeIgnoreSecureView bugseeElement =
          element.widget as BugseeIgnoreSecureView;
      return bugseeElement.enabled;
    } else if (element.widget is TextField) {
      TextField tfElement = element.widget as TextField;
      if (tfElement.obscureText) {
        return _addElementBounds(element, boundsData);
      }
    }

    return false;
  }

  void _visitChildElements(Element parentElement, List<int> boundsData) {
    if (!_checkIfElementSecure(parentElement, boundsData)) {
      parentElement.visitChildren((element) {
        if (!_checkIfElementSecure(element, boundsData)) {
          _visitChildElements(element, boundsData);
        }
      });
    }
  }

  void collectAndSendSecureRectangles() {
    if (_isCollecting) return;

    _isCollecting = true;
    // _stopwatch.reset();
    // _stopwatch.start();

    this._updateDevicePixelRatio();

    if (WidgetsBinding.instance != null) {
      List<int> boundsData = [];

      // start widgets tree traversal
      WidgetsBinding.instance?.renderViewElement
          ?.visitChildren((Element element) {
        _visitChildElements(element, boundsData);
      });

      _sendBoundsData(boundsData);
    }

    // print("View tracking complete. It took: ${_stopwatch.elapsedMilliseconds}");
    // _stopwatch.stop();
    _isCollecting = false;
  }

  void _sendBoundsData(List<int> boundsData) {
    if (boundsData.length > 0) {
      _boundsWasFilled = true;
      _channel.invokeMethod(
          "setSecureRectsInternal", {'bounds': Int32List.fromList(boundsData)});
    } else if (_boundsWasFilled) {
      // we need to send empty data to instruct underlying SDK
      // to clear the internal rectangles list
      _boundsWasFilled = false;
      _channel.invokeMethod("setSecureRectsInternal", {'bounds': null});
    }
  }

  void onFrame(timeStamp) {
    if (_areViewsTracked) {
      // we can also check secure views here
      // collectAndSendSecureRectangles();
    }
  }

  void _onExtraFrameUpdate(Timer timer) {
    if (lastUpdateTimestamp != 0) {
      int elapsed = DateTime.now().millisecondsSinceEpoch - lastUpdateTimestamp;
      if (elapsed > 500 && elapsed < 1500) {
        collectAndSendSecureRectangles();
      }
    }
  }

  void onAfterFrame(Duration timeStamp) {
    lastUpdateTimestamp = DateTime.now().millisecondsSinceEpoch;

    collectAndSendSecureRectangles();

    WidgetsBinding.instance?.addPostFrameCallback(onAfterFrame);
  }

  void _createOptionsForElement(Element element, ViewHierarchyItem item) {
    // Fill element options here
    item.options = {
      "hashCode": element.hashCode.toString(),
      "element": element.runtimeType.toString(),
      "dirty": element.dirty,
      "debugIsDefunct": element.debugIsDefunct,
      "key": element.widget.key?.toString() ?? ""
    };

    RenderObject? ro = element.renderObject;
    if (ro != null) {
      item.options!['semantic_bounds'] = _rectToList(ro.semanticBounds);
      item.options!['paint_bounds'] = _rectToList(ro.paintBounds);
      item.options!['need_compositing'] = ro.needsCompositing;
      item.options!['is_repaint_boundary'] = ro.isRepaintBoundary;
      item.options!['attached'] = ro.attached;
    }

    // try the following for more options:
    // element.describeElement(name).toJsonMap(delegate)
  }

  ViewHierarchyItem? _createViewHierarchyItemFromElement(Element? element) {
    if (element == null) {
      return null;
    }

    Rectangle? bounds;
    try {
      RenderBox? renderBox = element.renderObject as RenderBox?;
      if (renderBox != null) {
        Size elementSize = renderBox.size;
        Offset elementOffset = renderBox.localToGlobal(Offset.zero);
        var x = (elementOffset.dx * _devicePixelRatio).round();
        var y = (elementOffset.dy * _devicePixelRatio).round();
        var width = (elementSize.width * _devicePixelRatio).round();
        var height = (elementSize.height * _devicePixelRatio).round();
        bounds = Rectangle(x, y, width, height);
      }
    } catch (e) {
      // TODO: check whether it's safe to ignore the failure here
    }

    if (bounds == null) {
      bounds = Rectangle(0, 0, 0, 0);
    }

    var className = element.widget.runtimeType.toString();

    ViewHierarchyItem item =
        ViewHierarchyItem(element.hashCode.toString(), bounds, className);

    _createOptionsForElement(element, item);

    element.visitChildren((element) {
      if (item.subitems == null) {
        item.subitems = [];
      }

      var subitem = _createViewHierarchyItemFromElement(element);
      if (subitem != null) {
        item.subitems!.add(subitem);
      }
    });

    return item;
  }

  String? dumpViewHierarchy() {
    this._updateDevicePixelRatio();

    ViewHierarchyItem? rootItem = _createViewHierarchyItemFromElement(
        WidgetsBinding.instance?.renderViewElement);

    if (rootItem != null) {
      try {
        return jsonEncode(rootItem.toMap());
      } catch (e) {
        // Failed to convert to JSON
      }
    }

    return null;
  }

  void startViewTracking() {
    if (!_areViewsTracked) {
      this._areViewsTracked = true;
      //_onFrameUpdated(DateTime.now());
    }
  }

  void stopViewTracking() {
    this._areViewsTracked = false;
  }

  void initialize(BugseeCallbacks callbacks) {
    WidgetsBinding.instance?.addPersistentFrameCallback(onFrame);
    onAfterFrame(Duration(seconds: 0));
    Timer.periodic(new Duration(milliseconds: 500), _onExtraFrameUpdate);
  }
}

class BugseeSecureView extends MetaData {
  const BugseeSecureView({Key? key, Widget? child, bool? enabled})
      : this.enabled = enabled ?? true,
        super(key: key, child: child);

  final bool enabled;
}

class BugseeIgnoreSecureView extends MetaData {
  const BugseeIgnoreSecureView({Key? key, Widget? child, bool? enabled})
      : this.enabled = enabled ?? true,
        super(key: key, child: child);

  final bool enabled;
}
