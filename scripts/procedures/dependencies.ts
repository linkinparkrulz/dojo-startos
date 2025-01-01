import { types as T, matches } from "../deps.ts";

const { shape, number, string, boolean } = matches;

const matchBitcoindConfig = shape({
  rpc: shape({
    enable: boolean,
    advanced: shape({
      threads: number,
    })
  }),
  advanced: shape({
    blockfilters: shape({
      blockfilterindex: boolean,
    }),
    pruning: shape({
      mode: string
    })
  }),
});

export const dependencies: T.ExpectedExports.dependencies = {
  bitcoind: {
    // deno-lint-ignore require-await
    async check(effects, config) {
      effects.info("check bitcoind");
      if (!matchBitcoindConfig.test(config)) {
        return { error: "Bitcoind config is not the correct shape" }
      }
      if (!config.rpc.enable) {
        return { error: "Must have RPC enabled" };
      }
      // if (config.advanced.pruning.mode !== "disabled") {
      //   return { error: "Pruning must be disabled (must be an archival node)" };
      // }
      // if (!config.advanced.blockfilters.blockfilterindex) {
      //   return {
      //     error:
      //       "Must have block filter index enabled for Run The Numbers to work",
      //   };
      // }
      // if (config.rpc.advanced.threads < 4) {
      //   return { error: "Must be greater than or equal to 4" };
      // }
      return { result: null };
    },
    // deno-lint-ignore require-await
    async autoConfigure(effects, configInput) {
      effects.info("autoconfigure bitcoind");
      const config = matchBitcoindConfig.unsafeCast(configInput);
      config.rpc.enable = true;
      // config.advanced.blockfilters.blockfilterindex = true;
      // if (config.rpc.advanced.threads < 4) {
      //   config.rpc.advanced.threads = 4;
      // }
      // if (config.advanced.pruning.mode !== "disabled") {
      //   config.advanced.pruning.mode = "disabled";
      // }
      return { result: config };
    },
  }
};