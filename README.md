# web4-min-contract

Minimal useful [Web4](https://github.com/vgrichina/web4) contract. Can be used together with [web4-deploy](https://github.com/vgrichina/web4-deploy)
to deploy website tied to your `.near` account, with static content hosted on IPFS.

## Building from source

Install [Zig](https://ziglang.org/learn/getting-started/#installing-zig). Below command uses [v0.13.0](https://github.com/ziglang/zig/releases/tag/0.13.0).

Then run:

```bash
zig build --release=small
```

You should get `zig-out/bin/web4-min` file.

## Deploying smart contract

Install [near-cli-rs](https://github.com/near/near-cli-rs) first.

Then run:

```bash
near deploy --wasmFile zig-out/bin/web4-min --accountId <your-account>.near
```

See more on [how to deploy NEAR smart contracts](https://docs.near.org/develop/deploy).

## Deploying website

Run [web4-deploy](https://github.com/vgrichina/web4-deploy) using `npx`:

```bash
npx web4-deploy path/to/your/website <your-account>.near
```

## How it works

`web4-deploy` will upload your website to IPFS and then call `web4_setStaticUrl` method in this smart contract to set IPFS hash of your website.

Then you can access your website using `https://<your-account>.near.page` Web4 gateway.

## Contract Functions

- `web4_get`: Serves static content from IPFS, with SPA support (redirects to index.html)
- `web4_setStaticUrl`: Updates the IPFS URL for static content
- `web4_setOwner`: Updates the contract owner account

## SPA Support
The contract automatically redirects paths without file extensions to `index.html`, making it suitable for Single Page Applications (SPAs). For example:
- `/about` -> serves `/index.html`
- `/style.css` -> serves directly

## Storage
The contract uses two storage keys:
- `web4:staticUrl` - IPFS URL for static content
- `web4:owner` - Optional owner account that can manage the contract

## Default Content
When no static URL is set, the contract serves content from:
```ipfs://bafybeidc4lvv4bld66h4rmy2jvgjdrgul5ub5s75vbqrcbjd3jeaqnyd5e```
This contains instructions for getting started.

## Access Control

The contract can be managed by:
- The contract account itself
- An owner account (if set via web4_setOwner)

## Memory Management
The contract is optimized for NEAR's ephemeral runtime environment:
- Memory is automatically freed after each contract call
- No explicit memory management is needed
- Built with `-O ReleaseSmall` for minimal contract size

## Development

Run tests:
```bash
zig build test
```

Note: The contract is designed for NEAR's ephemeral runtime environment where memory is automatically freed after execution.
