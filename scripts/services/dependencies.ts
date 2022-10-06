import { types as T, matches } from "../deps.ts";

const { shape, arrayOf, string, boolean } = matches;

const matchProxyConfig = shape({
  users: arrayOf(
    shape(
      {
        name: string,
        "allowed-calls": arrayOf(string),
        password: string,
      },
    )
  ),
});

function times<T>(fn: (i: number) => T, amount: number): T[] {
  const answer = new Array(amount);
  for (let i = 0; i < amount; i++) {
    answer[i] = fn(i);
  }
  return answer;
}

function randomItemString(input: string) {
  return input[Math.floor(Math.random() * input.length)];
}

const serviceName = "dojo";
const fullChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
type Check = {
  currentError(config: T.Config): string | void;
  fix(config: T.Config): void;
};

const checks: Array<Check> = [
  {
    currentError(config) {
      if (!matchProxyConfig.test(config)) {
        return "Config is not the correct shape";
      }
      if (config.users.some((x) => x.name === serviceName)) {
        return;
      }
      return `Must have an RPC user named "${serviceName}"`;
    },
    fix(config) {
      if (!matchProxyConfig.test(config)) {
        return
      }
      config.users.push({
        name: serviceName,
        "allowed-calls": [],
        password: times(() => randomItemString(fullChars), 22).join(""),
      });
    },
  },
  ...[
    "createwallet",
    "loadwallet",
    "listwallets",
    "getwalletinfo",
    "getblockcount",
    "listaddressgroupings",
    "listunspent",
    "listtransactions",
    "importmulti",
    "listlabels",
    "getaddressesbylabel",
    "getinfo",
    "getbestblockhash",
    "gettxout",
    "getblockchaininfo",
    "sendrawtransaction",
    "getblockhash",
    "getblock",
    "getblockheader",
    "estimatesmartfee",
    "getnetworkinfo",
    "uptime",
    "getrawtransaction",
    "getpeerinfo",
    "getmempoolinfo",
    "getzmqnotifications",
  ].map(
    (operator): Check => ({
      currentError(config) {
        if (!matchProxyConfig.test(config)) {
          return "Config is not the correct shape";
        }
        if (config.users.find((x) => x.name === serviceName)?.["allowed-calls"]?.some((x) => x === operator) ?? false) {
          return;
        }
        return `RPC user "${serviceName}" must have "${operator}" enabled`;
      },
      fix(config) {
        if (!matchProxyConfig.test(config)) {
          throw new Error("Config is not the correct shape");
        }
        const found = config.users.find((x) => x.name === serviceName);
        if (!found) {
          throw new Error(`Users for "${serviceName}" should exist`);
        }
        found["allowed-calls"] = [...(found["allowed-calls"] ?? []), operator];
      },
    })
  ),
];

const matchBitcoindConfig = shape({
  rpc: shape({
    enable: boolean,
  }),
});

export const dependencies: T.ExpectedExports.dependencies = {
  "btc-rpc-proxy": {
    // deno-lint-ignore require-await
    async check(effects, configInput) {
      effects.info("check btc-rpc-proxy");
      for (const checker of checks) {
        const error = checker.currentError(configInput);
        if (error) {
          effects.error(`throwing error: ${error}`);
          return { error };
        }
      }
      return { result: null };
    },
    // deno-lint-ignore require-await
    async autoConfigure(effects, configInput) {
      effects.info("autoconfigure btc-rpc-proxy");
      for (const checker of checks) {
        const error = checker.currentError(configInput);
        if (error) {
          checker.fix(configInput);
        }
      }
      return { result: configInput };
    },
  },
  bitcoind: {
    // deno-lint-ignore require-await
    async check(_effects, configInput) {
      const config = matchBitcoindConfig.unsafeCast(configInput);
      if (!config.rpc.enable) {
        return { error: 'Must have RPC enabled' };
      }
      return { result: null };
    },
    // deno-lint-ignore require-await
    async autoConfigure(_effects, configInput) {
      const config = matchBitcoindConfig.unsafeCast(configInput);
      config.rpc.enable = true;
      return { result: config };
    },
  },
};
