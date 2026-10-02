import React from "react";
import { Composition } from "remotion";
import { BurgerProfVideo, videoSchema } from "./Video";
import { DURATION, FPS, HEIGHT, WIDTH } from "./theme";

export const RemotionRoot: React.FC = () => (
  <Composition
    id="BurgerProfKarakterek"
    component={BurgerProfVideo}
    schema={videoSchema}
    durationInFrames={DURATION}
    fps={FPS}
    width={WIDTH}
    height={HEIGHT}
    defaultProps={{ showSafeZone: false, textOnly: false }}
  />
);
