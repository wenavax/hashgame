# HashRig — Crypto Mining Simulator

A mobile-first crypto mining simulation game built as a single HTML file. Tap to mine HashCoins, manage resources, upgrade your rig, complete daily quests, and battle other miners in PvP.

**Live:** [hashrategame.netlify.app](https://hashrategame.netlify.app/)

## Features

- **Tap-to-Mine** — Mine HashCoins with tap or SPACE key, with random variance and coin multipliers
- **3 Mineable Coins** — BTC (x1.0), ETH (x1.5), SOL (x2.0) with live simulated market prices
- **Resource Management** — Balance Energy, Cooling, and Health to keep your rig running
- **10 Upgrades** — Hardware (GPU, ASIC, Rack), Software (Algorithm, Pool, Overclock), Defense (Shield, Firewall, Vault)
- **Auto-Mining** — Passive income after purchasing ASIC or Rack upgrades
- **Block Finding** — Progressive difficulty system with scaling rewards
- **Daily Quests** — 3 random quests per day with HC rewards, resets at midnight
- **PvP Battles** — Attack 7 simulated enemies with win-chance based on your hash rate vs their defense
- **Ethereum Wallet** — Auto-generated BIP-44 HD wallet via ethers.js (self-custodial, MetaMask compatible)
- **Persistent State** — Auto-saves to localStorage every 8 seconds

## Tech Stack

- **Frontend:** HTML5 / CSS3 / Vanilla JavaScript (single file)
- **Blockchain:** ethers.js v6 — BIP-39 / BIP-44 HD Wallet
- **Fonts:** Orbitron + Share Tech Mono (Google Fonts)
- **Hosting:** Netlify (static)

## Security (v1.1)

- **IIFE encapsulation** — All game logic wrapped in closure, no global state exposure
- **Subresource Integrity (SRI)** — ethers.js CDN loaded with SHA-384 hash verification
- **Content Security Policy** — CSP meta tag restricts script/style/font sources
- **Safe DOM rendering** — All dynamic content rendered via `createElement`/`textContent`, no `innerHTML` with user data
- **Wallet isolation** — Private key/mnemonic stored in closure variable, never on `window`
- **Lazy reveal** — Seed phrase and private key not rendered to DOM until explicitly revealed by user
- **Clipboard auto-clear** — Copied secrets automatically cleared from clipboard after 30 seconds
- **Input validation** — Loaded save data validated with type checking, range clamping, and key whitelisting
- **Immutable constants** — All game definitions (`UPGRADES`, `ENEMIES`, `QUEST_TPL`) deep-frozen with `Object.freeze`
- **Delta-time validation** — Auto-mining rejects intervals under 500ms to detect timer manipulation
- **HTTPS enforcement** — CSP `upgrade-insecure-requests` directive

### Known Client-Side Limitations

This is a client-side only game. Without a server backend, the following cannot be fully prevented:
- DevTools console manipulation of in-memory state
- localStorage direct editing
- `Math.random` override for PvP outcomes

These will be addressed in **Phase 1** (server-side authority).

## Game Economy

| Metric | Value |
|--------|-------|
| Total HC to max all upgrades | ~1.14M HC |
| Max hash rate (fully upgraded) | 1,275 H/s |
| Max auto HC/min (SOL + Algo 5) | ~111K HC/min |
| PvP cooldown | 60 seconds |
| Daily quests | 3 per day |
| Block difficulty scaling | 1.3^n with 1.15^n reward scaling |

## How to Play

1. **Tap the rig** (or press SPACE) to mine HashCoins
2. **Watch your resources** — recharge energy, cool your rig, repair when needed
3. **Choose your coin** — higher risk coins give better multipliers
4. **Buy upgrades** — increase hash rate and unlock auto-mining
5. **Complete quests** — earn bonus HC from daily challenges
6. **Attack enemies** — steal their coins in PvP (spend first to minimize loss risk)
7. **Check your wallet** — your real Ethereum address is in the wallet modal

## Development

```bash
# Clone
git clone git@github.com:wenavax/hashgame.git
cd hashgame

# Open in browser
open index.html

# Deploy (auto on push to main via Netlify)
git add index.html && git commit -m "update" && git push
```

## Roadmap

| Phase | Description | Status |
|-------|-------------|--------|
| 0 | Single-file frontend | ✅ Complete |
| 1 | Backend & Multiplayer (Node.js, PostgreSQL, Redis, Socket.io) | Planned |
| 2 | ERC-20 HASH Token (Solidity smart contract) | Planned |
| 3 | Real Wallet Integration (Infura/Alchemy RPC) | Planned |
| 4 | PWA & Mobile (Service Worker, push notifications) | Planned |
| 5 | Monetization (Premium, AdMob, NFT skins) | Planned |
| 6 | Security & Testing (audit, anti-cheat, beta) | Planned |
| 7 | Launch (Play Store, App Store, CoinGecko) | Planned |

## License

All rights reserved.
