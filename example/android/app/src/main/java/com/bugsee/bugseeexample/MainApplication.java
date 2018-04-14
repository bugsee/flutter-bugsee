package com.bugsee.bugseeexample;

import android.app.Application;
import com.bugsee.library.Bugsee;

import java.util.HashMap;

import io.flutter.app.FlutterApplication;

/**
 * Created by finik on 4/13/18.
 */

public class MainApplication extends FlutterApplication {
    @Override
    public void onCreate() {
        super.onCreate();
        HashMap<String, Object> options = new HashMap<>();

        // Regular doesn't capture anything in Flutter for now
        options.put(Bugsee.Option.ExtendedVideoMode, true);
        Bugsee.launch(this, "YOUR APP TOKEN", options);
    }
}
