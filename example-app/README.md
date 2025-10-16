# Example App for `@capgo/capacitor-live-reload`

This Vite project links directly to the local plugin source so you can exercise live reload workflows while developing.

## Playground actions

- **Configure server** – Provide a dev server URL and optional WebSocket path.
- **Connect / disconnect** – Manage the WebSocket from the app.
- **Force reload** – Trigger a manual full reload of the webview.
- **Simulate file update** – Locally emulate an incoming file-update event.

## Getting started

```bash
npm install
npm start
```

Add native shells with `npx cap add ios` or `npx cap add android` from this folder to test on device or simulator.
