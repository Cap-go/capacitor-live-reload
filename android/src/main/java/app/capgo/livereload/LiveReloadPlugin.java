package app.capgo.livereload;

import android.app.Activity;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.webkit.WebView;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import okhttp3.Headers;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.WebSocket;
import okhttp3.WebSocketListener;
import org.json.JSONException;
import org.json.JSONObject;

@CapacitorPlugin(name = "LiveReload")
public class LiveReloadPlugin extends Plugin {

    private final String pluginVersion = "7.0.0";

    private static final String TAG = "LiveReload";

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final OkHttpClient client = new OkHttpClient.Builder().pingInterval(15, TimeUnit.SECONDS).build();

    private WebSocket socket;
    private String serverUrl;
    private String websocketPath = "/ws";
    private Map<String, String> headers = new HashMap<>();
    private boolean autoReconnect = true;
    private long reconnectIntervalMs = 2000;
    private boolean reconnectScheduled = false;

    private boolean connected = false;
    private boolean manualDisconnect = false;
    private String initialUrl;
    private boolean usingLiveReload = false;
    private AlertDialog disconnectDialog;

    @PluginMethod
    public void configureServer(PluginCall call) {
        String url = call.getString("url");
        if (url == null || url.isEmpty()) {
            call.reject("Missing 'url'");
            return;
        }
        serverUrl = url;
        websocketPath = call.getString("websocketPath", "/ws");
        autoReconnect = call.getBoolean("autoReconnect", true);
        reconnectIntervalMs = call.getInt("reconnectInterval", 2000);

        headers = new HashMap<>();
        JSObject jsonHeaders = call.getObject("headers", new JSObject());
        for (Iterator<String> it = jsonHeaders.keys(); it.hasNext(); ) {
            String key = it.next();
            String value = jsonHeaders.optString(key, null);
            if (value != null) {
                headers.put(key, value);
            }
        }

        captureInitialUrl();

        JSObject result = buildStatus();
        notifyStatus();
        call.resolve(result);
    }

    @PluginMethod
    public void connect(PluginCall call) {
        if (serverUrl == null || serverUrl.isEmpty()) {
            call.reject("Server URL is not configured");
            return;
        }
        if (socket != null && connected) {
            call.resolve(buildStatus());
            return;
        }
        manualDisconnect = false;
        hideDisconnectedDialog();
        openSocket();
        call.resolve(buildStatus());
    }

    @PluginMethod
    public void disconnect(PluginCall call) {
        manualDisconnect = true;
        disconnectSocket(true);
        restoreOriginalContent();
        hideDisconnectedDialog();
        call.resolve(buildStatus());
    }

    @PluginMethod
    public void getStatus(PluginCall call) {
        call.resolve(buildStatus());
    }

    @PluginMethod
    public void reload(PluginCall call) {
        reloadWebView();
        call.resolve();
    }

    @PluginMethod
    public void reloadFile(PluginCall call) {
        reloadWebView();
        call.resolve();
    }

    private void openSocket() {
        manualDisconnect = false;
        hideDisconnectedDialog();
        String wsUrl = buildWebsocketUrl();
        if (wsUrl == null) {
            notifyListeners("reloadEvent", createEvent("error", null, "Unable to build WebSocket URL"));
            return;
        }

        Request.Builder requestBuilder = new Request.Builder().url(wsUrl);
        if (!headers.isEmpty()) {
            requestBuilder.headers(Headers.of(headers));
        }

        socket = client.newWebSocket(requestBuilder.build(), new LiveReloadListener());
    }

    private void disconnectSocket(boolean manual) {
        if (socket != null) {
            socket.close(1000, manual ? "manual" : "disconnect");
            socket = null;
        }
        setConnected(false);
        reconnectScheduled = false;
    }

    private void scheduleReconnect() {
        if (!autoReconnect || reconnectScheduled || serverUrl == null || manualDisconnect) {
            return;
        }
        reconnectScheduled = true;
        mainHandler.postDelayed(
            () -> {
                reconnectScheduled = false;
                if (!connected && !manualDisconnect) {
                    openSocket();
                }
            },
            reconnectIntervalMs
        );
    }

    private void setConnected(boolean isConnected) {
        if (connected == isConnected) {
            return;
        }
        connected = isConnected;
        if (connected) {
            hideDisconnectedDialog();
            switchToLiveReloadContent();
        }
        notifyStatus();
    }

    private void notifyStatus() {
        notifyListeners("statusChange", buildStatus());
    }

    private JSObject buildStatus() {
        JSObject status = new JSObject();
        status.put("connected", connected);
        if (serverUrl != null) {
            status.put("url", serverUrl);
        }
        return status;
    }

    private String buildWebsocketUrl() {
        if (serverUrl == null) {
            return null;
        }
        Uri uri = Uri.parse(serverUrl);
        String scheme = uri.getScheme();
        if (scheme == null) {
            return null;
        }
        String wsScheme = scheme.equals("https") ? "wss" : scheme.equals("http") ? "ws" : scheme;
        Uri.Builder builder = uri.buildUpon().scheme(wsScheme);
        if (websocketPath != null && !websocketPath.isEmpty()) {
            builder.encodedPath(websocketPath.startsWith("/") ? websocketPath : "/" + websocketPath);
        }
        return builder.build().toString();
    }

    private void reloadWebView() {
        WebView webView = getBridge().getWebView();
        if (webView == null) {
            return;
        }
        final WebView targetWebView = webView;
        final String targetUrl = usingLiveReload ? serverUrl : null;
        mainHandler.post(() -> {
            if (usingLiveReload && targetUrl != null) {
                targetWebView.loadUrl(targetUrl);
            } else {
                targetWebView.reload();
            }
        });
    }

    private JSObject createEvent(String type, @Nullable JSObject payload, @Nullable String message) {
        JSObject event = new JSObject();
        event.put("type", type);
        if (payload != null) {
            event.put("file", payload);
        }
        if (message != null) {
            event.put("message", message);
        }
        return event;
    }

    private final class LiveReloadListener extends WebSocketListener {

        @Override
        public void onOpen(WebSocket webSocket, Response response) {
            socket = webSocket;
            setConnected(true);
            notifyListeners("reloadEvent", createEvent("connected", null, "connected"));
        }

        @Override
        public void onMessage(WebSocket webSocket, String text) {
            handleMessage(text);
        }

        @Override
        public void onClosed(WebSocket webSocket, int code, String reason) {
            setConnected(false);
            notifyListeners("reloadEvent", createEvent("disconnected", null, reason));
            if (!manualDisconnect) {
                showDisconnectedDialog(reason);
                scheduleReconnect();
            }
        }

        @Override
        public void onFailure(WebSocket webSocket, Throwable t, Response response) {
            Log.e(TAG, "WebSocket failure", t);
            setConnected(false);
            String message = t.getMessage();
            notifyListeners("reloadEvent", createEvent("error", null, message));
            if (!manualDisconnect) {
                showDisconnectedDialog(message);
                scheduleReconnect();
            }
        }
    }

    private void handleMessage(String text) {
        JSONObject data = null;
        String type = "full-reload";
        try {
            data = new JSONObject(text);
            type = data.optString("type", type);
        } catch (JSONException ignore) {
            // plain text message, treat as full reload
        }

        switch (type) {
            case "file-update":
                JSObject filePayload = null;
                if (data != null) {
                    JSONObject nested = data.optJSONObject("file");
                    if (nested != null) {
                        filePayload = new JSObject();
                        for (Iterator<String> it = nested.keys(); it.hasNext(); ) {
                            String key = it.next();
                            filePayload.put(key, nested.opt(key));
                        }
                    } else if (data.has("path")) {
                        filePayload = new JSObject();
                        filePayload.put("path", data.optString("path"));
                        if (data.has("hash")) {
                            filePayload.put("hash", data.optString("hash"));
                        }
                    }
                }
                notifyListeners("reloadEvent", createEvent("file-update", filePayload, null));
                reloadWebView();
                break;
            case "full-reload":
            default:
                notifyListeners("reloadEvent", createEvent("full-reload", null, null));
                reloadWebView();
                break;
        }
    }

    private void captureInitialUrl() {
        if (initialUrl != null) {
            return;
        }
        WebView webView = getBridge().getWebView();
        if (webView == null) {
            return;
        }
        if (Looper.myLooper() == Looper.getMainLooper()) {
            if (initialUrl == null) {
                initialUrl = webView.getUrl();
            }
        } else {
            mainHandler.post(() -> {
                if (initialUrl == null) {
                    initialUrl = webView.getUrl();
                }
            });
        }
    }

    private void switchToLiveReloadContent() {
        if (serverUrl == null) {
            return;
        }
        WebView webView = getBridge().getWebView();
        if (webView == null) {
            return;
        }
        final WebView targetWebView = webView;
        final String targetUrl = serverUrl;
        mainHandler.post(() -> {
            if (initialUrl == null) {
                initialUrl = targetWebView.getUrl();
            }
            if (usingLiveReload) {
                targetWebView.reload();
            } else {
                usingLiveReload = true;
                targetWebView.loadUrl(targetUrl);
            }
        });
    }

    private void restoreOriginalContent() {
        WebView webView = getBridge().getWebView();
        if (webView == null) {
            usingLiveReload = false;
            return;
        }
        final WebView targetWebView = webView;
        mainHandler.post(() -> {
            usingLiveReload = false;
            String target = initialUrl;
            if (target == null) {
                target = getBridge().getServerUrl();
            }
            if (target != null) {
                targetWebView.loadUrl(target);
            } else {
                targetWebView.reload();
            }
        });
    }

    private void showDisconnectedDialog(@Nullable String reason) {
        if (manualDisconnect) {
            return;
        }
        Activity activity = getActivity();
        if (activity == null || disconnectDialog != null) {
            return;
        }
        final Activity currentActivity = activity;
        mainHandler.post(() -> {
            if (disconnectDialog != null || manualDisconnect) {
                return;
            }
            AlertDialog.Builder builder = new AlertDialog.Builder(currentActivity);
            builder.setTitle("Live Reload Disconnected");
            StringBuilder message = new StringBuilder("The connection to the live reload server was lost.");
            if (reason != null && !reason.isEmpty()) {
                message.append('\n').append('\n').append("Details: ").append(reason);
            }
            message.append('\n').append('\n').append("Close restores the original bundle. Reload tries to reconnect.");
            builder.setMessage(message.toString());
            builder.setCancelable(false);
            builder.setNegativeButton("Close", (dialog, which) -> {
                manualDisconnect = true;
                disconnectDialog = null;
                disconnectSocket(true);
                restoreOriginalContent();
            });
            builder.setPositiveButton("Reload", (dialog, which) -> {
                manualDisconnect = false;
                disconnectDialog = null;
                reloadWebView();
                openSocket();
            });
            builder.setOnDismissListener((dialog) -> disconnectDialog = null);
            disconnectDialog = builder.create();
            disconnectDialog.show();
        });
    }

    private void hideDisconnectedDialog() {
        AlertDialog dialog = disconnectDialog;
        if (dialog == null) {
            return;
        }
        mainHandler.post(() -> {
            AlertDialog current = disconnectDialog;
            if (current != null && current.isShowing()) {
                current.dismiss();
            }
            disconnectDialog = null;
        });
    }

    @PluginMethod
    public void getPluginVersion(final PluginCall call) {
        try {
            final JSObject ret = new JSObject();
            ret.put("version", this.pluginVersion);
            call.resolve(ret);
        } catch (final Exception e) {
            call.reject("Could not get plugin version", e);
        }
    }
}
