# MPD Remote Playback - NoisePort Implementation Reference

This document describes how NoisePort implements remote playback via MPD (Music Player Daemon). Use this as inspiration for implementing similar functionality in other projects.

---

## What We Built

NoisePort acts as an **MPD client** that controls a remote MPD server (e.g., Raspberry Pi with speakers). The app:
- Connects to MPD over TCP (port 6600)
- Converts its music queue into HTTP stream URLs
- Tells MPD to play those URLs
- Polls MPD for playback status (position, state)

**Key insight**: MPD fetches audio directly from the music server (Navidrome/Jellyfin). The app never streams audio—it only orchestrates.

```
┌─────────────┐       ┌─────────────┐       ┌─────────────┐
│  NoisePort  │  TCP  │ MPD Server  │ HTTP  │  Navidrome  │
│   (App)     │──────►│ (Speakers)  │──────►│  (Music)    │
└─────────────┘ cmds  └─────────────┘ audio └─────────────┘
```

---

## Architecture Overview

### Files We Created

| File | Purpose |
|------|---------|
| `src/main/features/playback/mpd-playback-service.ts` | TCP client, commands, polling, reconnect |
| `src/main/features/playback/mpd-ipc-handlers.ts` | IPC bridge (Electron-specific) |
| `src/preload/mpd-player.ts` | Context bridge API |
| `src/renderer/hooks/use-mpd-playback.ts` | Syncs app state → MPD |
| `src/renderer/hooks/use-mpd-status-sync.ts` | Syncs MPD status → app state |
| `src/renderer/features/player/mpd-queue-sync.ts` | Converts songs to MPD queue items |

---

## Core Service (mpd-playback-service.ts)

The heart of the implementation. Uses `mpc-js` library for TCP communication.

### Key Properties

```typescript
class MpdPlaybackService {
  private client: MPC | null = null;
  private connected = false;
  private statusPollInterval: NodeJS.Timeout | null = null;
  private queueMapping: Record<number, string> = {}; // mpdIndex → appSongId
  private reconnectAttempts = 0;
}
```

### Connection

```typescript
async connect(): Promise<void> {
  this.client = new MPC();
  await this.client.connectTCP(this.config.host, this.config.port);

  // Authenticate if password provided
  if (this.config.password) {
    await this.sendCommand('password', [this.config.password]);
  }

  this.connected = true;
  this.startStatusPolling();
}
```

### Playback Commands

```typescript
async play(): Promise<void> {
  await this.sendCommand('play');
}

async pause(): Promise<void> {
  await this.sendCommand('pause', ['1']);
}

async seek(seconds: number): Promise<void> {
  await this.sendCommand('seekcur', [seconds.toString()]);
}

async setVolume(volume: number): Promise<void> {
  const clamped = Math.max(0, Math.min(100, volume));
  await this.sendCommand('setvol', [clamped.toString()]);
}
```

### Queue Management

```typescript
async setQueue(items: QueueItem[], startIndex = 0): Promise<void> {
  // Clear existing queue
  await this.sendCommand('clear');
  this.queueMapping = {};

  // Add each item by URI
  for (let i = 0; i < items.length; i++) {
    await this.sendCommand('add', [items[i].uri]);
    this.queueMapping[i] = items[i].id;
  }

  // Start playback at index
  if (items.length > 0) {
    await this.sendCommand('play', [startIndex.toString()]);
  }
}
```

### Status Polling

MPD doesn't push position updates, so we poll every 1.5 seconds:

```typescript
private startStatusPolling(): void {
  this.statusPollInterval = setInterval(async () => {
    const status = await this.getStatus();
    this.emit({ type: 'status', data: status });
  }, 1500);
}

async getStatus(): Promise<PlaybackStatus> {
  const statusResponse = await this.sendCommand('status');
  const songResponse = await this.sendCommand('currentsong');

  const status = this.parseResponse(statusResponse);
  const song = this.parseResponse(songResponse);

  return {
    state: this.mapMpdState(status.state), // 'play'|'pause'|'stop'
    position: parseFloat(status.elapsed || '0'),
    duration: parseFloat(status.duration || '0'),
    volume: parseInt(status.volume || '0', 10),
    currentIndex: parseInt(status.song || '-1', 10),
  };
}
```

### Reconnection with Exponential Backoff

```typescript
private scheduleReconnect(): void {
  if (this.reconnectAttempts >= 10) return;

  this.reconnectAttempts++;
  // 1s, 2s, 4s, 8s, ... max 30s
  const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts - 1), 30000);

  setTimeout(() => this.connect(), delay);
}
```

---

## Queue Sync (mpd-queue-sync.ts)

Converts app songs to MPD-playable items with authenticated stream URLs.

```typescript
interface MpdQueueItem {
  id: string;    // App's song ID
  uri: string;   // HTTP stream URL
  duration?: number;
  metadata?: { title?: string; artist?: string; album?: string };
}

function buildStreamUrl(song: QueueSong, transcode?: TranscodingConfig): string {
  // If transcoding enabled, get transcoded URL
  if (transcode?.enabled) {
    return api.controller.getTranscodingUrl({ ... });
  }
  // Otherwise use original stream URL (already has auth params)
  return song.streamUrl;
}

function convertToMpdQueue(songs: QueueSong[], transcode?: TranscodingConfig): MpdQueueItem[] {
  return songs.map((song) => ({
    id: song.uniqueId,
    uri: buildStreamUrl(song, transcode),
    duration: song.duration || 0,
    metadata: {
      title: song.name,
      artist: song.artistName,
      album: song.album,
    },
  }));
}
```

---

## State Sync Hook (use-mpd-playback.ts)

Watches the app's player store and sends commands to MPD when state changes.

### Key Pattern: Refs for Change Detection

```typescript
const prevStatusRef = useRef<PlayerStatus>(status);
const prevIndexRef = useRef(currentIndex);
const queueSyncedRef = useRef(false);
```

### Connect/Disconnect on Mode Change

```typescript
useEffect(() => {
  if (!isMpdMode || !mpdConfig?.enabled) {
    if (isConnectedRef.current) {
      mpdPlayer?.disconnect();
    }
    return;
  }

  // Connect
  mpdPlayer?.connect({
    host: mpdConfig.host,
    port: mpdConfig.port,
    password: mpdConfig.password,
  });
}, [isMpdMode, mpdConfig]);
```

### Sync Queue on Changes

```typescript
useEffect(() => {
  if (!isMpdMode || !isConnectedRef.current || queue.length === 0) return;

  const queueChanged = queue.length !== prevQueueLengthRef.current || !queueSyncedRef.current;

  if (queueChanged) {
    const mpdQueue = convertToMpdQueue(queue, settings.transcode);
    mpdPlayer?.setQueue(mpdQueue, currentIndex);
    queueSyncedRef.current = true;
  }
}, [queue, currentIndex]);
```

### Handle Play/Pause

```typescript
useEffect(() => {
  if (!isMpdMode || !isConnectedRef.current) return;

  if (status !== prevStatusRef.current) {
    prevStatusRef.current = status;

    if (status === PlayerStatus.PLAYING) {
      mpdPlayer?.play();
    } else if (status === PlayerStatus.PAUSED) {
      mpdPlayer?.pause();
    }
  }
}, [status]);
```

### Handle Track Navigation

```typescript
useEffect(() => {
  if (!isMpdMode || !queueSyncedRef.current) return;

  const prevIndex = prevIndexRef.current;
  prevIndexRef.current = currentIndex;

  if (prevIndex !== currentIndex && prevIndex !== -1) {
    const diff = currentIndex - prevIndex;

    if (diff === 1) {
      mpdPlayer?.next();
    } else if (diff === -1) {
      mpdPlayer?.previous();
    } else {
      // Jump: resync entire queue at new position
      const mpdQueue = convertToMpdQueue(queue, settings.transcode);
      mpdPlayer?.setQueue(mpdQueue, currentIndex);
    }
  }
}, [currentIndex]);
```

---

## Status Sync Hook (use-mpd-status-sync.ts)

Receives MPD status updates and syncs position back to app state.

```typescript
useEffect(() => {
  if (!isMpdMode) return;

  mpdPlayerListener?.onStatusUpdate((_event, status) => {
    // Update player store with MPD's current position
    actions.setCurrentTime(status.position);
  });
}, [isMpdMode]);
```

---

## MPD Commands We Use

| Command | Usage |
|---------|-------|
| `password <pw>` | Authenticate after connect |
| `play [index]` | Start playback |
| `pause 1` | Pause |
| `stop` | Stop |
| `next` | Next track |
| `previous` | Previous track |
| `seekcur <seconds>` | Seek in current track |
| `setvol <0-100>` | Set volume |
| `clear` | Clear queue |
| `add <uri>` | Add URL to queue |
| `status` | Get state, elapsed, duration, volume, song index |
| `currentsong` | Get current track info |

---

## Data Flow Summary

### User Action → MPD

```
User taps Play
  → Zustand store: status = PLAYING
  → use-mpd-playback detects: status !== prevStatus
  → Calls: mpdPlayer.play()
  → IPC → Main process
  → MpdPlaybackService.play()
  → TCP: "play\n"
  → MPD plays audio
```

### MPD → App State

```
Every 1.5s:
  → MpdPlaybackService polls: status + currentsong
  → Emits 'status' event
  → IPC → Renderer: renderer-mpd-status
  → use-mpd-status-sync receives
  → Updates store: actions.setCurrentTime(position)
  → UI re-renders with progress
```

---

## Key Design Decisions

1. **Queue Mapping**: MPD uses integer indices. We maintain `{ mpdIndex: appSongId }` to correlate.

2. **Polling vs Push**: MPD doesn't push position. We poll every 1.5s—good enough for progress bars.

3. **Ref-Based Change Detection**: Using `useRef` to compare previous vs current values avoids sending duplicate commands.

4. **Adjacent vs Jump Navigation**: If index changes by ±1, use `next()`/`previous()`. Otherwise, resync the entire queue.

5. **Stream URLs**: MPD fetches audio directly from the music server. URLs must include auth tokens.

6. **Exponential Backoff**: On disconnect, retry at 1s, 2s, 4s, 8s... up to 30s, max 10 attempts.

---

## Settings Stored

```typescript
// In settings store
playback: {
  type: 'local' | 'web' | 'remote_mpd',
  remoteTargets: {
    mpd: {
      enabled: boolean,
      host: string,      // e.g., "192.168.1.100"
      port: number,      // default 6600
      password: string,  // optional
    }
  }
}
```

---

## What You'd Adapt for Flutter

1. **No IPC needed** - Direct method calls from UI to service
2. **Use `dart:io` Socket** - No external package needed for TCP
3. **Streams instead of IPC events** - `StreamController` for status updates
4. **Riverpod/Bloc** - Replace Zustand hooks with your state management
5. **Same MPD protocol** - Commands and parsing are identical
