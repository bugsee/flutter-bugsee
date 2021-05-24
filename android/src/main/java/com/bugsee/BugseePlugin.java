package com.bugsee;

import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.graphics.Color;
import android.graphics.Rect;
import android.os.Process;
import android.os.Handler;
import android.os.Looper;

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
    private HashMap<String, Object> lastLaunchOptions;
    private final HashSet<String> activeCallbacks = new HashSet<>();

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
        // TODO: replace this with a new API which will set internal secure rectangles
        Bugsee.removeAllSecureRectangles();

        List<Double> bounds = call.argument("bounds");
        for (int i = 0; i < bounds.size(); i += 4) {
            int x = getRectValue(bounds.get(i));
            int y = getRectValue(bounds.get(i + 1));
            int w = getRectValue(bounds.get(i + 2)) + x;
            int h = getRectValue(bounds.get(i + 3)) + y;
            Rect rect = new Rect(x, y, w, h);
            Bugsee.addSecureRectangle(rect);
        }

        result.success(null);
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
        HashMap<String, Object> serializedEvent = new HashMap<String, Object>() {
            {
                put("url", bugseeNetworkEvent.getUrl());
                put("body", bugseeNetworkEvent.getBody());
                put("method", bugseeNetworkEvent.getMethod());
                put("stage", bugseeNetworkEvent.getEventType());
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

    private void filterConsoleEvent(final BugseeLog bugseeLog, final LogListener logListener) {
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

    private void handleAttachments(final Report report) {
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
                        BugseeInternalAdapter.logWarning(TAG, "Failed to handle attachments. Error: " + e.toString(),
                                false);
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
                            channel.invokeMethod("onNewFeedbackMessages", Collections.singletonList(list));
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
                            channel.invokeMethod("onLifecycleEvent",
                                    Collections.singletonList(eventType.getIntValue()));
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

    // endregion
    // ----------------------------------------------------------------------------------
}
