import { WebPlugin } from '@capacitor/core';

import type { PluginListenerHandle } from '@capacitor/core';

import type {
  ConfigureServerOptions,
  FileUpdatePayload,
  LiveReloadEventCallback,
  LiveReloadPlugin,
  LiveReloadStatus,
  LiveReloadStatusCallback,
} from './definitions';

export class LiveReloadWeb extends WebPlugin implements LiveReloadPlugin {
  private status: LiveReloadStatus = { connected: false };
  private socket?: WebSocket;

  async configureServer(options: ConfigureServerOptions): Promise<LiveReloadStatus> {
    this.status = { connected: this.status.connected, url: options.url };
    this.notifyStatus();
    return this.status;
  }

  async connect(): Promise<LiveReloadStatus> {
    if (this.status.url == null) {
      throw this.unimplemented('No server URL configured');
    }
    if (this.socket != null && this.status.connected) {
      return this.status;
    }
    this.socket = new WebSocket(this.status.url.replace(/^http/, 'ws'));
    this.socket.onopen = () => {
      this.status = { connected: true, url: this.status.url };
      this.notifyStatus();
    };
    this.socket.onclose = () => {
      this.status = { connected: false, url: this.status.url };
      this.notifyStatus();
    };
    this.socket.onmessage = (event) => {
      this.notifyListeners('reloadEvent', { type: 'full-reload', message: event.data });
    };
    return this.status;
  }

  async disconnect(): Promise<LiveReloadStatus> {
    this.socket?.close();
    this.socket = undefined;
    this.status = { connected: false, url: this.status.url };
    this.notifyStatus();
    return this.status;
  }

  async getStatus(): Promise<LiveReloadStatus> {
    return this.status;
  }

  async reload(): Promise<void> {
    window.location.reload();
  }

  async reloadFile(_options: FileUpdatePayload): Promise<void> {
    window.location.reload();
  }

  async addListener(eventName: 'reloadEvent', listenerFunc: LiveReloadEventCallback): Promise<PluginListenerHandle>;
  async addListener(eventName: 'statusChange', listenerFunc: LiveReloadStatusCallback): Promise<PluginListenerHandle>;
  async addListener(eventName: string, listenerFunc: LiveReloadEventCallback | LiveReloadStatusCallback): Promise<PluginListenerHandle> {
    return super.addListener(eventName, listenerFunc as (...args: any[]) => void);
  }

  async removeAllListeners(): Promise<void> {
    await super.removeAllListeners();
  }

  private notifyStatus() {
    this.notifyListeners('statusChange', this.status);
  }
}
