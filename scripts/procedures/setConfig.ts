import { compat, types as T } from "../deps.ts";

// deno-lint-ignore require-await
export const setConfig: T.ExpectedExports.setConfig = async (
  effects: T.Effects,
  newConfig: T.Config,
) => {
  const dependencies: { [key: string]: string[] } = {};

  if ((newConfig as any)?.['bitcoin-node']?.type === 'bitcoind') {
    dependencies['bitcoind'] = ['synced'];
  }

  if ((newConfig as any)?.['bitcoin-node']?.type === 'bitcoind-testnet') {
    dependencies['bitcoind-testnet'] = ['synced'];
  }

  if ((newConfig as any)?.indexer?.type === 'fulcrum') {
    dependencies['fulcrum'] = ['synced'];
  }

  if ((newConfig as any)?.indexer?.type === 'electrs') {
    dependencies['electrs'] = ['synced'];
  }

  return compat.setConfig(effects, newConfig, dependencies);
};