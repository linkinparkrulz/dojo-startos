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

const matchIndexerConfig = shape({
  type: string,  // "electrs" or "fulcrum"
  rpc: shape({
    enable: boolean,
    port: number,
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

      if (config.advanced.pruning.mode !== "disabled") {
        return { error: "Pruning must be disabled (must be an archival node)" };
      }

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

      if (config.advanced.pruning.mode !== "disabled") {
        config.advanced.pruning.mode = "disabled";
      }

      // config.advanced.blockfilters.blockfilterindex = true;

      // if (config.rpc.advanced.threads < 4) {
      //   config.rpc.advanced.threads = 4;
      // }

      return { result: config };
    },
  },
  'bitcoind-testnet': {
    // deno-lint-ignore require-await
    async check(effects, config) {
      effects.info("check bitcoind-testnet");

      if (!matchBitcoindConfig.test(config)) {
        return { error: "Bitcoind-testnet config is not the correct shape" }
      }

      if (!config.rpc.enable) {
        return { error: "Must have RPC enabled" };
      }

      if (config.advanced.pruning.mode !== "disabled") {
        return { error: "Pruning must be disabled (must be an archival node)" };
      }

      if (!config.advanced.blockfilters.blockfilterindex) {
        return {
          error:
            "Must have block filter index enabled for Run The Numbers to work",
        };
      }

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

      if (config.advanced.pruning.mode !== "disabled") {
        config.advanced.pruning.mode = "disabled";
      }

      config.advanced.blockfilters.blockfilterindex = true;

      // if (config.rpc.advanced.threads < 4) {
      //   config.rpc.advanced.threads = 4;
      // }

      return { result: config };
    },
  },
  indexer: {
    // deno-lint-ignore require-await
    async check(effects, config) {
      effects.info("check indexer");
      if (!matchIndexerConfig.test(config)) {
        return { error: "Indexer config is not the correct shape" };
      }
      if (!config.rpc.enable) {
        return { error: "Must have RPC enabled" };
      }
      if (!["electrs", "fulcrum"].includes(config.type)) {
        return { error: "Indexer type must be either 'electrs' or 'fulcrum'" };
      }
      return { result: null };
    },

    // deno-lint-ignore require-await
    async autoConfigure(effects, configInput) {
      effects.info("autoconfigure indexer");
      const config = matchIndexerConfig.unsafeCast(configInput);
      config.rpc.enable = true;

      // Set default type if not specified
      if (!config.type) {
        config.type = "electrs";  // default to electrs
      }

      // Ensure port is set
      if (!config.rpc.port) {
        config.rpc.port = 50001;  // default electrum port
      }

      return { result: config };
    },
  },
  indexer: {
    // deno-lint-ignore require-await
    async check(effects, config) {
      effects.info("check indexer");
      if (!matchIndexerConfig.test(config)) {
        return { error: "Indexer config is not the correct shape" };
      }
      if (!config.rpc.enable) {
        return { error: "Must have RPC enabled" };
      }
      if (!["electrs", "fulcrum"].includes(config.type)) {
        return { error: "Indexer type must be either 'electrs' or 'fulcrum'" };
      }
      return { result: null };
    },

    // deno-lint-ignore require-await
    async autoConfigure(effects, configInput) {
      effects.info("autoconfigure indexer");
      const config = matchIndexerConfig.unsafeCast(configInput);
      config.rpc.enable = true;

      // Set default type if not specified
      if (!config.type) {
        config.type = "electrs";  // default to electrs
      }

      // Ensure port is set
      if (!config.rpc.port) {
        config.rpc.port = 50001;  // default electrum port
      }

      return { result: config };
    },
  },
  indexer: {
    // deno-lint-ignore require-await
    async check(effects, config) {
      effects.info("check indexer");
      if (!matchIndexerConfig.test(config)) {
        return { error: "Indexer config is not the correct shape" };
      }
      if (!config.rpc.enable) {
        return { error: "Must have RPC enabled" };
      }
      if (!["electrs", "fulcrum"].includes(config.type)) {
        return { error: "Indexer type must be either 'electrs' or 'fulcrum'" };
      }
      return { result: null };
    },

    // deno-lint-ignore require-await
    async autoConfigure(effects, configInput) {
      effects.info("autoconfigure indexer");
      const config = matchIndexerConfig.unsafeCast(configInput);
      config.rpc.enable = true;

      // Set default type if not specified
      if (!config.type) {
        config.type = "electrs";  // default to electrs
      }

      // Ensure port is set
      if (!config.rpc.port) {
        config.rpc.port = 50001;  // default electrum port
      }

      return { result: config };
    },
  }

};