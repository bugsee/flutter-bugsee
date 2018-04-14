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
        options.put("endpoint",  "http://apidev.bugsee.com");
        Bugsee.launch(this, "2a618407-54e7-44f6-bf77-6c872c868053", options);
    }
}
