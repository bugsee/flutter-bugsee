package com.bugsee;

import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.content.res.Configuration;
import android.graphics.Color;
import android.graphics.Rect;
import android.hardware.SensorManager;
import android.os.Process;
import android.os.Handler;
import android.os.Looper;
import android.view.OrientationEventListener;
import android.view.Surface;
import android.view.WindowManager;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.UiThread;

import java.lang.ref.WeakReference;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.Math;
import java.util.Arrays;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.PluginRegistry.Registrar;

import com.bugsee.library.Bugsee;
import com.bugsee.library.BugseeInternalAdapter;
import com.bugsee.library.attachment.CustomAttachment;
import com.bugsee.library.attachment.Report;
import com.bugsee.library.attachment.ReportAttachmentsProvider;
import com.bugsee.library.data.IssueSeverity;
import com.bugsee.library.events.BugseeLogLevel;
import com.bugsee.library.exchange.ExchangeNetworkEvent;
import com.bugsee.library.feedback.OnNewFeedbackListener;
import com.bugsee.library.lifecycle.LifecycleEventListener;
import com.bugsee.library.lifecycle.LifecycleEventTypes;
import com.bugsee.library.logs.BugseeLog;
import com.bugsee.library.logs.LogFilter;
import com.bugsee.library.logs.LogListener;
import com.bugsee.library.network.NetworkEventFilter;
import com.bugsee.library.network.NetworkEventListener;
import com.bugsee.library.network.data.BugseeNetworkEvent;
import com.bugsee.library.network.data.NetworkEventType;

/**
 * BugseePlugin
 */
public class BugseePlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
    private static final String TAG = "BugseeFlutterBridge";
    private static final String CHANNEL_NAME = "bugsee";

    private final HashMap<String, Method> methods = new HashMap<>();

    @Nullable
    private MethodChannel channel;
    private WeakReference<Activity> activityRef = null;
    private WeakReference<Context> contextRef = null;
    private OrientationTracker orientationTracker = null;
    private HashMap<String, Object> lastLaunchOptions;
    private final HashSet<String> activeCallbacks = new HashSet<>();
    private final HashMap<Integer, Rect[]> mInternalRectsMap = new HashMap<>();
    private long lastOrientationChangeTimeStamp = 0;

    public BugseePlugin() {
        // TODO: should we do this on launch instead?
        createHandlersAndCallbacks();
    }

    // ----------------------------------------------------------------------------------
    // region Nested classes (helper classes)

    /**
     * Special class to wrap actual exceptions and send them to the underlying
     * Bugsee SDK
     */
    private static class FlutterManagedException extends Exception {
        private static final long serialVersionUID = 1L;

        public FlutterManagedException(String message) {
            super(message);
        }
    }

    private static class ThreadUtils {
        private static Handler mainLooperHandler;

        private static void ensureHandlerCreated() {
            if (mainLooperHandler == null) {
                mainLooperHandler = new Handler(Looper.getMainLooper());
            }
        }

        public static void runOnUiThread(Runnable runnable) {
            if (isUiThread()) {
                runnable.run();
            } else {
                postToUiThread(runnable);
            }
        }

        public static synchronized void postToUiThread(Runnable runnable) {
            ensureHandlerCreated();
            mainLooperHandler.post(runnable);
        }

        public static boolean isUiThread() {
            return Looper.getMainLooper().getThread() == Thread.currentThread();
        }
    }

    // endregion
    // ----------------------------------------------------------------------------------

    // ----------------------------------------------------------------------------------
    // region Plugin embedding V1

    public static void registerWith(@NonNull Registrar registrar) {
        MethodChannel channel = new MethodChannel(registrar.messenger(), CHANNEL_NAME);
        Activity currentActivity = registrar.activity();
        BugseePlugin plugin = new BugseePlugin();
        plugin.activityRef = new WeakReference<>(currentActivity);
        plugin.channel = channel;
//        plugin.orientationTracker = new OrientationTracker(registrar.context(), new OrientationTrackerCallback() {
//            @Override
//            public void onOrientationChanged(Orientation newOrientation) {
//                plugin.setNewOrientation(newOrientation);
//            }
//        });
        channel.setMethodCallHandler(plugin);
    }

    // endregion
    // ----------------------------------------------------------------------------------

    // ----------------------------------------------------------------------------------
    // region Plugin embedding V2

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        contextRef = new WeakReference<>(binding.getApplicationContext());
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
        channel.setMethodCallHandler(this);
        orientationTracker = new OrientationTracker(contextRef, new OrientationTrackerCallback() {
            @Override
            public void onOrientationChanged(Orientation newOrientation) {
                setNewOrientation(newOrientation);
            }
        });
        orientationTracker.start();
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        // explicitly clear context reference here
        contextRef = null;

        // deregister handler and release channel reference
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }

        if (orientationTracker != null) {
            orientationTracker.stop();
            orientationTracker = null;
        }

        // plugin is completely detached from FlutterEngine. Stop our all
        // our internal mechanics and release resources
        BugseeInternalAdapter.stop(true);
    }

    // endregion
    // ----------------------------------------------------------------------------------

    // ----------------------------------------------------------------------------------
    // region Current activity tracking

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activityRef = new WeakReference<>(binding.getActivity());
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activityRef = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activityRef = new WeakReference<>(binding.getActivity());
    }

    @Override
    public void onDetachedFromActivity() {
        activityRef = null;
    }

    // endregion
    // ----------------------------------------------------------------------------------

    // ----------------------------------------------------------------------------------
    // region MethodCallHandler implementation and accompanying routines

    @Override
    @UiThread
    public void onMethodCall(MethodCall call, @NonNull Result result) {
        // we use switch here instead of reflection due to performance
        // of the latter. The downside of it, however, is much more
        // verbose and bloated code
        switch (call.method) {
            case "launch":
                launch(call, result);
                break;
            case "stop":
                stop(call, result);
                break;
            case "relaunch":
                relaunch(call, result);
                break;
            case "pause":
                pause(call, result);
                break;
            case "resume":
                resume(call, result);
                break;
            case "event":
                event(call, result);
                break;
            case "trace":
                trace(call, result);
                break;
            case "log":
                log(call, result);
                break;
            case "setAttribute":
                setAttribute(call, result);
                break;
            case "getAttribute":
                getAttribute(call, result);
                break;
            case "clearAttribute":
                clearAttribute(call, result);
                break;
            case "clearAllAttributes":
                clearAllAttributes(call, result);
                break;
            case "setEmail":
                setEmail(call, result);
                break;
            case "getEmail":
                getEmail(call, result);
                break;
            case "clearEmail":
                clearEmail(call, result);
                break;
            case "logException":
                logException(call, result);
                break;
            case "upload":
                upload(call, result);
                break;
            case "showReportDialog":
                showReportDialog(call, result);
                break;
            case "showFeedbackUI":
                showFeedbackUI(call, result);
                break;
            case "setDefaultFeedbackGreeting":
                setDefaultFeedbackGreeting(call, result);
                break;
            case "addSecureRect":
                addSecureRect(call, result);
                break;
            case "removeSecureRect":
                removeSecureRect(call, result);
                break;
            case "removeAllSecureRects":
                removeAllSecureRects(call, result);
                break;
            case "getAllSecureRects":
                getAllSecureRects(call, result);
                break;
            case "setSecureRectsInternal":
                setSecureRectsInternal(call, result);
                break;
            case "setViewHidden":
                setViewHidden(call, result);
                break;
            case "isViewHidden":
                isViewHidden(call, result);
                break;
            case "setAppearanceProperty":
                setAppearanceProperty(call, result);
                break;
            case "getAppearanceProperty":
                getAppearanceProperty(call, result);
                break;
            case "setCallbackState":
                setCallbackState(call, result);
                break;
            case "registerNetworkEvent":
                registerNetworkEvent(call, result);
                break;
            case "testExceptionCrash":
                testExceptionCrash(call, result);
                break;
            case "testSignalCrash":
                testSignalCrash(call, result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    // endregion
    // ----------------------------------------------------------------------------------

    // ----------------------------------------------------------------------------------
    // region State helpers

    @Nullable
    private Activity getCurrentActivity() {
        return this.activityRef != null ? this.activityRef.get() : null;
    }

    private Context getCurrentContext() {
        return this.contextRef != null ? this.contextRef.get() : null;
    }

    // endregion
    // ----------------------------------------------------------------------------------

    // ----------------------------------------------------------------------------------
    // region Execution management

    private void launch(MethodCall call, Result result) {
        int returnValue = 1;
        String appToken = call.argument("token");
        HashMap<String, Object> launchOptions = call.argument("launchOptions");

        Activity activity = getCurrentActivity();
        if (activity != null) {
            lastLaunchOptions = launchOptions;
            Bugsee.launch(activity, appToken, launchOptions);
        } else {
            Context context = getCurrentContext();
            if (context != null) {
                lastLaunchOptions = launchOptions;
                Bugsee.launch((Application) context, appToken, launchOptions);
            } else {
                returnValue = 0;
            }
        }

        result.success(returnValue);
    }

    private void stop(MethodCall call, Result result) {
        Bugsee.stop();
        result.success(null);
    }

    private void relaunch(MethodCall call, Result result) {
        HashMap<String, Object> launchOptions = null;
        if (call.hasArgument("launchOptions")) {
            launchOptions = call.argument("launchOptions");
        }
        launchOptions = (launchOptions == null) ? lastLaunchOptions : launchOptions;
        Bugsee.relaunch(launchOptions);
        result.success(null);
    }

    private void pause(MethodCall call, Result result) {
        Bugsee.pause();
        result.success(null);
    }

    private void resume(MethodCall call, Result result) {
        Bugsee.resume();
        result.success(null);
    }

    // endregion
    // ----------------------------------------------------------------------------------

    // ----------------------------------------------------------------------------------
    // region Events and traces

    private void event(MethodCall call, Result result) {
        String name = call.argument("name");
        HashMap<String, Object> parameters = null;

        if (call.hasArgument("parameters")) {
            parameters = call.argument("parameters");
        }

        if (parameters == null) {
            Bugsee.event(name);
        } else {
            Bugsee.event(name, parameters);
        }

        result.success(null);
    }

    private void trace(MethodCall call, Result result) {
        String name = call.argument("name");
        Object value = call.argument("value");
        Bugsee.trace(name, value);
        result.success(null);
    }

    // endregion
    // ----------------------------------------------------------------------------------

    // ----------------------------------------------------------------------------------
    // region Console

    private void log(MethodCall call, Result result) {
        String name = call.argument("text");
        BugseeLogLevel level = call.hasArgument("level") ? BugseeLogLevel.fromIntValue((int) call.argument("level"))
                : BugseeLogLevel.Info;
        Bugsee.log(name, level);
        result.success(null);
    }

    // endregion
    // ----------------------------------------------------------------------------------

    // ----------------------------------------------------------------------------------
    // region Attributes

    private void setAttribute(MethodCall call, Result result) {
        String key = call.argument("key");
        Object value = call.argument("value");
        Bugsee.setAttribute(key, value);
        result.success(null);
    }

    private void getAttribute(MethodCall call, Result result) {
        String key = call.argument("key");
        Object value = Bugsee.getAttribute(key);
        result.success(value);
    }

    private void clearAttribute(MethodCall call, Result result) {
        String key = call.argument("key");
        Bugsee.clearAttribute(key);
        result.success(null);
    }

    private void clearAllAttributes(MethodCall call, Result result) {
        Bugsee.clearAllAttributes();
        result.success(null);
    }

    // endregion
    // ----------------------------------------------------------------------------------

    // ----------------------------------------------------------------------------------
    // region Email field management

    private void setEmail(MethodCall call, Result result) {
        String value = call.argument("value");
        Bugsee.setEmail(value);
        result.success(null);
    }

    private void getEmail(MethodCall call, Result result) {
        String value = Bugsee.getEmail();
        result.success(value);
    }

    private void clearEmail(MethodCall call, Result result) {
        Bugsee.setEmail(null);
        result.success(null);
    }

    // endregion
    // ----------------------------------------------------------------------------------

    // ----------------------------------------------------------------------------------
    // region Exceptions

    private void logException(MethodCall call, final Result result) {
        String reason = call.argument("reason");
        Boolean isHandled = call.argument("handled");

        FlutterManagedException ex = new FlutterManagedException(reason);

        if (isHandled) {
            Bugsee.logException(ex);
        } else {
            Bugsee.onUncaughtException(Thread.currentThread(), ex);
        }

        result.success(null);
    }

    // endregion
    // ----------------------------------------------------------------------------------

    // ----------------------------------------------------------------------------------
    // region Manual upload

    private void _parseManualReportingDataAndCallMethod(MethodCall call, final Result result) {
        String summary = call.argument("summary");
        String description = call.argument("description");
        IssueSeverity severity = IssueSeverity.Medium;
        ArrayList<String> labels = call.argument("labels");
        Object rawSeverity = call.hasArgument("severity") ? call.argument("severity") : null;

        if (rawSeverity != null) {
            severity = IssueSeverity.fromIntValue((int) rawSeverity);
        } else {
            HashMap<String, Object> options = BugseeInternalAdapter.getLaunchOptions();
            if (options != null && options.containsKey(Bugsee.Option.DefaultBugPriority)) {
                try {
                    severity = IssueSeverity.fromIntValue((int) options.get(Bugsee.Option.DefaultBugPriority));
                } catch (Throwable t) {
                    // in case when nothing could be received or parsed,
                    // use Medium as fallback
                    severity = IssueSeverity.Medium;
                }
            }
        }

        if (call.method.equals("upload")) {
            Bugsee.upload(summary, description, severity, labels);
        } else if (call.method.equals("showReportDialog")) {
            Bugsee.showReportDialog(summary, description, severity, labels);
        }

        result.success(null);
    }

    private void upload(MethodCall call, final Result result) {
        this._parseManualReportingDataAndCallMethod(call, result);
    }

    private void showReportDialog(MethodCall call, final Result result) {
        this._parseManualReportingDataAndCallMethod(call, result);
    }

    // endregion
    // ----------------------------------------------------------------------------------

    // ----------------------------------------------------------------------------------
    // region Feedback

    private void showFeedbackUI(MethodCall call, final Result result) {
        Bugsee.showFeedbackActivity(null);
        result.success(null);
    }

    private void setDefaultFeedbackGreeting(MethodCall call, final Result result) {
        String greeting = call.argument("greeting");
        Bugsee.setDefaultFeedbackGreeting(greeting);
        result.success(null);
    }

    // endregion
    // ----------------------------------------------------------------------------------

    // ----------------------------------------------------------------------------------
    // region Secure rectangles

    private int getRectValue(Object rectValue) {
        if (rectValue instanceof Double) {
            return ((Double) rectValue).intValue();
        }

        return 0;
    }

    private Rect parseSecureRectData(MethodCall call) {
        int x = getRectValue(call.argument("x"));
        int y = getRectValue(call.argument("y"));
        int w = getRectValue(call.argument("width"));
        int h = getRectValue(call.argument("height"));

        return new Rect(x, y, x + w, y + h);
    }

    private void addSecureRect(MethodCall call, final Result result) {
        Bugsee.addSecureRectangle(parseSecureRectData(call));
        result.success(null);
    }

    private void removeSecureRect(MethodCall call, final Result result) {
        Bugsee.removeSecureRectangle(parseSecureRectData(call));
        result.success(null);
    }

    private void removeAllSecureRects(MethodCall call, final Result result) {
        Bugsee.removeAllSecureRectangles();
        result.success(null);
    }

    private void getAllSecureRects(MethodCall call, final Result result) {
        ArrayList<Rect> rawRectangles = Bugsee.getAllSecureRectangles();
        ArrayList<List<Double>> finalRectangles = new ArrayList<List<Double>>();

        for (Rect rawRect : rawRectangles) {
            List<Double> items = Arrays.asList((double) rawRect.left, (double) rawRect.top, (double) rawRect.width(),
                    (double) rawRect.height());
            finalRectangles.add(items);
        }

        result.success(finalRectangles);
    }

    private void setSecureRectsInternal(MethodCall call, final Result result) {
        result.success(null);

        int[] boundsData = call.argument("bounds");
        List<Rect> finalRectangles = null;

        if ((boundsData != null) && (boundsData.length > 0)) {
            finalRectangles = new ArrayList<>();
            Set<Integer> idsToKeep = new HashSet<>();

            for (int i = 0; i < boundsData.length; i += 5) {
                // Rect is constructed as <top left, right bottom>,
                // hence sum up X + Width, and Y + Height to get
                // right and bottom correspondingly
                int rectID = boundsData[i];
                idsToKeep.add(rectID);

                // we use two rectangles here to check and update the position
                // of the areas to obscure.
                //
                // stateRect:
                // Rectangle which contains the position from
                // the previous update. We always check the new data against it
                //
                // actualRect:
                // Rectangle denoting the current bounds of the
                // target area and which is altered with diffing on each update
                //

                if (!mInternalRectsMap.containsKey(rectID)) {
                    Rect newRect = new Rect(
                            boundsData[i + 1],
                            boundsData[i + 2],
                            boundsData[i + 1] + boundsData[i + 3],
                            boundsData[i + 2] + boundsData[i + 4]);
                    mInternalRectsMap.put(rectID, new Rect[] {
                            // this is state check rect
                            new Rect(newRect),
                            // this is actual rect
                            newRect
                    });
                    finalRectangles.add(new Rect(newRect));
                } else {
                    Rect[] rects = mInternalRectsMap.get(rectID);
                    if (rects != null) {
                        Rect stateRect = rects[0];
                        Rect actualRect = rects[1];

                        int left = boundsData[i + 1];
                        int top = boundsData[i + 2];
                        int right = left + boundsData[i + 3];
                        int bottom = top + boundsData[i + 4];

                        int diffL = left - stateRect.left;
                        int diffT = top - stateRect.top;
                        int diffR = right - stateRect.right;
                        int diffB = bottom - stateRect.bottom;

                        stateRect.set(left, top, right, bottom);

                        if (Math.abs(diffT) <= 1 && Math.abs(diffB) <= 1 && Math.abs(diffL) <= 1
                                && Math.abs(diffR) <= 1) {
                            actualRect.set(stateRect);
                        } else {
                            left = Math.min(left, actualRect.left);
                            top = Math.min(top, actualRect.top);
                            right = Math.max(right, actualRect.right);
                            bottom = Math.max(bottom, actualRect.bottom);

                            actualRect.set(left, top, right, bottom);
                        }

                        finalRectangles.add(new Rect(actualRect));
                    }
                }
            }

            // note that Set<> returned from keySet is connected to the
            // underlying Map. Hence, modifications to the set are
            // propagated to the Map itself
            mInternalRectsMap.keySet().retainAll(idsToKeep);
        } else {
            mInternalRectsMap.clear();
        }

        if (finalRectangles != null) {
            long currentTimestamp = System.currentTimeMillis();
            if (currentTimestamp - lastOrientationChangeTimeStamp < 1500) {
                finalRectangles.add(new Rect(0,0,99999,99999));
            }
        }

        Bugsee.setSecureRectsInternal(finalRectangles);
    }

    // endregion
    // ----------------------------------------------------------------------------------

    // ----------------------------------------------------------------------------------
    // region View management

    private void setViewHidden(MethodCall call, final Result result) {
        result.success(null);
    }

    private void isViewHidden(MethodCall call, final Result result) {
        result.success(null);
    }

    // endregion
    // ----------------------------------------------------------------------------------

    // ----------------------------------------------------------------------------------
    // region Appearance

    private Field getAppearanceField(String fieldName) {
        try {
            return Bugsee.getAppearance().getClass().getDeclaredField(fieldName);
        } catch (Throwable t) {
            BugseeInternalAdapter.logWarning(TAG, t.toString(), false);
        }

        return null;
    }

    private void setAppearanceProperty(MethodCall call, final Result result) {
        String colorProperty = call.argument("cP");

        Field field = getAppearanceField(colorProperty);
        if (field != null) {
            int cR = call.argument("cR");
            int cG = call.argument("cG");
            int cB = call.argument("cB");
            int cA = call.argument("cA");
            int colorValue = Color.argb(cA, cR, cG, cB);

            try {
                field.set(Bugsee.getAppearance(), colorValue);
            } catch (Throwable t) {
                BugseeInternalAdapter.logWarning(TAG, t.toString(), false);
            }
        }

        result.success(null);
    }

    private void getAppearanceProperty(MethodCall call, final Result result) {
        String colorProperty = call.argument("cP");
        HashMap<String, Integer> colorComponents = null;

        Field field = getAppearanceField(colorProperty);
        if (field != null) {
            try {
                final int colorValue = (int) field.get(Bugsee.getAppearance());

                colorComponents = new HashMap<String, Integer>() {
                    {
                        put("cR", Color.red(colorValue));
                        put("cG", Color.green(colorValue));
                        put("cB", Color.blue(colorValue));
                        put("cA", Color.alpha(colorValue));
                    }
                };
            } catch (Throwable t) {
                BugseeInternalAdapter.logWarning(TAG, t.toString(), false);
            }
        }

        result.success(colorComponents);
    }

    // endregion
    // ----------------------------------------------------------------------------------

    // ----------------------------------------------------------------------------------
    // region Events and callbacks

    private void setCallbackState(MethodCall call, final Result result) {
        String callbackName = call.argument("callbackName");
        boolean flagState = call.argument("state");

        if (flagState) {
            activeCallbacks.add(callbackName);
        } else {
            activeCallbacks.remove(callbackName);
        }

        result.success(null);
    }

    private void filterNetworkEvent(final BugseeNetworkEvent bugseeNetworkEvent,
            final NetworkEventListener networkEventListener) {
        if (channel != null) {
            final NetworkEventType eventStage = bugseeNetworkEvent.getEventType();
            HashMap<String, Object> serializedEvent = new HashMap<String, Object>() {
                {
                    put("url", bugseeNetworkEvent.getUrl());
                    put("body", bugseeNetworkEvent.getBody());
                    put("method", bugseeNetworkEvent.getMethod());
                    // event stage in not a primitive, but rather an enum value
                    // hence we need to convert it to string to let it be
                    // properly passed through the codec
                    put("stage", eventStage != null ? eventStage.toString() : null);
                    // put("redirectedFrom", ?);
                    put("headers", bugseeNetworkEvent.getHeaders());
                }
            };

            channel.invokeMethod("onNetworkEvent", Collections.singletonList(serializedEvent), new Result() {
                @Override
                public void success(@Nullable Object result) {
                    if (result instanceof Map) {
                        try {
                            Map<String, Object> resultData = (Map<String, Object>) result;
                            bugseeNetworkEvent.setBody((String) resultData.get("body"));
                            bugseeNetworkEvent.setUrl((String) resultData.get("url"));
                            bugseeNetworkEvent.setHeaders((Map<String, Object>) resultData.get("headers"));
                            networkEventListener.onEvent(bugseeNetworkEvent);
                        } catch (Exception e) {
                            BugseeInternalAdapter.logWarning(TAG,
                                    "Failed to handle network event filtering result. Error: " + e.toString(), false);
                        }
                        return;
                    }

                    networkEventListener.onEvent(null);
                }

                @Override
                public void error(String errorCode, @Nullable String errorMessage, @Nullable Object errorDetails) {
                    // in case of error, do not log anything to prevent possible
                    // data leakage/disclosure
                    networkEventListener.onEvent(null);
                }

                @Override
                public void notImplemented() {
                    // this is also called when null is returned by the remote
                    // end
                    networkEventListener.onEvent(null);
                }
            });
        }
    }

    private void filterConsoleEvent(final BugseeLog bugseeLog, final LogListener logListener) {
        if (channel != null) {
            ArrayList<Object> arguments = new ArrayList<Object>() {
                {
                    add(bugseeLog.getMessage());
                    add(bugseeLog.getLevel().getIntValue());
                }
            };

            channel.invokeMethod("onLogEvent", arguments, new Result() {
                @Override
                public void success(@Nullable Object result) {
                    if (result instanceof List) {
                        try {
                            List<Object> resultArray = (List<Object>) result;
                            bugseeLog.setMessage((String) resultArray.get(0));
                            bugseeLog.setLevel(BugseeLogLevel.fromIntValue((int) resultArray.get(1)));
                            logListener.onLog(bugseeLog);
                        } catch (Exception e) {
                            BugseeInternalAdapter.logWarning(TAG,
                                    "Failed to handle console event filtering result. Error: " + e.toString(), false);
                        }
                        return;
                    }

                    logListener.onLog(null);
                }

                @Override
                public void error(String errorCode, @Nullable String errorMessage, @Nullable Object errorDetails) {
                    // in case of error, do not log anything to prevent possible
                    // data leakage/disclosure
                    logListener.onLog(null);
                }

                @Override
                public void notImplemented() {
                    // this is also called when null is returned by the remote
                    // end
                    logListener.onLog(null);
                }
            });
        }
    }

    private void handleAttachments(final Report report) {
        if (channel != null) {
            List<Object> reportArgs = new ArrayList<Object>() {
                {
                    add(report.getType().toString());
                    add(report.getSeverity().getIntValue());
                }
            };

            channel.invokeMethod("onAttachmentsForReport", reportArgs, new Result() {
                @Override
                public void success(@Nullable Object result) {
                    if (result instanceof List) {
                        try {
                            List<List<Object>> resultData = (List<List<Object>>) result;
                            ArrayList<CustomAttachment> attachments = new ArrayList<>();

                            for (List<Object> itemValues : resultData) {
                                CustomAttachment attachment = null;
                                String name = (String) itemValues.get(0);
                                String fileName = (String) itemValues.get(1);
                                byte[] rawData = (byte[]) itemValues.get(2);

                                if (rawData != null) {
                                    String dataString = new String(rawData);
                                    if (!dataString.isEmpty()) {
                                        attachment = CustomAttachment.fromDataString(dataString);
                                        attachment.setName(name);
                                        attachment.setFileName(fileName);
                                        attachments.add(attachment);
                                    }
                                }
                            }

                            BugseeInternalAdapter.setAttachments(attachments);
                            return;
                        } catch (Exception e) {
                            BugseeInternalAdapter.logWarning(TAG,
                                    "Failed to handle attachments. Error: " + e.toString(), false);
                        }
                    }

                    BugseeInternalAdapter.setAttachments(new ArrayList<CustomAttachment>());
                }

                @Override
                public void error(String errorCode, @Nullable String errorMessage, @Nullable Object errorDetails) {
                    // in case of error, just put an empty attachments list
                    BugseeInternalAdapter.setAttachments(new ArrayList<CustomAttachment>());
                }

                @Override
                public void notImplemented() {
                    // just put an empty attachments list
                    BugseeInternalAdapter.setAttachments(new ArrayList<CustomAttachment>());
                }
            });
        }
    }

    private void createHandlersAndCallbacks() {
        Bugsee.setNetworkEventFilter(new NetworkEventFilter() {
            @Override
            public void filter(final BugseeNetworkEvent bugseeNetworkEvent,
                    final NetworkEventListener networkEventListener) {
                if (!activeCallbacks.contains("onNetworkEvent")) {
                    networkEventListener.onEvent(bugseeNetworkEvent);
                }

                ThreadUtils.runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        filterNetworkEvent(bugseeNetworkEvent, networkEventListener);
                    }
                });
            }
        });

        Bugsee.setLogFilter(new LogFilter() {
            @Override
            public void filter(final BugseeLog bugseeLog, final LogListener logListener) {
                if (!activeCallbacks.contains("onLogEvent")) {
                    logListener.onLog(bugseeLog);
                }

                ThreadUtils.runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        filterConsoleEvent(bugseeLog, logListener);
                    }
                });
            }
        });

        BugseeInternalAdapter.setAttachmentsAsync(true);
        Bugsee.setReportAttachmentsProvider(new ReportAttachmentsProvider() {
            @Override
            public ArrayList<CustomAttachment> getAttachments(final Report report) {
                if (activeCallbacks.contains("onAttachmentsForReport")) {
                    ThreadUtils.runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            handleAttachments(report);
                        }
                    });
                } else {
                    // there is no attachments handler set in user code,
                    // hence just return an empty set
                    BugseeInternalAdapter.setAttachments(new ArrayList<CustomAttachment>());
                }

                // In async flow, this result will be ignored,
                // so just return an empty array list
                return new ArrayList<>();
            }
        });

        Bugsee.setOnNewFeedbackListener(new OnNewFeedbackListener() {
            @Override
            public void onNewFeedback(final List<String> list) {
                if (channel != null) {
                    // MessageChannel.invokeMethod() must be executed on UI thread,
                    // that is why we need all the logic below
                    ThreadUtils.runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            if (channel != null) {
                                channel.invokeMethod("onNewFeedbackMessages", Collections.singletonList(list));
                            }
                        }
                    });
                }
            }
        });

        Bugsee.setLifecycleEventsListener(new LifecycleEventListener() {
            @Override
            public void onEvent(final LifecycleEventTypes eventType) {
                if (channel != null) {
                    // MessageChannel.invokeMethod() must be executed on UI thread,
                    // that is why we need all the logic below
                    ThreadUtils.runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            if (channel != null) {
                                channel.invokeMethod("onLifecycleEvent",
                                        Collections.singletonList(eventType.getIntValue()));
                            }
                        }
                    });
                }
            }
        });
    }

    private <T> T getParamOrDefault(Map<String, Object> params, String paramName, T defaultValue) {
        Object value = params.get(paramName);
        if (value == null) {
            return defaultValue;
        }

        return (T) value;
    }

    private void registerNetworkEvent(MethodCall call, final Result result) {
        ExchangeNetworkEvent networkEvent = new ExchangeNetworkEvent();
        Map<String, Object> eventData = call.arguments();

        networkEvent.id = getParamOrDefault(eventData, "id", "");
        networkEvent.type = getParamOrDefault(eventData, "type", "begin");
        networkEvent.timestamp = getParamOrDefault(eventData, "timestamp", System.currentTimeMillis());
        networkEvent.method = getParamOrDefault(eventData, "method", "");
        networkEvent.url = getParamOrDefault(eventData, "url", "");
        networkEvent.size = getParamOrDefault(eventData, "size", 0);
        networkEvent.body = getParamOrDefault(eventData, "body", "");
        networkEvent.headers = getParamOrDefault(eventData, "headers", new HashMap<String, String>());
        networkEvent.isSupplement = getParamOrDefault(eventData, "isSupplement", false);

        if (eventData.containsKey("status")) {
            networkEvent.status = getParamOrDefault(eventData, "status", 200);
        }

        networkEvent.error = getParamOrDefault(eventData, "error", null);

        BugseeInternalAdapter.addNetworkEvent(networkEvent);
        result.success(null);
    }

    // endregion
    // ----------------------------------------------------------------------------------

    // ----------------------------------------------------------------------------------
    // region Custom logic

    private void testExceptionCrash(MethodCall call, final Result result) {
        int a = 1;
        int b = a - 1;
        int c = a / b;
        result.success(c);
    }

    private void testSignalCrash(MethodCall call, final Result result) {
        // TODO: can we trigger signal crash from here?
        Process.sendSignal(Process.myPid(), 11);
        result.success(null);
    }

    private enum Orientation {
        PortraitUp,
        PortraitDown,
        LandscapeLeft,
        LandscapeRight,
        Unknown
    }

    private interface OrientationTrackerCallback {
        void onOrientationChanged(Orientation newOrientation);
    }

    private class OrientationTracker {
        private final WeakReference<Context> contextRef;
        private final OrientationTrackerCallback callback;
        private OrientationEventListener platformListener;
        private Orientation lastOrientation = null;

        public OrientationTracker(WeakReference<Context> contextRef, OrientationTrackerCallback callback) {
            this.contextRef = contextRef;
            this.callback = callback;
        }

        public void start() {
            if (platformListener == null && contextRef != null && contextRef.get() != null) {
                platformListener = new OrientationEventListener(contextRef.get(), SensorManager.SENSOR_DELAY_NORMAL) {
                    @Override
                    public void onOrientationChanged(int angle) {
                        Orientation newOrientation = calculateSensorOrientation(angle);
                        if (!newOrientation.equals(lastOrientation)) {
                            lastOrientation = newOrientation;
                            callback.onOrientationChanged(newOrientation);
                        }
                    }
                };
                if (platformListener.canDetectOrientation()) {
                    platformListener.enable();
                }
            }
        }

        public void stop() {
            if (platformListener != null) {
                platformListener.disable();
                platformListener = null;
            }
        }

        public Orientation calculateSensorOrientation(int angle) {
            angle += 45; // tolerance

            // orientation of 0 denotes "portrait" for smartphones
            // and "landscape" for tablets (aka default mode). Hence we
            // need to use proper offset applying an offset.
            int defaultDeviceOrientation = getDefaultOrientation();
            if (defaultDeviceOrientation == Configuration.ORIENTATION_LANDSCAPE) {
                angle += 90;
            }

            angle = angle % 360;
            int screenOrientation = angle / 90;

            switch (screenOrientation) {
                case 0:
                    return Orientation.PortraitUp;
                case 1:
                    return Orientation.LandscapeRight;
                case 2:
                    return Orientation.PortraitDown;
                case 3:
                    return Orientation.LandscapeLeft;
                default:
                    return Orientation.Unknown;
            }
        }

        private int getDefaultOrientation() {
            Context context = contextRef.get();

            if (context != null) {
                Configuration config = context.getResources().getConfiguration();
                int rotation = ((WindowManager) context.getSystemService(Context.WINDOW_SERVICE))
                        .getDefaultDisplay().getRotation();

                if (((rotation == Surface.ROTATION_180 || rotation == Surface.ROTATION_0) &&
                        config.orientation == Configuration.ORIENTATION_LANDSCAPE)
                        || ((rotation == Surface.ROTATION_90 || rotation == Surface.ROTATION_270) &&
                        config.orientation == Configuration.ORIENTATION_PORTRAIT)) {
                    return Configuration.ORIENTATION_LANDSCAPE;
                } else {
                    return Configuration.ORIENTATION_PORTRAIT;
                }
            }

            // if we can't get anything - just return some default
            return Configuration.ORIENTATION_PORTRAIT;
        }
    }

    private void setNewOrientation(Orientation newOrientation) {
        lastOrientationChangeTimeStamp = System.currentTimeMillis();

        if (mInternalRectsMap.size() > 0) {
            // if we have secure rectangles and device is rotated,
            // obscure the whole screen to make sure nothing is
            // leaked
            Bugsee.setSecureRectsInternal(Collections.singletonList(new Rect(0, 0, 99999, 99999)));
        }
    }

    // endregion
    // ----------------------------------------------------------------------------------
}
