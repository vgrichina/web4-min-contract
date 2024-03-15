# web4-min-contract

Minimal useful [Web4](https://github.com/vgrichina/web4) contract. Can be used together with [web4-deploy](https://github.com/vgrichina/web4-deploy)
to deploy website tied to your `.near` account, with static content hosted on IPFS.

## Building from source

Install [Zig](https://ziglang.org/learn/getting-started/#installing-zig) first.

Then run:

```bash
zig build-lib web4-min.zig -target wasm32-freestanding -dynamic -rdynamic -OReleaseSmall
```

You should get `web4-min.wasm` file.

## Deploying smart contract

Install [near-cli](https://github.com/near/near-cli) first.

Then run:

```bash
near deploy --wasmFile web4-min.wasm --accountId <your-account>.near
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
