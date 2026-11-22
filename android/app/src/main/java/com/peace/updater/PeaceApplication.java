package com.peace.updater;

import android.app.Activity;
import android.app.Application;
import android.os.Bundle;

public class PeaceApplication extends Application {

    private static boolean updateChecked = false;

    @Override
    public void onCreate() {
        super.onCreate();

        registerActivityLifecycleCallbacks(new ActivityLifecycleCallbacks() {
            @Override
            public void onActivityCreated(Activity activity, Bundle savedInstanceState) {
                // Trigger auto update check only once per app session when MainActivity loads
                if (!updateChecked && activity != null && activity.getClass().getName().contains("MainActivity")) {
                    updateChecked = true;
                    PeaceUpdater.checkUpdate(activity);
                }
            }

            @Override public void onActivityStarted(Activity activity) {}
            @Override
            public void onActivityResumed(Activity activity) {
                PeaceUpdater.checkPendingInstall(activity);
            }
            @Override public void onActivityPaused(Activity activity) {}
            @Override public void onActivityStopped(Activity activity) {}
            @Override public void onActivitySaveInstanceState(Activity activity, Bundle outState) {}
            @Override public void onActivityDestroyed(Activity activity) {}
        });
    }
}
