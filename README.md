# web4-min-contract

Minimal useful [Web4](https://github.com/vgrichina/web4) contract. Can be used together with [web4-deploy](https://github.com/vgrichina/web4-deploy)
to deploy website tied to your `.near` account, with static content hosted on IPFS.

## Building from source

Install [Zig](https://ziglang.org/learn/getting-started/#installing-zig) first.

Then run:

```bash
zig build-lib web4-min.zig  -target wasm32-freestanding -dynamic -OReleaseSmall
```

You should get `web4-min.wasm` file.