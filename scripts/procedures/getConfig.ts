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
  "soroban-announce": {
    "type": "union",
    "name": "Soroban Network Announce",
    "description": "Configure Soroban network participation",
    "tag": {
      "id": "enabled",
      "name": "Soroban Network Announce",
      "variant-names": {
        "disabled": "Disabled",
        "enabled": "Enabled"
      },
      "description": "Enable to participate in the Soroban network"
    },
    "default": "disabled",
    "variants": {
      "disabled": {},
      "enabled": {
        "pandotx-process": {
          "type": "boolean",
          "name": "PandoTx Process",
          "description": "Process and relay transactions from other Soroban nodes",
          "nullable": false,
          "default": false
        }
      }
    }
  },
  "pandotx-push": {
    "type": "boolean",
    "name": "PandoTx Push",
    "description": "Push your transactions through random Soroban nodes for enhanced privacy",
    "nullable": false,
    "default": true,
  },
  "pandotx-retries": {
    "type": "number",
    "name": "PandoTx Retries",
    "description": "Maximum retry attempts for failed transaction pushes",
    "nullable": false,
    "default": 2,
    "range": "[0,10]",
    "integral": true,
  },
  "pandotx-fallback-mode": {
    "type": "enum",
    "name": "PandoTx Fallback Mode",
    "description": "Behavior when Soroban push fails",
    "nullable": false,
    "default": "convenient",
    "values": ["convenient", "secure"],
    "value-names": {
      "convenient": "Convenient (fallback to local node)",
      "secure": "Secure (fail if Soroban unavailable)",
    },
  },
});