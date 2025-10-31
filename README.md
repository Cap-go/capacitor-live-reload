# @capgo/capacitor-live-reload
 <a href="https://capgo.app/"><img src='https://raw.githubusercontent.com/Cap-go/capgo/main/assets/capgo_banner.png' alt='Capgo - Instant updates for capacitor'/></a>

<div align="center">
  <h2><a href="https://capgo.app/?ref=plugin_live_reload"> ➡️ Get Instant updates for your App with Capgo</a></h2>
  <h2><a href="https://capgo.app/consulting/?ref=plugin_live_reload"> Missing a feature? We’ll build the plugin for you 💪</a></h2>
</div>


WIP: Live reload your Capacitor app from a remote Vite (or compatible) dev server.

> **Note**
> Configure your Vite dev server to disable the built-in HMR client and forward reload events (e.g. JSON payloads `{ "type": "full-reload" }` or `{ "type": "file-update", "path": "..." }`) over a dedicated WebSocket endpoint such as `/capgo-livereload`.

## Documentation

The most complete doc is available here: https://capgo.app/docs/plugins/live-reload/

## Install

```bash
npm install @capgo/capacitor-live-reload
npx cap sync
```

```ts
import { LiveReload } from '@capgo/capacitor-live-reload';

await LiveReload.configureServer({
  url: 'http://localhost:5173',
  websocketPath: '/capgo-livereload',
});

await LiveReload.connect();

LiveReload.addListener('reloadEvent', (event) => {
  console.log('Live reload event', event);
});
```

## API

<docgen-index>

* [`configureServer(...)`](#configureserver)
* [`connect()`](#connect)
* [`disconnect()`](#disconnect)
* [`getStatus()`](#getstatus)
* [`reload()`](#reload)
* [`reloadFile(...)`](#reloadfile)
* [`addListener('reloadEvent', ...)`](#addlistenerreloadevent-)
* [`addListener('statusChange', ...)`](#addlistenerstatuschange-)
* [`removeAllListeners()`](#removealllisteners)
* [`getPluginVersion()`](#getpluginversion)
* [Interfaces](#interfaces)
* [Type Aliases](#type-aliases)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### configureServer(...)

```typescript
configureServer(options: ConfigureServerOptions) => Promise<LiveReloadStatus>
```

Store remote dev server settings used for subsequent connections.

| Param         | Type                                                                      |
| ------------- | ------------------------------------------------------------------------- |
| **`options`** | <code><a href="#configureserveroptions">ConfigureServerOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#livereloadstatus">LiveReloadStatus</a>&gt;</code>

--------------------


### connect()

```typescript
connect() => Promise<LiveReloadStatus>
```

Establish a WebSocket connection if one is not already active.

**Returns:** <code>Promise&lt;<a href="#livereloadstatus">LiveReloadStatus</a>&gt;</code>

--------------------


### disconnect()

```typescript
disconnect() => Promise<LiveReloadStatus>
```

Close the current WebSocket connection and disable auto reconnect.

**Returns:** <code>Promise&lt;<a href="#livereloadstatus">LiveReloadStatus</a>&gt;</code>

--------------------


### getStatus()

```typescript
getStatus() => Promise<LiveReloadStatus>
```

Returns the current connection status.

**Returns:** <code>Promise&lt;<a href="#livereloadstatus">LiveReloadStatus</a>&gt;</code>

--------------------


### reload()

```typescript
reload() => Promise<void>
```

Trigger a full reload of the Capacitor WebView.

--------------------


### reloadFile(...)

```typescript
reloadFile(options: FileUpdatePayload) => Promise<void>
```

Reload a single file/module if the runtime supports it (falls back to full reload).

| Param         | Type                                                            |
| ------------- | --------------------------------------------------------------- |
| **`options`** | <code><a href="#fileupdatepayload">FileUpdatePayload</a></code> |

--------------------


### addListener('reloadEvent', ...)

```typescript
addListener(eventName: 'reloadEvent', listenerFunc: LiveReloadEventCallback) => Promise<PluginListenerHandle>
```

Listen to incoming reload events emitted by the server.

| Param              | Type                                                                        |
| ------------------ | --------------------------------------------------------------------------- |
| **`eventName`**    | <code>'reloadEvent'</code>                                                  |
| **`listenerFunc`** | <code><a href="#livereloadeventcallback">LiveReloadEventCallback</a></code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('statusChange', ...)

```typescript
addListener(eventName: 'statusChange', listenerFunc: LiveReloadStatusCallback) => Promise<PluginListenerHandle>
```

Listen to socket status changes (connected/disconnected).

| Param              | Type                                                                          |
| ------------------ | ----------------------------------------------------------------------------- |
| **`eventName`**    | <code>'statusChange'</code>                                                   |
| **`listenerFunc`** | <code><a href="#livereloadstatuscallback">LiveReloadStatusCallback</a></code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### removeAllListeners()

```typescript
removeAllListeners() => Promise<void>
```

Remove all registered listeners.

--------------------


### getPluginVersion()

```typescript
getPluginVersion() => Promise<{ version: string; }>
```

Get the native Capacitor plugin version

**Returns:** <code>Promise&lt;{ version: string; }&gt;</code>

--------------------


### Interfaces


#### LiveReloadStatus

| Prop            | Type                 |
| --------------- | -------------------- |
| **`connected`** | <code>boolean</code> |
| **`url`**       | <code>string</code>  |


#### ConfigureServerOptions

| Prop                    | Type                                                            | Description                                                                                                                              |
| ----------------------- | --------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| **`url`**               | <code>string</code>                                             | Base URL for the dev server (e.g. https://dev.local:5173). When a connection is established the Capacitor WebView navigates to this URL. |
| **`websocketPath`**     | <code>string</code>                                             | Optional WebSocket path override when different from /ws.                                                                                |
| **`headers`**           | <code><a href="#record">Record</a>&lt;string, string&gt;</code> | Extra headers sent when creating the WebSocket connection.                                                                               |
| **`autoReconnect`**     | <code>boolean</code>                                            | Automatically reconnect when the socket closes unexpectedly. Default: true.                                                              |
| **`reconnectInterval`** | <code>number</code>                                             | Delay (ms) between reconnection attempts. Default: 2000.                                                                                 |


#### FileUpdatePayload

| Prop       | Type                |
| ---------- | ------------------- |
| **`path`** | <code>string</code> |
| **`hash`** | <code>string</code> |


#### PluginListenerHandle

| Prop         | Type                                      |
| ------------ | ----------------------------------------- |
| **`remove`** | <code>() =&gt; Promise&lt;void&gt;</code> |


#### LiveReloadEventPayload

| Prop          | Type                                                                    | Description                                                   |
| ------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------- |
| **`type`**    | <code><a href="#livereloadmessagetype">LiveReloadMessageType</a></code> |                                                               |
| **`file`**    | <code><a href="#fileupdatepayload">FileUpdatePayload</a></code>         | Populated when type === 'file-update'.                        |
| **`message`** | <code>string</code>                                                     | Optional human-readable message for errors or status changes. |


### Type Aliases


#### Record

Construct a type with a set of properties K of type T

<code>{ [P in K]: T; }</code>


#### LiveReloadEventCallback

<code>(event: <a href="#livereloadeventpayload">LiveReloadEventPayload</a>): void</code>


#### LiveReloadMessageType

<code>'full-reload' | 'file-update' | 'error' | 'connected' | 'disconnected'</code>


#### LiveReloadStatusCallback

<code>(status: <a href="#livereloadstatus">LiveReloadStatus</a>): void</code>

</docgen-api>
