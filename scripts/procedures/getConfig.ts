import { compat, types as T } from "../deps.ts";

export const getConfig: T.ExpectedExports.getConfig = compat.getConfig({
  "tor-address": {
    "name": "Tor Address",
    "description": "The Tor address of the network interface",
    "type": "pointer",
    "subtype": "package",
    "package-id": "dojo",
    "target": "tor-address",
    "interface": "main",
  },
  "bitcoin-node": {
    "type": "union",
    "name": "Bitcoin Node",
    "description":
      "The Bitcoin node type you would like to use for Dojo",
    "tag": {
      "id": "type",
      "name": "Select Bitcoin Node",
      "variant-names": {
        "bitcoind": "Bitcoin Core",
        "bitcoind-testnet": "Bitcoin Core (testnet4)",
      },
      "description":
        "The Bitcoin node type you would like to use for Dojo",
    },
    "default": "bitcoind",
    "variants": {
      "bitcoind": {
        "username": {
          "type": "pointer",
          "name": "RPC Username",
          "description": "The username for Bitcoin Core's RPC interface",
          "subtype": "package",
          "package-id": "bitcoind",
          "target": "config",
          "multi": false,
          "selector": "$.rpc.username",
        },
        "password": {
          "type": "pointer",
          "name": "RPC Password",
          "description": "The password for Bitcoin Core's RPC interface",
          "subtype": "package",
          "package-id": "bitcoind",
          "target": "config",
          "multi": false,
          "selector": "$.rpc.password",
        },
      },
      "bitcoind-testnet": {
        "username": {
          "type": "pointer",
          "name": "RPC Username",
          "description": "The username for Bitcoin Core Testnet RPC interface",
          "subtype": "package",
          "package-id": "bitcoind-testnet",
          "target": "config",
          "multi": false,
          "selector": "$.rpc.username",
        },
        "password": {
          "type": "pointer",
          "name": "RPC Password",
          "description": "The password for Bitcoin Core Testnet RPC interface",
          "subtype": "package",
          "package-id": "bitcoind-testnet",
          "target": "config",
          "multi": false,
          "selector": "$.rpc.password",
        },
      },
    },
  },
  "indexer": {
    "type": "union",
    "name": "Indexer",
    "description":
      "The indexer you want to use for Dojo",
    "tag": {
      "id": "type",
      "name": "Select Indexer",
      "variant-names": {
        "electrs": "electrs",
        "fulcrum": "Fulcrum",
      },
      "description":
        "The indexer you want to use for Dojo",
    },
    "default": "electrs",
    "variants": {
      "electrs": {},
      "fulcrum": {},
    },
  },
  "payment-code": {
    "type": "string",
    "name": "BIP47 Payment Code",
    "description": "BIP47 Payment Code used for admin authentication",
    "nullable": true,
    "copyable": true,
    "masked": false
  },
  "admin-key": {
    "type": "string",
    "name": "Admin Key",
    "description": "Key for accessing the admin/maintenance",
    "nullable": false,
    "copyable": true,
    "masked": true,
    "default": {
      "charset": "a-z,A-Z,0-9",
      "len": 22,
    },
  },
  "api-key": {
    "type": "string",
    "name": "API Key",
    "description": "Key for accessing the services",
    "nullable": false,
    "copyable": true,
    "masked": true,
    "default": {
      "charset": "a-z,A-Z,0-9",
      "len": 22,
    },
  },
  "jwt-secret": {
    "type": "string",
    "name": "JWT Secret",
    "description": "Secret used by the server for signing",
    "nullable": false,
    "copyable": true,
    "masked": true,
    "default": {
      "charset": "a-z,A-Z,0-9",
      "len": 22,
    },
  },
});