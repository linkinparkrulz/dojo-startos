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
    pruning: shape({
      mode: string
    })
  }),
  'zmq-enabled': boolean
});

const matchIndexerConfig = shape({
  type: string,  // "electrs" or "fulcrum"
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

      if (!config['zmq-enabled']) {
	return { error: "Must have ZeroMQ enabled" };
      }

      if (config.advanced.pruning.mode !== "disabled") {
        return { error: "Pruning must be disabled (must be an archival node)" };
      }

      return { result: null };
    },
    // deno-lint-ignore require-await
    async autoConfigure(effects, configInput) {
      effects.info("autoconfigure bitcoind");

      const config = matchBitcoindConfig.unsafeCast(configInput);

      config.rpc.enable = true;

      config['zmq-enabled'] = true;

      if (config.advanced.pruning.mode !== "disabled") {
        config.advanced.pruning.mode = "disabled";
      }

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

      if (!config['zmq-enabled']) {
	return { error: "Must have ZeroMQ enabled" };
      }

      if (config.advanced.pruning.mode !== "disabled") {
        return { error: "Pruning must be disabled (must be an archival node)" };
      }

      return { result: null };
    },
    // deno-lint-ignore require-await
    async autoConfigure(effects, configInput) {
      effects.info("autoconfigure bitcoind");

      const config = matchBitcoindConfig.unsafeCast(configInput);

      config.rpc.enable = true;

      config['zmq-enabled'] = true;

      if (config.advanced.pruning.mode !== "disabled") {
        config.advanced.pruning.mode = "disabled";
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
      if (!["electrs", "fulcrum"].includes(config.type)) {
        return { error: "Indexer type must be either 'electrs' or 'fulcrum'" };
      }
      return { result: null };
    },

    // deno-lint-ignore require-await
    async autoConfigure(effects, configInput) {
      effects.info("autoconfigure indexer");
      const config = matchIndexerConfig.unsafeCast(configInput);

      // Set default type if not specified
      if (!config.type) {
        config.type = "fulcrum";  // default to fulcrum
      }

      return { result: config };
    },
  }
};
