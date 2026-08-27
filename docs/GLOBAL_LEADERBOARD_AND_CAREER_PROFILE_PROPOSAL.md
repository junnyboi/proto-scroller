# Global Leaderboard, Callsign Profile, and Career History Proposal

**Author:** Manus AI
**Date:** 2026-08-27
**Status:** Approved for implementation by user request
**Canonical baseline:** `089f486`

## 1. Executive Summary

The current After-Action Dossier already records each run’s highest authored combo tier, score, enemy kills, fatal-weapon distribution, preferred weapon, and bounded lifetime totals. The proposed release turns that private record into a complete **operator identity and ranking system** without making network availability a gameplay dependency.

Every installation receives a persistent local profile with a custom callsign, a bounded history of recent runs, and a deterministic local leaderboard. When the Web host can reach the Manus-hosted database, the same profile submits only an allowlisted career-best payload and receives the global top rankings plus the player’s current placement. If the request fails, times out, or the game runs natively, the dossier switches to the local ranking immediately. Combat, saving, retry, extraction, and New Game+ never wait on the network.

The revamped dossier becomes a three-page terminal:

1. **After Action** preserves the current score, grade, combo, weapon affinity, enemy matrix, and career record.
2. **Career Signal** adds an interactive weapon-history chart, callsign editor, and local run ranking.
3. **Global Network** shows the worldwide ranking, player placement, freshness state, retry action, and explicit local-fallback status.

> The online board is a community ranking, not an anti-cheat competitive authority. The server validates shape and bounds, hashes installation identifiers at rest, applies monotonic career maxima, and never trusts the client with database access; a determined modified client can still fabricate gameplay statistics.

## 2. Delivery Options

| Approach | Tradeoffs | Cost | Setup Complexity |
|---|---|---:|---:|
| **Anonymous local-first community board** | No login friction; works in the existing game canvas; installation identity can be lost when browser storage is cleared; client-originated scores are bounded but not cryptographically authoritative | Managed application/database usage | Medium |
| **Manus account-bound competitive board** | Durable identity across devices and stronger abuse controls; requires login UI and account consent before submission; complicates the zero-chrome game flow | Managed application/database usage | High |
| **Local-only career board** | Fastest, private, and fully offline; cannot rank players globally | None beyond current hosting | Low |

The implementation will support the first approach now because it matches the existing anonymous profile boundary and the user’s request for a global board with local fallback. The database schema leaves room for a nullable account owner later, so Manus account linking can be added without changing the Godot profile format.

## 3. Player Experience

### 3.1 Callsign profile

A new **Operator Profile** block appears on the Career Signal page. The player can enter a callsign between 3 and 20 characters using letters, digits, spaces, hyphens, and underscores. Saving updates the local profile immediately and, when online, updates the same global installation row. Invalid input remains local to the editor and receives a translated validation message; it never reaches the database.

The initial callsign is `OBELISK-XXXX`, where the suffix derives from the local anonymous profile identifier. It is readable, non-sensitive, and stable until changed.

### 3.2 Interactive career-history chart

The local profile stores the most recent 30 finalized runs. Each immutable history item contains timestamp, score, highest combo tier, completion state, preferred weapon, total enemy kills, and bounded per-weapon kill counts. The chart visualizes the most recent 12 runs and selects the three most-used weapons across that window.

The chart supports:

- **Kills** and **share percentage** display modes;
- mouse hover, touch press, keyboard/controller left-right selection;
- a selected-run tooltip with callsign, timestamp-relative run number, score, combo tier, and per-weapon values;
- stable weapon colors shared with the current dossier palette;
- explicit empty and one-run states.

All chart geometry is drawn by a Godot `Control`; no raster chart assets are generated because exact values, scaling, and interaction must remain data-driven.

### 3.3 Global ranking

The Global Network page ranks profiles by:

1. highest authored combo tier, descending;
2. best score, descending;
3. best physical chain, descending;
4. earliest record timestamp, ascending;
5. stable row identifier.

The top 20 rows show rank, callsign, combo tier, best score, preferred weapon, and victories. The player’s own rank is shown even when outside the top 20. A refresh button is available, but the game also requests a background refresh whenever the dossier opens.

### 3.4 Local fallback

The local leaderboard ranks the same 30-run history using the same tier/score/chain ordering. It is available in native builds, offline browsers, fresh deployments before database migration, API failures, and request timeouts. The Global Network page visibly reports `GLOBAL`, `SYNCING`, `LOCAL FALLBACK`, or `NATIVE LOCAL` rather than pretending stale local data is worldwide.

## 4. Architecture

### 4.1 Godot-owned local state

`PlayerCombatProfileStore` becomes schema version 2. It owns:

- anonymous installation identifier;
- callsign and callsign normalization;
- career maxima and lifetime counters;
- the bounded 30-run history;
- deterministic local ranking;
- the allowlisted leaderboard submission payload.

Schema version 1 profiles migrate in place rather than reset. Existing totals, records, and anonymous IDs are preserved; a default callsign and empty history are added.

### 4.2 Trusted same-origin bridge

A new Godot `LeaderboardBridge` sends versioned requests to the parent WebDev host with `window.parent.postMessage`. Both directions require the exact same origin and a fixed channel/version. The React host validates `event.source === iframe.contentWindow`, validates the message with Zod, performs the typed API operation, and replies only to that iframe and origin.

Godot assigns a unique request ID, applies a bounded timeout, ignores unknown replies, and treats every failure as a local-fallback transition. No auth token, database credential, raw stack trace, or server environment value enters the iframe message.

### 4.3 Manus WebDev backend

The existing static fullscreen project is upgraded in place to the WebDev database/server scaffold. Its visible output remains exactly one fullscreen iframe. Backend additions use tRPC, Drizzle, and the built-in MySQL/TiDB database.

The `leaderboard_profiles` table stores one row per hashed anonymous installation ID. The server never persists the raw local identifier. Submission procedures apply strict length/range validation and monotonic maxima so a lower or stale submission cannot erase a record.

| Column | Purpose |
|---|---|
| `installationHash` | SHA-256 of the random local profile ID; unique server identity. |
| `callsign` | Sanitized player-selected display name. |
| `highestComboTier` | Career-best authored combo tier. |
| `bestScore` | Career-best final score. |
| `bestPhysicalChain` | Career-best physical kill chain. |
| `peakMultiplier` | Capped multiplier display value. |
| `totalRuns`, `victories`, `totalEnemyKills` | Monotonic bounded career totals. |
| `preferredWeapon` | Stable allowlisted weapon identifier. |
| `sourceRevision` | Bounded build revision for diagnostics. |
| `recordedAt`, `updatedAt` | Server timestamps used for deterministic ties and freshness. |

### 4.4 API surface

| Procedure | Access | Behavior |
|---|---|---|
| `leaderboard.list` | Public read | Returns bounded top rows and server timestamp. |
| `leaderboard.submit` | Public mutation | Validates the local identity and career payload, hashes identity, upserts monotonic maxima, returns updated top rows and player rank. |
| `leaderboard.updateCallsign` | Public mutation | Validates identity and callsign, updates one installation row, returns the normalized profile. |

The server uses parameterized Drizzle queries only. Database access remains server-side through `DATABASE_URL` supplied by WebDev.

## 5. Privacy and Abuse Boundaries

The online payload includes only the anonymous random profile ID in transit, callsign, build revision, best score, best combo tier, best physical chain, peak multiplier, preferred weapon, and bounded aggregate totals. The server hashes the anonymous ID before storage.

The following remain local and are never submitted: complete run history, per-run weapon trends, enemy-type details, campaign dossiers, ending archive, language/audio/input settings, hardware/browser fingerprints, IP-derived identity, save paths, and crash logs.

Callsigns are plain text rendered by Godot or React text nodes only. They are length-limited and character-allowlisted. The server enforces numeric ceilings, insertion/update timestamps, unique installation hashes, bounded query limits, and deterministic ordering. Rate limiting and signed authoritative simulation are explicitly deferred because the client currently owns gameplay authority.

## 6. Responsive Design

The existing 1280×720 dossier gains a compact top tab rail while preserving the fixed action footer. Career and global pages reuse the full card surface so content never competes with the overview. At 720×1280 the tabs remain at least 48 px high, the callsign editor uses a full-width row, the chart receives a tall 600×280 logical area, and leaderboard rows condense weapon/victory metadata beneath the callsign.

No additional WebDev page chrome is introduced. The React host remains invisible and fullscreen; it exists only to bridge trusted game messages to the managed database.

## 7. Success Criteria

The feature is complete when a player can set and persist a callsign, finalize multiple runs, inspect interactive weapon trends, view a deterministic local ranking, submit a bounded career-best profile to the Manus database, see the global top 20 and personal rank, lose connectivity without blocking the dossier, recover online via refresh, and use all three pages in landscape and portrait. The canonical Godot source must be pushed, freshly exported, remapped into the existing WebDev project, checkpointed, and published.
