import { registerPlugin } from '@capacitor/core';

import type { LiveReloadPlugin } from './definitions';

const LiveReload = registerPlugin<LiveReloadPlugin>('LiveReload', {
  web: () => import('./web').then((m) => new m.LiveReloadWeb()),
});

export * from './definitions';
export { LiveReload };
