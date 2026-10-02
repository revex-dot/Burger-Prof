import React from "react";
import { AbsoluteFill, Sequence } from "remotion";
import { z } from "zod";
import { BurgerBlock, Hook, Payoff } from "./components/blocks";
import { SafeZone } from "./components/SafeZone";
import { BLACK } from "./theme";

export const videoSchema = z.object({
  /** Reels biztonsági zóna overlay (csak előnézethez). */
  showSafeZone: z.boolean(),
  /** Ellenőrző mód: fekete alap, fotó nélkül – csak a szöveg marad (zóna-mérés). */
  textOnly: z.boolean(),
});
export type VideoProps = z.infer<typeof videoSchema>;

// Blokkhatárok (frame). A blokkok közti 2 frame-et a fekete alap adja: 28–29, 133–134, 238–239, 343–344.
const BLOCK = 103;

export const BurgerProfVideo: React.FC<VideoProps> = ({ showSafeZone, textOnly }) => (
  <AbsoluteFill style={{ backgroundColor: BLACK }}>
    <Sequence durationInFrames={28} name="Hook">
      <Hook textOnly={textOnly} />
    </Sequence>
    <Sequence from={30} durationInFrames={BLOCK} name="Classic">
      <BurgerBlock id="classic" copyAt={30} copy={["Ketchup, mustár, gyerekkor.", "Nem kell megfejteni."]} textOnly={textOnly} />
    </Sequence>
    <Sequence from={135} durationInFrames={BLOCK} name="Prof">
      <BurgerBlock id="prof" copyAt={30} copy={["Évek. Sok száz sütés.", "Pisti életműve."]} textOnly={textOnly} />
    </Sequence>
    <Sequence from={240} durationInFrames={BLOCK} name="Genius">
      <BurgerBlock id="genius" copyAt={30} copy={["Málna. Bacon. Füst.", "A nyitás napján, fejből."]} textOnly={textOnly} />
    </Sequence>
    <Sequence from={345} durationInFrames={105} name="Payoff">
      <Payoff textOnly={textOnly} />
    </Sequence>
    {showSafeZone && <SafeZone />}
  </AbsoluteFill>
);
