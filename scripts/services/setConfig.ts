import {
  compat,
  types as T
} from "../deps.ts";
export const setConfig: T.ExpectedExports.setConfig = async (effects, input ) => {

  const depsBitcoind: T.DependsOn = {bitcoind: ['synced']}

  return await compat.setConfig(effects,input, depsBitcoind)
}