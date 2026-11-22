package com.peace.updater;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.widget.Toast;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedInputStream;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;

public class PeaceUpdater {

    public static final String RAW_JSON_URL = "https://raw.githubusercontent.com/peacemusic1709-eng/Peace-Music/main/version.json";
    public static final String GITHUB_RELEASES_URL = "https://api.github.com/repos/peacemusic1709-eng/Peace-Music/releases/latest";

    private static boolean isDownloading = false;

    public static void checkUpdate(final Activity activity) {
        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    // Small delay to let Flutter UI initialize smoothly
                    Thread.sleep(3000);

                    int latestCode = 0;
                    String latestName = "";
                    String apkUrl = "";
                    String changelog = "Naye songs aur performance improvements shamil kiye gaye hain.";

                    // 1. Try reading raw version.json
                    try {
                        URL url = new URL(RAW_JSON_URL);
                        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                        conn.setConnectTimeout(5000);
                        conn.setReadTimeout(5000);
                        conn.setRequestProperty("User-Agent", "PeaceMusicApp");

                        if (conn.getResponseCode() == 200) {
                            String body = readStream(conn.getInputStream());
                            JSONObject json = new JSONObject(body);
                            latestCode = json.optInt("versionCode", 0);
                            latestName = json.optString("versionName", "");
                            apkUrl = json.optString("apkUrl", "");
                            if (json.has("changelog")) {
                                changelog = json.optString("changelog");
                            }
                        }
                    } catch (Exception ignored) {
                    }

                    // 2. Fallback to GitHub Releases API if needed
                    if (apkUrl.isEmpty()) {
                        try {
                            URL url = new URL(GITHUB_RELEASES_URL);
                            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                            conn.setConnectTimeout(5000);
                            conn.setReadTimeout(5000);
                            conn.setRequestProperty("User-Agent", "PeaceMusicApp");

                            if (conn.getResponseCode() == 200) {
                                String body = readStream(conn.getInputStream());
                                JSONObject json = new JSONObject(body);
                                String tagName = json.optString("tag_name", "");
                                if (!tagName.isEmpty()) {
                                    latestName = tagName;
                                    String cleanTag = tagName.replaceAll("[^0-9]", "");
                                    if (!cleanTag.isEmpty()) {
                                        try {
                                            latestCode = Integer.parseInt(cleanTag);
                                        } catch (Exception e) {
                                            latestCode = 0;
                                        }
                                    }
                                }
                                if (json.has("body")) {
                                    changelog = json.optString("body");
                                }
                                JSONArray assets = json.optJSONArray("assets");
                                if (assets != null) {
                                    for (int i = 0; i < assets.length(); i++) {
                                        JSONObject asset = assets.getJSONObject(i);
                                        String downloadUrl = asset.optString("browser_download_url", "");
                                        if (downloadUrl.toLowerCase().endsWith(".apk")) {
                                            apkUrl = downloadUrl;
                                            break;
                                        }
                                    }
                                }
                            }
                        } catch (Exception ignored) {
                        }
                    }

                    if (apkUrl.isEmpty()) return;

                    PackageInfo pInfo = activity.getPackageManager().getPackageInfo(activity.getPackageName(), 0);
                    int curCode = pInfo.versionCode;
                    String curName = pInfo.versionName != null ? pInfo.versionName : "1.0.0";

                    // Strict check: ONLY update if remote version is strictly newer!
                    boolean isNewer = isNewerVersion(latestCode, latestName, curCode, curName);

                    if (isNewer) {
                        final String finalVersionName = latestName.isEmpty() ? ("v" + latestCode) : latestName;
                        final String finalApkUrl = apkUrl;
                        final String finalChangelog = changelog;

                        new Handler(Looper.getMainLooper()).post(new Runnable() {
                            @Override
                            public void run() {
                                showUpdateDialog(activity, finalVersionName, finalApkUrl, finalChangelog);
                            }
                        });
                    }
                } catch (Exception ignored) {
                }
            }
        }).start();
    }

    public static boolean isNewerVersion(int latestCode, String latestName, int curCode, String curName) {
        // Priority 1: Check integer versionCode
        if (latestCode > 0 && curCode > 0) {
            return latestCode > curCode;
        }

        // Priority 2: Semantic version comparison (e.g. 1.0.1 > 1.0.0)
        try {
            String cleanL = latestName.replaceAll("[^0-9.]", "").trim();
            String cleanC = curName.replaceAll("[^0-9.]", "").trim();
            if (cleanL.isEmpty() || cleanC.isEmpty()) return false;

            String[] lParts = cleanL.split("\\.");
            String[] cParts = cleanC.split("\\.");
            int maxLen = Math.max(lParts.length, cParts.length);
            for (int i = 0; i < maxLen; i++) {
                int l = (i < lParts.length && !lParts[i].isEmpty()) ? Integer.parseInt(lParts[i]) : 0;
                int c = (i < cParts.length && !cParts[i].isEmpty()) ? Integer.parseInt(cParts[i]) : 0;
                if (l > c) return true;
                if (l < c) return false;
            }
        } catch (Exception ignored) {
        }
        return false;
    }

    private static String readStream(InputStream is) throws Exception {
        BufferedReader reader = new BufferedReader(new InputStreamReader(is, "UTF-8"));
        StringBuilder sb = new StringBuilder();
        String line;
        while ((line = reader.readLine()) != null) {
            sb.append(line);
        }
        reader.close();
        return sb.toString();
    }

    public static File pendingInstallFile = null;

    public static void checkPendingInstall(final Activity activity) {
        if (activity == null || activity.isFinishing()) return;
        if (pendingInstallFile != null && pendingInstallFile.exists()) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || activity.getPackageManager().canRequestPackageInstalls()) {
                final File toInstall = pendingInstallFile;
                pendingInstallFile = null;
                new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        installApk(activity, toInstall);
                    }
                }, 500);
            }
        }
    }

    private static void showUpdateDialog(final Activity activity, final String versionName, final String apkUrl, final String changelog) {
        if (activity == null || activity.isFinishing()) return;

        AlertDialog.Builder builder = new AlertDialog.Builder(activity);
        builder.setTitle("New Update Available!");
        builder.setMessage("Peace Music " + versionName + " uplabdh hai!\n\n" + changelog + "\n\nKya aap download karna chahte hain?");
        builder.setCancelable(true);
        builder.setPositiveButton("Update Now", new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                dialog.dismiss();
                if (!isDownloading) {
                    Toast.makeText(activity, "Downloading update in background... 🎵 Aap music sunte rahein!", Toast.LENGTH_LONG).show();
                    startBackgroundDownload(activity, apkUrl);
                }
            }
        });
        builder.setNegativeButton("Later", new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                dialog.dismiss();
            }
        });
        builder.create().show();
    }

    private static void startBackgroundDownload(final Activity activity, final String apkUrl) {
        isDownloading = true;

        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    URL url = new URL(apkUrl);
                    HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                    conn.setConnectTimeout(10000);
                    conn.setReadTimeout(30000);
                    conn.setInstanceFollowRedirects(true);
                    conn.connect();

                    // Handle redirects (GitHub Release to AWS S3)
                    int status = conn.getResponseCode();
                    if (status == HttpURLConnection.HTTP_MOVED_TEMP || status == HttpURLConnection.HTTP_MOVED_PERM || status == 307 || status == 308) {
                        String newUrl = conn.getHeaderField("Location");
                        conn = (HttpURLConnection) new URL(newUrl).openConnection();
                        conn.connect();
                    }

                    File cacheDir = activity.getExternalCacheDir();
                    if (cacheDir == null) cacheDir = activity.getCacheDir();
                    final File apkFile = new File(cacheDir, "PeaceMusic_Update.apk");

                    InputStream input = new BufferedInputStream(conn.getInputStream(), 8192);
                    FileOutputStream output = new FileOutputStream(apkFile);

                    byte[] data = new byte[8192];
                    int count;
                    while ((count = input.read(data)) != -1) {
                        output.write(data, 0, count);
                    }
                    output.flush();
                    output.close();
                    input.close();

                    isDownloading = false;

                    // Download complete: trigger Android package installer!
                    new Handler(Looper.getMainLooper()).post(new Runnable() {
                        @Override
                        public void run() {
                            Toast.makeText(activity, "Update Downloaded! Installing...", Toast.LENGTH_SHORT).show();
                            installApk(activity, apkFile);
                        }
                    });

                } catch (final Exception e) {
                    isDownloading = false;
                    new Handler(Looper.getMainLooper()).post(new Runnable() {
                        @Override
                        public void run() {
                            Toast.makeText(activity, "Download failed: " + e.getMessage(), Toast.LENGTH_LONG).show();
                        }
                    });
                }
            }
        }).start();
    }

    public static void installApk(final Activity activity, final File file) {
        new Handler(Looper.getMainLooper()).post(new Runnable() {
            @Override
            public void run() {
                try {
                    if (activity == null || activity.isFinishing()) return;

                    // Android 8.0+ REQUEST_INSTALL_PACKAGES permission check
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        if (!activity.getPackageManager().canRequestPackageInstalls()) {
                            pendingInstallFile = file;
                            new AlertDialog.Builder(activity)
                                .setTitle("Permission Required")
                                .setMessage("Peace Music update install karne ke liye ek baar 'Allow from this source' enable kar dijiye.")
                                .setPositiveButton("Settings Kholein", new DialogInterface.OnClickListener() {
                                    @Override
                                    public void onClick(DialogInterface dialog, int which) {
                                        try {
                                            Intent reqIntent = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES);
                                            reqIntent.setData(Uri.parse("package:" + activity.getPackageName()));
                                            activity.startActivity(reqIntent);
                                        } catch (Exception e) {
                                            Intent reqIntent = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES);
                                            activity.startActivity(reqIntent);
                                        }
                                    }
                                })
                                .setNegativeButton("Cancel", null)
                                .show();
                            return;
                        }
                    }

                    Uri apkUri = PeaceFileProvider.getUriForFile(activity, file);

                    Intent intent = new Intent(Intent.ACTION_VIEW);
                    intent.setDataAndType(apkUri, "application/vnd.android.package-archive");
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    intent.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION);

                    // Explicitly grant URI permission to all potential package installers
                    try {
                        android.content.pm.PackageManager pm = activity.getPackageManager();
                        java.util.List<android.content.pm.ResolveInfo> resolveInfos = pm.queryIntentActivities(intent, android.content.pm.PackageManager.MATCH_DEFAULT_ONLY);
                        if (resolveInfos != null) {
                            for (android.content.pm.ResolveInfo resolveInfo : resolveInfos) {
                                String packageName = resolveInfo.activityInfo.packageName;
                                activity.grantUriPermission(packageName, apkUri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
                            }
                        }
                    } catch (Exception ignored) {}

                    activity.startActivity(intent);

                } catch (Exception e) {
                    Toast.makeText(activity, "Install error: " + e.getMessage(), Toast.LENGTH_LONG).show();
                }
            }
        });
    }
}
