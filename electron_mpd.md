# Remote Playback via MPD in an Electron App

A complete implementation guide for adding remote MPD (Music Player Daemon) playback to an Electron + React application. This documents the pattern used in NoisePort and can be adapted to any Electron project.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Layer 1: Main Process Service](#layer-1-main-process-service)
3. [Layer 2: IPC Handlers](#layer-2-ipc-handlers)
4. [Layer 3: Preload / Context Bridge](#layer-3-preload--context-bridge)
5. [Layer 4: Renderer Hooks](#layer-4-renderer-hooks)
6. [Layer 5: Queue Synchronization](#layer-5-queue-synchronization)
7. [Layer 6: UI Components](#layer-6-ui-components)
8. [Layer 7: Settings & Store](#layer-7-settings--store)
9. [IPC Channel Reference](#ipc-channel-reference)
10. [Data Flow Diagram](#data-flow-diagram)
11. [Design Patterns & Decisions](#design-patterns--decisions)
12. [MPD Server Setup](#mpd-server-setup)

---

## Architecture Overview

The implementation follows Electron's process isolation model across 4 layers:

```
Remote MPD Server  <──TCP──>  Main Process  <──IPC──>  Preload Bridge  <──API──>  Renderer (React)
     (mpc-js)                (Service +               (contextBridge)             (Hooks + UI)
                              IPC handlers)
```

**File structure:**

```
src/
├── main/features/playback/
│   ├── types.ts                   # Interfaces & enums
│   ├── mpd-playback-service.ts    # TCP client wrapping mpc-js
│   ├── mpd-ipc-handlers.ts        # ipcMain handlers
│   └── index.ts                   # Registration entry point
├── preload/
│   ├── mpd-player.ts              # contextBridge API
│   └── index.ts                   # Aggregate all preload modules
├── renderer/
│   ├── hooks/
│   │   ├── use-mpd-playback.ts    # Command orchestration (store → MPD)
│   │   ├── use-mpd-status-sync.ts # Status sync (MPD → store)
│   │   └── use-mpd-connection.ts  # Connection state for UI
│   ├── features/player/
│   │   ├── mpd-queue-sync.ts      # Queue format conversion + URL building
│   │   └── components/
│   │       ├── playback-output-selector.tsx
│   │       └── playback-output-indicator.tsx
│   └── store/
│       ├── player.store.ts        # Playback state (Zustand)
│       └── settings.store.ts      # MPD config persistence
└── shared/types/
    └── types.ts                   # PlaybackType enum
```

**Dependency:** `mpc-js` (MPD client for Node.js, TCP-based).

```bash
pnpm add mpc-js
```

---

## Layer 1: Main Process Service

**File:** `src/main/features/playback/types.ts`

Define the interface that any playback backend must implement:

```typescript
export enum PlaybackState {
  PLAYING = 'playing',
  PAUSED = 'paused',
  STOPPED = 'stopped',
}

export interface PlaybackStatus {
  state: PlaybackState;
  position: number;    // seconds
  duration: number;    // seconds
  volume: number;      // 0-100
  currentTrackUri?: string;
  currentIndex?: number;
}

export interface QueueItem {
  id: string;          // Your app's unique ID for this queue entry
  uri: string;         // Playable HTTP URL
  duration?: number;
  metadata?: {
    title?: string;
    artist?: string;
    album?: string;
  };
}

export type PlaybackEventType =
  | 'status' | 'play' | 'pause' | 'stop'
  | 'next' | 'previous' | 'seek' | 'volume'
  | 'queue' | 'error' | 'connected' | 'disconnected';

export interface PlaybackEvent {
  type: PlaybackEventType;
  data?: any;
}

export type PlaybackEventCallback = (event: PlaybackEvent) => void;

export interface IPlaybackService {
  connect(): Promise<void>;
  disconnect(): Promise<void>;
  isConnected(): boolean;
  play(): Promise<void>;
  pause(): Promise<void>;
  stop(): Promise<void>;
  next(): Promise<void>;
  previous(): Promise<void>;
  seek(seconds: number): Promise<void>;
  setVolume(volume: number): Promise<void>;
  setQueue(items: QueueItem[], startIndex?: number): Promise<void>;
  addToQueue(items: QueueItem[]): Promise<void>;
  getStatus(): Promise<PlaybackStatus>;
  subscribe(callback: PlaybackEventCallback): () => void; // returns unsubscribe
}
```

---

**File:** `src/main/features/playback/mpd-playback-service.ts`

The core service. Key responsibilities:
- Manage TCP connection to MPD via `mpc-js`
- Poll status on an interval (MPD has no push for position updates)
- Map MPD queue indices to your app's queue item IDs
- Auto-reconnect with exponential backoff
- Emit events to subscribers

```typescript
import { MPC } from 'mpc-js';
import {
  IPlaybackService, PlaybackState, PlaybackStatus,
  QueueItem, PlaybackEvent, PlaybackEventCallback,
} from './types';

interface MpdConfig {
  host: string;
  port: number;
  password?: string;
}

export class MpdPlaybackService implements IPlaybackService {
  private client: MPC | null = null;
  private config: MpdConfig;
  private connected = false;
  private subscribers: PlaybackEventCallback[] = [];
  private statusPollInterval: NodeJS.Timeout | null = null;
  private queueMapping: Record<number, string> = {}; // mpdIndex → appItemId
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 10;

  constructor(config: MpdConfig) {
    this.config = config;
  }

  // ── Connection ──────────────────────────────────────────

  async connect(): Promise<void> {
    this.client = new MPC();

    this.client.on('ready', async () => {
      this.connected = true;
      this.reconnectAttempts = 0;

      if (this.config.password) {
        try {
          // mpc-js: send password command
          await this.client!.sendCommand('password', [this.config.password!]);
        } catch (err) {
          this.emit({ type: 'error', data: { message: 'Authentication failed' } });
          return;
        }
      }

      this.startStatusPolling();
      this.emit({ type: 'connected' });
    });

    this.client.on('socket-error', (err: Error) => {
      this.connected = false;
      this.emit({ type: 'error', data: { message: err.message } });
      this.scheduleReconnect();
    });

    this.client.on('socket-end', () => {
      this.connected = false;
      this.emit({ type: 'disconnected' });
      this.scheduleReconnect();
    });

    await this.client.connectTCP(this.config.host, this.config.port);
  }

  async disconnect(): Promise<void> {
    this.stopStatusPolling();
    if (this.client) {
      this.client.disconnect();
      this.client = null;
    }
    this.connected = false;
    this.subscribers = [];
    this.emit({ type: 'disconnected' });
  }

  isConnected(): boolean {
    return this.connected;
  }

  // ── Reconnection (exponential backoff) ──────────────────

  private scheduleReconnect(): void {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) return;

    const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000);
    this.reconnectAttempts++;

    setTimeout(async () => {
      try {
        await this.connect();
      } catch {
        // Will trigger socket-error → scheduleReconnect again
      }
    }, delay);
  }

  // ── Status Polling ──────────────────────────────────────

  private startStatusPolling(): void {
    this.stopStatusPolling();
    this.statusPollInterval = setInterval(async () => {
      try {
        const status = await this.getStatus();
        this.emit({ type: 'status', data: status });
      } catch {
        // Swallow; socket-error handler deals with disconnection
      }
    }, 1500); // 1.5 second interval
  }

  private stopStatusPolling(): void {
    if (this.statusPollInterval) {
      clearInterval(this.statusPollInterval);
      this.statusPollInterval = null;
    }
  }

  // ── Playback Commands ───────────────────────────────────

  async play(): Promise<void> {
    if (!this.client) return;
    await this.client.playback.play();
    this.emit({ type: 'play' });
  }

  async pause(): Promise<void> {
    if (!this.client) return;
    await this.client.playback.pause();
    this.emit({ type: 'pause' });
  }

  async stop(): Promise<void> {
    if (!this.client) return;
    await this.client.playback.stop();
    this.emit({ type: 'stop' });
  }

  async next(): Promise<void> {
    if (!this.client) return;
    await this.client.playback.next();
    this.emit({ type: 'next' });
  }

  async previous(): Promise<void> {
    if (!this.client) return;
    await this.client.playback.previous();
    this.emit({ type: 'previous' });
  }

  async seek(seconds: number): Promise<void> {
    if (!this.client) return;
    await this.client.playback.seekCur(seconds);
    this.emit({ type: 'seek', data: seconds });
  }

  async setVolume(volume: number): Promise<void> {
    if (!this.client) return;
    const clamped = Math.max(0, Math.min(100, Math.round(volume)));
    await this.client.playbackOptions.setVolume(clamped);
    this.emit({ type: 'volume', data: clamped });
  }

  // ── Queue Management ────────────────────────────────────

  async setQueue(items: QueueItem[], startIndex = 0): Promise<void> {
    if (!this.client) return;

    // Clear existing MPD queue
    await this.client.currentPlaylist.clear();
    this.queueMapping = {};

    // Add each item by URI
    for (let i = 0; i < items.length; i++) {
      await this.client.currentPlaylist.add(items[i].uri);
      this.queueMapping[i] = items[i].id;
    }

    // Start playback at requested index
    if (items.length > 0) {
      await this.client.playback.play(startIndex);
    }

    this.emit({ type: 'queue', data: { items, startIndex } });
  }

  async addToQueue(items: QueueItem[]): Promise<void> {
    if (!this.client) return;

    const currentSize = Object.keys(this.queueMapping).length;
    for (let i = 0; i < items.length; i++) {
      await this.client.currentPlaylist.add(items[i].uri);
      this.queueMapping[currentSize + i] = items[i].id;
    }

    this.emit({ type: 'queue', data: { added: items } });
  }

  // ── Status Query ────────────────────────────────────────

  async getStatus(): Promise<PlaybackStatus> {
    if (!this.client) {
      return {
        state: PlaybackState.STOPPED,
        position: 0, duration: 0, volume: 0,
      };
    }

    const response = await this.client.status.status();
    const parsed = this.parseResponse(response);

    return {
      state: this.mapState(parsed.state),
      position: parseFloat(parsed.elapsed || '0'),
      duration: parseFloat(parsed.duration || '0'),
      volume: parseInt(parsed.volume || '0', 10),
      currentTrackUri: parsed.file,
      currentIndex: parsed.song !== undefined ? parseInt(parsed.song, 10) : undefined,
    };
  }

  // ── Event System ────────────────────────────────────────

  subscribe(callback: PlaybackEventCallback): () => void {
    this.subscribers.push(callback);
    return () => {
      this.subscribers = this.subscribers.filter((s) => s !== callback);
    };
  }

  private emit(event: PlaybackEvent): void {
    this.subscribers.forEach((cb) => cb(event));
  }

  // ── Helpers ─────────────────────────────────────────────

  private mapState(state: string | undefined): PlaybackState {
    switch (state) {
      case 'play': return PlaybackState.PLAYING;
      case 'pause': return PlaybackState.PAUSED;
      default: return PlaybackState.STOPPED;
    }
  }

  private parseResponse(response: any): Record<string, string> {
    // mpc-js returns objects or raw strings depending on version
    if (typeof response === 'object' && response !== null) {
      return response;
    }
    const result: Record<string, string> = {};
    String(response).split('\n').forEach((line: string) => {
      const idx = line.indexOf(':');
      if (idx > 0) {
        result[line.slice(0, idx).trim().toLowerCase()] = line.slice(idx + 1).trim();
      }
    });
    return result;
  }
}
```

---

## Layer 2: IPC Handlers

**File:** `src/main/features/playback/mpd-ipc-handlers.ts`

Bridges main process service to renderer. Maintains a single global service instance.

```typescript
import { BrowserWindow, ipcMain } from 'electron';
import { MpdPlaybackService } from './mpd-playback-service';

let mpdService: MpdPlaybackService | null = null;

export function initializeMpdHandlers(): void {
  // ── Connection ─────────────────────────────────────────

  ipcMain.handle('mpd-connect', async (_event, config) => {
    try {
      if (mpdService) await mpdService.disconnect();
      mpdService = new MpdPlaybackService(config);

      // Forward service events to renderer
      mpdService.subscribe((event) => {
        const win = BrowserWindow.getAllWindows()[0];
        if (!win) return;
        win.webContents.send(`renderer-mpd-${event.type}`, event.data);
      });

      await mpdService.connect();
      return { success: true };
    } catch (err: any) {
      return { success: false, error: err.message };
    }
  });

  ipcMain.handle('mpd-disconnect', async () => {
    try {
      if (mpdService) {
        await mpdService.disconnect();
        mpdService = null;
      }
      return { success: true };
    } catch (err: any) {
      return { success: false, error: err.message };
    }
  });

  ipcMain.handle('mpd-is-connected', () => {
    return mpdService?.isConnected() ?? false;
  });

  ipcMain.handle('mpd-test-connection', async (_event, config) => {
    const testService = new MpdPlaybackService(config);
    try {
      await testService.connect();
      const status = await testService.getStatus();
      await testService.disconnect();
      return { success: true, status };
    } catch (err: any) {
      try { await testService.disconnect(); } catch { /* ignore */ }
      return { success: false, error: err.message };
    }
  });

  // ── Playback Commands (fire-and-forget via ipcMain.on) ─

  ipcMain.on('mpd-play', () => mpdService?.play());
  ipcMain.on('mpd-pause', () => mpdService?.pause());
  ipcMain.on('mpd-stop', () => mpdService?.stop());
  ipcMain.on('mpd-next', () => mpdService?.next());
  ipcMain.on('mpd-previous', () => mpdService?.previous());
  ipcMain.on('mpd-seek', (_e, seconds) => mpdService?.seek(seconds));
  ipcMain.on('mpd-set-volume', (_e, volume) => mpdService?.setVolume(volume));

  // ── Queue Commands (fire-and-forget) ───────────────────

  ipcMain.on('mpd-set-queue', (_e, items, startIndex) => {
    mpdService?.setQueue(items, startIndex);
  });

  ipcMain.on('mpd-add-to-queue', (_e, items) => {
    mpdService?.addToQueue(items);
  });

  ipcMain.on('mpd-clear-queue', () => {
    // Clear is done inside setQueue; standalone clear:
    mpdService?.setQueue([]);
  });

  // ── Status Query ───────────────────────────────────────

  ipcMain.handle('mpd-get-status', async () => {
    return mpdService?.getStatus() ?? null;
  });
}
```

**File:** `src/main/features/playback/index.ts`

```typescript
import { initializeMpdHandlers } from './mpd-ipc-handlers';

export function initializePlayback(): void {
  initializeMpdHandlers();
}
```

Call `initializePlayback()` from your main process entry point (`src/main/index.ts`), after `app.whenReady()`.

---

## Layer 3: Preload / Context Bridge

**File:** `src/preload/mpd-player.ts`

Exposes a safe, typed API to the renderer via `contextBridge`.

```typescript
import { ipcRenderer } from 'electron';

// ── Types (duplicated here to avoid importing from main) ─

export interface MpdConnectionConfig {
  host: string;
  port: number;
  password?: string;
}

export interface MpdStatus {
  state: 'playing' | 'paused' | 'stopped';
  position: number;
  duration: number;
  volume: number;
  currentTrackUri?: string;
  currentIndex?: number;
}

export interface MpdQueueItem {
  id: string;
  uri: string;
  duration?: number;
  metadata?: { title?: string; artist?: string; album?: string };
}

// ── Command API ──────────────────────────────────────────

export const mpdPlayer = {
  // Async (request-response)
  connect: (config: MpdConnectionConfig) =>
    ipcRenderer.invoke('mpd-connect', config),
  disconnect: () =>
    ipcRenderer.invoke('mpd-disconnect'),
  isConnected: () =>
    ipcRenderer.invoke('mpd-is-connected') as Promise<boolean>,
  getStatus: () =>
    ipcRenderer.invoke('mpd-get-status') as Promise<MpdStatus | null>,
  testConnection: (config: MpdConnectionConfig) =>
    ipcRenderer.invoke('mpd-test-connection', config),

  // Fire-and-forget (no response)
  play: () => ipcRenderer.send('mpd-play'),
  pause: () => ipcRenderer.send('mpd-pause'),
  stop: () => ipcRenderer.send('mpd-stop'),
  next: () => ipcRenderer.send('mpd-next'),
  previous: () => ipcRenderer.send('mpd-previous'),
  seek: (seconds: number) => ipcRenderer.send('mpd-seek', seconds),
  setVolume: (volume: number) => ipcRenderer.send('mpd-set-volume', volume),
  setQueue: (items: MpdQueueItem[], startIndex?: number) =>
    ipcRenderer.send('mpd-set-queue', items, startIndex),
  addToQueue: (items: MpdQueueItem[]) =>
    ipcRenderer.send('mpd-add-to-queue', items),
  clearQueue: () => ipcRenderer.send('mpd-clear-queue'),
};

// ── Event Listener API ───────────────────────────────────

export const mpdPlayerListener = {
  onStatusUpdate: (cb: (_event: any, status: MpdStatus) => void) =>
    ipcRenderer.on('renderer-mpd-status', cb),
  onPlay: (cb: (_event: any) => void) =>
    ipcRenderer.on('renderer-mpd-play', cb),
  onPause: (cb: (_event: any) => void) =>
    ipcRenderer.on('renderer-mpd-pause', cb),
  onStop: (cb: (_event: any) => void) =>
    ipcRenderer.on('renderer-mpd-stop', cb),
  onNext: (cb: (_event: any) => void) =>
    ipcRenderer.on('renderer-mpd-next', cb),
  onPrevious: (cb: (_event: any) => void) =>
    ipcRenderer.on('renderer-mpd-previous', cb),
  onSeek: (cb: (_event: any, position: number) => void) =>
    ipcRenderer.on('renderer-mpd-seek', cb),
  onVolume: (cb: (_event: any, volume: number) => void) =>
    ipcRenderer.on('renderer-mpd-volume', cb),
  onConnected: (cb: (_event: any) => void) =>
    ipcRenderer.on('renderer-mpd-connected', cb),
  onDisconnected: (cb: (_event: any) => void) =>
    ipcRenderer.on('renderer-mpd-disconnected', cb),
  onError: (cb: (_event: any, error: any) => void) =>
    ipcRenderer.on('renderer-mpd-error', cb),
  onQueueUpdate: (cb: (_event: any, data: any) => void) =>
    ipcRenderer.on('renderer-mpd-queue', cb),
};
```

**In `src/preload/index.ts`**, add to the API object:

```typescript
import { contextBridge } from 'electron';
import { mpdPlayer, mpdPlayerListener } from './mpd-player';

const api = {
  // ...existing APIs...
  mpdPlayer,
  mpdPlayerListener,
};

contextBridge.exposeInMainWorld('api', api);
```

**TypeScript declaration** (so the renderer can see `window.api.mpdPlayer`):

```typescript
// src/preload/types.d.ts or augment your existing Window interface
import type { mpdPlayer, mpdPlayerListener } from './mpd-player';

declare global {
  interface Window {
    api: {
      mpdPlayer: typeof mpdPlayer;
      mpdPlayerListener: typeof mpdPlayerListener;
      // ...other APIs...
    };
  }
}
```

---

## Layer 4: Renderer Hooks

Three hooks, each with a single responsibility.

### Hook 1: `use-mpd-playback.ts` -- Command Orchestration

Watches your player store and sends commands to MPD when state changes.

```typescript
import { useEffect, useRef } from 'react';
import { usePlayerStore } from '../store/player.store';
import { useSettingsStore } from '../store/settings.store';
import { convertToMpdQueue } from '../features/player/mpd-queue-sync';

const mpdPlayer = window.api?.mpdPlayer;

export function useMpdPlayback() {
  const isMpdMode = useSettingsStore((s) => s.playback.type === 'remote_mpd');
  const mpdConfig = useSettingsStore((s) => s.playback.remoteTargets?.mpd);
  const status = usePlayerStore((s) => s.status);
  const volume = usePlayerStore((s) => s.volume);
  const queue = usePlayerStore((s) => s.queue);
  const currentIndex = usePlayerStore((s) => s.currentIndex);

  const isConnectedRef = useRef(false);
  const queueSyncedRef = useRef(false);
  const prevStatusRef = useRef(status);
  const prevIndexRef = useRef(currentIndex);

  // Effect 1: Connect / disconnect
  useEffect(() => {
    if (!mpdPlayer || !isMpdMode || !mpdConfig?.enabled) {
      if (isConnectedRef.current) {
        mpdPlayer?.disconnect();
        isConnectedRef.current = false;
      }
      return;
    }

    (async () => {
      const alreadyConnected = await mpdPlayer.isConnected();
      if (alreadyConnected) {
        isConnectedRef.current = true;
        return;
      }
      const result = await mpdPlayer.connect({
        host: mpdConfig.host,
        port: mpdConfig.port,
        password: mpdConfig.password || undefined,
      });
      isConnectedRef.current = result.success;
      queueSyncedRef.current = false;
    })();

    return () => {
      mpdPlayer.disconnect();
      isConnectedRef.current = false;
    };
  }, [isMpdMode, mpdConfig?.enabled, mpdConfig?.host, mpdConfig?.port, mpdConfig?.password]);

  // Effect 2: Queue sync
  useEffect(() => {
    if (!mpdPlayer || !isMpdMode || !isConnectedRef.current) return;
    if (queue.length === 0) return;

    const mpdQueue = convertToMpdQueue(queue);
    mpdPlayer.setQueue(mpdQueue, currentIndex);
    queueSyncedRef.current = true;
  }, [isMpdMode, queue.length]); // Trigger on queue changes

  // Effect 3: Play / pause
  useEffect(() => {
    if (!mpdPlayer || !isMpdMode) return;
    const prev = prevStatusRef.current;
    prevStatusRef.current = status;
    if (prev === status) return;

    if (status === 'playing') mpdPlayer.play();
    else if (status === 'paused') mpdPlayer.pause();
  }, [status, isMpdMode]);

  // Effect 4: Volume
  useEffect(() => {
    if (!mpdPlayer || !isMpdMode) return;
    mpdPlayer.setVolume(volume);
  }, [volume, isMpdMode]);

  // Effect 5: Track navigation (next / previous / jump)
  useEffect(() => {
    if (!mpdPlayer || !isMpdMode || !queueSyncedRef.current) return;
    const prev = prevIndexRef.current;
    prevIndexRef.current = currentIndex;
    if (prev === currentIndex) return;

    const diff = currentIndex - prev;
    if (diff === 1) {
      mpdPlayer.next();
    } else if (diff === -1) {
      mpdPlayer.previous();
    } else {
      // Jump: resync queue at new position
      const mpdQueue = convertToMpdQueue(queue);
      mpdPlayer.setQueue(mpdQueue, currentIndex);
    }
  }, [currentIndex, isMpdMode]);
}
```

### Hook 2: `use-mpd-status-sync.ts` -- Status Updates (MPD -> Store)

Listens for MPD status events and updates your player store.

```typescript
import { useEffect } from 'react';
import { usePlayerStore } from '../store/player.store';
import { useSettingsStore } from '../store/settings.store';

const mpdPlayerListener = window.api?.mpdPlayerListener;

export function useMpdStatusSync() {
  const isMpdMode = useSettingsStore((s) => s.playback.type === 'remote_mpd');
  const setCurrentTime = usePlayerStore((s) => s.actions.setCurrentTime);

  useEffect(() => {
    if (!mpdPlayerListener || !isMpdMode) return;

    mpdPlayerListener.onStatusUpdate((_event, status) => {
      // Sync playback position from MPD → player store
      setCurrentTime(status.position);
    });

    // Note: mpc-js ipcRenderer.on doesn't return a removeListener handle.
    // If your IPC wrapper supports cleanup, return it here.
  }, [isMpdMode, setCurrentTime]);
}
```

### Hook 3: `use-mpd-connection.ts` -- Connection State for UI

```typescript
import { useEffect, useState } from 'react';
import { useSettingsStore } from '../store/settings.store';

type MpdConnectionStatus = 'connected' | 'disconnected' | 'connecting' | 'error';

const mpdPlayerListener = window.api?.mpdPlayerListener;

export function useMpdConnection() {
  const isMpdMode = useSettingsStore((s) => s.playback.type === 'remote_mpd');
  const [status, setStatus] = useState<MpdConnectionStatus>('disconnected');
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!mpdPlayerListener || !isMpdMode) {
      setStatus('disconnected');
      return;
    }

    setStatus('connecting');

    mpdPlayerListener.onConnected(() => {
      setStatus('connected');
      setError(null);
    });

    mpdPlayerListener.onDisconnected(() => {
      setStatus('disconnected');
    });

    mpdPlayerListener.onError((_event, err) => {
      setStatus('error');
      setError(err?.message || 'Unknown error');
    });
  }, [isMpdMode]);

  return {
    status,
    isConnected: status === 'connected',
    isError: status === 'error',
    error,
  };
}
```

**Mount all three hooks** in your top-level `App.tsx`:

```tsx
function App() {
  useMpdPlayback();
  useMpdStatusSync();
  // useMpdConnection() is called inside UI components that need it

  return <>{/* your app */}</>;
}
```

---

## Layer 5: Queue Synchronization

**File:** `src/renderer/features/player/mpd-queue-sync.ts`

Converts your app's queue format into MPD-compatible items with playable HTTP URLs.

```typescript
interface MpdQueueItem {
  id: string;
  uri: string;
  duration?: number;
  metadata?: { title?: string; artist?: string; album?: string };
}

// Adapt this to your app's song type
interface QueueSong {
  uniqueId: string;
  streamUrl: string;      // HTTP URL the server provides
  duration?: number;
  name?: string;
  artistName?: string;
  albumName?: string;
}

/**
 * Build a stream URL for a given song.
 * If you use transcoding, apply it here.
 * If your server requires auth tokens in the URL, add them here.
 */
export function buildStreamUrl(song: QueueSong): string {
  // Example: Subsonic-style URLs already have auth params
  return song.streamUrl;
}

/**
 * Convert your app queue to MPD queue format.
 */
export function convertToMpdQueue(songs: QueueSong[]): MpdQueueItem[] {
  return songs.map((song) => ({
    id: song.uniqueId,
    uri: buildStreamUrl(song),
    duration: song.duration,
    metadata: {
      title: song.name,
      artist: song.artistName,
      album: song.albumName,
    },
  }));
}
```

---

## Layer 6: UI Components

### Playback Output Selector (dropdown to switch modes)

```tsx
import { Menu, ActionIcon } from '@mantine/core';
import { IconSpeaker, IconWifi } from './icons';
import { useMpdConnection } from '../../hooks/use-mpd-connection';
import { useSettingsStore } from '../../store/settings.store';

export function PlaybackOutputSelector() {
  const settings = useSettingsStore((s) => s.playback);
  const setSettings = useSettingsStore((s) => s.setPlaybackSettings);
  const mpdEnabled = settings.remoteTargets?.mpd?.enabled;
  const { isConnected, status } = useMpdConnection();

  const handleSelect = (type: 'local' | 'remote_mpd') => {
    setSettings({ ...settings, type });
  };

  return (
    <Menu>
      <Menu.Target>
        <ActionIcon>
          <IconSpeaker />
        </ActionIcon>
      </Menu.Target>
      <Menu.Dropdown>
        <Menu.Item onClick={() => handleSelect('local')}>
          Local (MPV)
        </Menu.Item>
        {mpdEnabled && (
          <Menu.Item onClick={() => handleSelect('remote_mpd')}>
            Remote MPD {isConnected ? '(Connected)' : `(${status})`}
          </Menu.Item>
        )}
      </Menu.Dropdown>
    </Menu>
  );
}
```

### Playback Output Indicator (status badge in player bar)

```tsx
import { Badge, Tooltip } from '@mantine/core';
import { useMpdConnection } from '../../hooks/use-mpd-connection';
import { useSettingsStore } from '../../store/settings.store';

export function PlaybackOutputIndicator() {
  const isMpdMode = useSettingsStore((s) => s.playback.type === 'remote_mpd');
  const mpdHost = useSettingsStore((s) => s.playback.remoteTargets?.mpd?.host);
  const { status, isConnected, error } = useMpdConnection();

  if (!isMpdMode) return null;

  const color = isConnected ? 'green' : status === 'error' ? 'red' : 'yellow';
  const label = isConnected ? 'MPD' : status === 'error' ? 'MPD Error' : 'Connecting...';
  const tooltip = isConnected
    ? `Connected to ${mpdHost}`
    : error || 'Connecting to MPD...';

  return (
    <Tooltip label={tooltip}>
      <Badge color={color} variant="dot" size="sm">
        {label}
      </Badge>
    </Tooltip>
  );
}
```

### Settings Form (MPD connection config)

```tsx
import { useState } from 'react';
import { TextInput, NumberInput, PasswordInput, Switch, Button } from '@mantine/core';
import { useSettingsStore } from '../../store/settings.store';

export function RemoteTargetsSettings() {
  const settings = useSettingsStore((s) => s.playback);
  const setSettings = useSettingsStore((s) => s.setPlaybackSettings);
  const mpdConfig = settings.remoteTargets?.mpd;
  const [testResult, setTestResult] = useState<string | null>(null);

  const updateMpd = (patch: Partial<typeof mpdConfig>) => {
    setSettings({
      ...settings,
      remoteTargets: {
        ...settings.remoteTargets,
        mpd: { ...mpdConfig!, ...patch },
      },
    });
  };

  const handleTestConnection = async () => {
    if (!mpdConfig?.host) return;
    setTestResult('Testing...');
    const result = await window.api.mpdPlayer.testConnection({
      host: mpdConfig.host,
      port: mpdConfig.port || 6600,
      password: mpdConfig.password || undefined,
    });
    setTestResult(result.success ? 'Connected!' : `Error: ${result.error}`);
  };

  return (
    <div>
      <Switch
        label="Enable MPD Remote"
        checked={mpdConfig?.enabled ?? false}
        onChange={(e) => updateMpd({ enabled: e.currentTarget.checked })}
      />

      {mpdConfig?.enabled && (
        <>
          <TextInput
            label="MPD Host"
            placeholder="192.168.1.100"
            value={mpdConfig.host || ''}
            onChange={(e) => updateMpd({ host: e.currentTarget.value })}
          />
          <NumberInput
            label="MPD Port"
            value={mpdConfig.port || 6600}
            min={1} max={65535}
            onChange={(val) => updateMpd({ port: val as number })}
          />
          <PasswordInput
            label="MPD Password (optional)"
            value={mpdConfig.password || ''}
            onChange={(e) => updateMpd({ password: e.currentTarget.value })}
          />
          <Button onClick={handleTestConnection}>Test Connection</Button>
          {testResult && <p>{testResult}</p>}
        </>
      )}
    </div>
  );
}
```

---

## Layer 7: Settings & Store

Add MPD config to your settings store (Zustand example):

```typescript
// In your settings store
interface PlaybackSettings {
  type: 'local' | 'web' | 'remote_mpd';
  remoteTargets: {
    mpd: {
      enabled: boolean;
      host: string;
      port: number;
      password: string;
    };
  };
  // ...other settings
}

// Add PlaybackType enum to shared types
enum PlaybackType {
  LOCAL = 'local',
  WEB = 'web',
  REMOTE_MPD = 'remote_mpd',
}
```

---

## IPC Channel Reference

| Direction | Channel | Method | Purpose |
|---|---|---|---|
| Renderer -> Main | `mpd-connect` | `invoke` | Connect with config, returns `{success, error?}` |
| Renderer -> Main | `mpd-disconnect` | `invoke` | Disconnect, returns `{success}` |
| Renderer -> Main | `mpd-is-connected` | `invoke` | Returns `boolean` |
| Renderer -> Main | `mpd-test-connection` | `invoke` | Test without persisting, returns `{success, error?}` |
| Renderer -> Main | `mpd-get-status` | `invoke` | Returns `PlaybackStatus` |
| Renderer -> Main | `mpd-play` | `send` | Fire-and-forget |
| Renderer -> Main | `mpd-pause` | `send` | Fire-and-forget |
| Renderer -> Main | `mpd-stop` | `send` | Fire-and-forget |
| Renderer -> Main | `mpd-next` | `send` | Fire-and-forget |
| Renderer -> Main | `mpd-previous` | `send` | Fire-and-forget |
| Renderer -> Main | `mpd-seek` | `send` | Arg: seconds |
| Renderer -> Main | `mpd-set-volume` | `send` | Arg: 0-100 |
| Renderer -> Main | `mpd-set-queue` | `send` | Args: items[], startIndex? |
| Renderer -> Main | `mpd-add-to-queue` | `send` | Arg: items[] |
| Renderer -> Main | `mpd-clear-queue` | `send` | No args |
| Main -> Renderer | `renderer-mpd-status` | `send` | Polled status (1.5s) |
| Main -> Renderer | `renderer-mpd-play` | `send` | State change event |
| Main -> Renderer | `renderer-mpd-pause` | `send` | State change event |
| Main -> Renderer | `renderer-mpd-stop` | `send` | State change event |
| Main -> Renderer | `renderer-mpd-connected` | `send` | Connection established |
| Main -> Renderer | `renderer-mpd-disconnected` | `send` | Connection lost |
| Main -> Renderer | `renderer-mpd-error` | `send` | Error with message |
| Main -> Renderer | `renderer-mpd-seek` | `send` | Position changed |
| Main -> Renderer | `renderer-mpd-volume` | `send` | Volume changed |
| Main -> Renderer | `renderer-mpd-queue` | `send` | Queue modified |

**Pattern:** Use `invoke` (async, returns result) for queries and connection management. Use `send` (fire-and-forget) for playback commands.

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     RENDERER (React)                            │
│                                                                 │
│  Player Store ──watches──> useMpdPlayback() ──commands──>       │
│  (status, queue,           (5 useEffects)        |              │
│   volume, index)                                 |              │
│       ^                                          |              │
│       |                                          v              │
│  useMpdStatusSync() <──events── mpdPlayerListener               │
│  (position updates)              (onStatusUpdate,               │
│                                   onConnected, etc.)            │
│  useMpdConnection()                                             │
│  (UI status badge)                                              │
└────────────────────────────────┬────────────────────────────────┘
                                 │ window.api.mpdPlayer
                                 │ window.api.mpdPlayerListener
┌────────────────────────────────┼────────────────────────────────┐
│  PRELOAD (contextBridge)       │                                │
│  ipcRenderer.send/invoke  ─────┼──> ipcRenderer.on (events)    │
└────────────────────────────────┼────────────────────────────────┘
                                 │ IPC channels
┌────────────────────────────────┼────────────────────────────────┐
│  MAIN PROCESS                  │                                │
│                                v                                │
│  IPC Handlers ──> MpdPlaybackService                            │
│  (mpd-ipc-handlers.ts)   (mpc-js TCP client)                   │
│                           - Status polling (1.5s)               │
│                           - Queue mapping                       │
│                           - Reconnect (exp. backoff)            │
└────────────────────────────────┬────────────────────────────────┘
                                 │ TCP (port 6600)
┌────────────────────────────────┼────────────────────────────────┐
│  REMOTE MPD SERVER             │                                │
│  - Receives HTTP URLs          │                                │
│  - Fetches audio from server   │                                │
│  - Plays through DAC           │                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Design Patterns & Decisions

### 1. Single Service Instance
One global `mpdService` in the main process. Created on connect, destroyed on disconnect. Prevents multiple concurrent TCP connections.

### 2. `useRef` for State Comparison
The `useMpdPlayback` hook uses refs (`prevStatusRef`, `prevIndexRef`, `isConnectedRef`, `queueSyncedRef`) to compare previous vs current values inside `useEffect`. This avoids sending redundant commands to MPD when React re-renders.

### 3. Polling vs Push
MPD's protocol supports idle notifications, but position/elapsed time requires polling. We poll every 1.5s. Adjust the interval based on how precise you need the progress bar to be.

### 4. Exponential Backoff Reconnection
Connection drops trigger automatic reconnection: 1s, 2s, 4s, 8s, ..., max 30s. Resets after successful reconnection. Caps at 10 attempts.

### 5. Queue Mapping
MPD has its own queue indices. The service maintains `queueMapping: { mpdIndex: appItemId }` so you can correlate MPD's "now playing song #3" back to your app's queue.

### 6. Fire-and-Forget for Commands
Playback commands (play, pause, next, etc.) use `ipcRenderer.send` (no response). This keeps the UI responsive. Status updates come back via the polling mechanism.

### 7. Stream URLs with Embedded Auth
MPD fetches audio directly from your music server via HTTP. The URLs must include any required auth tokens (e.g., Subsonic API tokens). Build these in `buildStreamUrl()`.

---

## MPD Server Setup

### Install

```bash
sudo apt update && sudo apt install mpd mpc
```

### Configure (`/etc/mpd.conf`)

```conf
bind_to_address "0.0.0.0"
port "6600"

# Optional password
# password "yourpass@read,add,control,admin"

music_directory "/var/lib/mpd/music"

audio_output {
    type          "alsa"
    name          "USB DAC"
    device        "hw:CARD=DAC,DEV=0"   # Find with: aplay -l
    mixer_type    "software"
}

# Performance tuning for HTTP streaming
audio_buffer_size    "4096"
buffer_before_play   "10%"
auto_update          "no"
```

### Start

```bash
sudo systemctl restart mpd
sudo systemctl enable mpd
```

### Verify

```bash
mpc status                              # Check MPD is running
telnet <mpd-host> 6600                  # Check network access
mpc add "http://example.com/test.mp3"   # Test HTTP playback
mpc play
```

---

## Checklist for Adapting to Another Project

1. **Install `mpc-js`** in your Electron project
2. **Copy the types** (`types.ts`) and adapt `QueueItem` to your song model
3. **Copy the service** (`mpd-playback-service.ts`) -- mostly generic
4. **Copy the IPC handlers** (`mpd-ipc-handlers.ts`) -- mostly generic
5. **Copy the preload bridge** (`mpd-player.ts`) -- fully generic
6. **Adapt the hooks** to your store (Zustand, Redux, Context, etc.):
   - Map your store's `status`, `queue`, `volume`, `currentIndex` to the hook effects
   - Implement `convertToMpdQueue()` for your song type
7. **Add UI components** for connection settings and status display
8. **Add `remote_mpd`** to your playback type enum
9. **Add MPD config** to your settings store with persistence
10. **Initialize IPC handlers** in your main process entry point
