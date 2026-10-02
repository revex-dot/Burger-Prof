/**
 * Note: When using the Node.JS APIs, the config file
 * doesn't apply. Instead, pass options directly to the APIs.
 *
 * All configuration options: https://remotion.dev/docs/config
 */

import { Config } from "@remotion/cli/config";

Config.setRspack(true);
// PNG köztes frame-ek: a JPEG eltolná a lemintázott narancsot.
Config.setVideoImageFormat("png");
Config.setOverwriteOutput(true);
Config.setCodec("h264");
Config.setCrf(18);
Config.setPixelFormat("yuv420p");
Config.setColorSpace("bt709");

// Ha a Remotion nem tudja letölteni a saját headless Chromiumát (zárt hálózat),
// egy helyben telepített böngésző adható meg: REMOTION_BROWSER=/path/to/headless_shell
if (process.env.REMOTION_BROWSER) {
  Config.setBrowserExecutable(process.env.REMOTION_BROWSER);
}
