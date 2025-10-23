import type { PluginListenerHandle } from '@capacitor/core';

export type LiveReloadMessageType = 'full-reload' | 'file-update' | 'error' | 'connected' | 'disconnected';

export interface ConfigureServerOptions {
  /**
   * Base URL for the dev server (e.g. https://dev.local:5173).
   * When a connection is established the Capacitor WebView navigates to this URL.
   */
  url: string;
  /** Optional WebSocket path override when different from /ws. */
  websocketPath?: string;
  /** Extra headers sent when creating the WebSocket connection. */
  headers?: Record<string, string>;
  /** Automatically reconnect when the socket closes unexpectedly. Default: true. */
  autoReconnect?: boolean;
  /** Delay (ms) between reconnection attempts. Default: 2000. */
  reconnectInterval?: number;
}

export interface LiveReloadStatus {
  connected: boolean;
  url?: string;
}

export interface FileUpdatePayload {
  path: string;
  hash?: string;
}

export interface LiveReloadEventPayload {
  type: LiveReloadMessageType;
  /** Populated when type === 'file-update'. */
  file?: FileUpdatePayload;
  /** Optional human-readable message for errors or status changes. */
  message?: string;
}

export type LiveReloadStatusCallback = (status: LiveReloadStatus) => void;
export type LiveReloadEventCallback = (event: LiveReloadEventPayload) => void;

export interface LiveReloadPlugin {
  /**
   * Store remote dev server settings used for subsequent connections.
   */
  configureServer(options: ConfigureServerOptions): Promise<LiveReloadStatus>;
  /**
   * Establish a WebSocket connection if one is not already active.
   */
  connect(): Promise<LiveReloadStatus>;
  /**
   * Close the current WebSocket connection and disable auto reconnect.
   */
  disconnect(): Promise<LiveReloadStatus>;
  /**
   * Returns the current connection status.
   */
  getStatus(): Promise<LiveReloadStatus>;
  /**
   * Trigger a full reload of the Capacitor WebView.
   */
  reload(): Promise<void>;
  /**
   * Reload a single file/module if the runtime supports it (falls back to full reload).
   */
  reloadFile(options: FileUpdatePayload): Promise<void>;
  /**
   * Listen to incoming reload events emitted by the server.
   */
  addListener(eventName: 'reloadEvent', listenerFunc: LiveReloadEventCallback): Promise<PluginListenerHandle>;
  /**
   * Listen to socket status changes (connected/disconnected).
   */
  addListener(eventName: 'statusChange', listenerFunc: LiveReloadStatusCallback): Promise<PluginListenerHandle>;
  /** Remove all registered listeners. */
  removeAllListeners(): Promise<void>;

  /**
   * Get the native Capacitor plugin version
   *
   * @returns {Promise<{ id: string }>} an Promise with version for this device
   * @throws An error if the something went wrong
   */
  getPluginVersion(): Promise<{ version: string }>;
}
