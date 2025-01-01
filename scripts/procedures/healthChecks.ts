import { types as T, healthUtil } from "../deps.ts";

export const health: T.ExpectedExports.health = {
  async "web-ui"(effects, duration) {
    return healthUtil.checkWebUrl("http://dojo.embassy:9000")(effects, duration)
      .catch(healthUtil.catchError(effects))
  },
  async "api"(effects, duration) {
    return healthUtil.checkWebUrl("http://dojo.embassy:8080")(effects, duration)
      .then(healthUtil.checkWebUrl("http://dojo.embassy:8081")(effects, duration))
      .then(healthUtil.checkWebUrl("http://dojo.embassy:8082")(effects, duration))
      .catch(healthUtil.catchError(effects))
  },
};