package com.bugsee.bugsee;

import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.PluginRegistry.Registrar;

import com.bugsee.library.Bugsee;

/**
 * BugseePlugin
 */
public class BugseePlugin implements MethodCallHandler {
    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "bugsee");
        channel.setMethodCallHandler(new BugseePlugin());
    }

    private void handleEvent(MethodCall call, final Result result) {
        @SuppressWarnings("unchecked")
        Map<String, Object> arguments = (Map<String, Object>) call.arguments;
        String name = (String)arguments.get("name");
        @SuppressWarnings("unchecked")
        HashMap<String, Object> parameters = (HashMap<String, Object>)arguments.get("parameters");
        Bugsee.event(name, parameters);
    }

    private void handleTrace(MethodCall call, final Result result) {
        @SuppressWarnings("unchecked")
        Map<String, Object> arguments = (Map<String, Object>) call.arguments;
        String name = (String)arguments.get("name");
        Object value = arguments.get("value");
//        Bugsee.event(name, value);
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        switch (call.method) {
            case "event":
                handleEvent(call, result);
                break;

            case "trace":
                handleTrace(call, result);
                break;

            default:
                result.notImplemented();
                break;
        }

    }
}
