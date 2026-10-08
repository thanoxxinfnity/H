# ANIME PROMPT PACK - 30 scenes (original characters, hand-drawn anime look)

Model-agnostic: paste per scene into any video model. Story = one complete anime duel with
ORIGINAL characters, so every scene can be reused freely.
Each scene is 5-10 s. Change `{CLIP_LEN}` for your model.

## 1) GLOBAL STYLE BLOCK (prepend to every scene)

```
Traditional hand-drawn 2D anime, cel animation, clean ink linework with slight line wobble,
animated on twos (12 drawn fps), flat cel shading with hard-edged shadows, painterly
gouache backgrounds with paper grain, film grain, subtle gate weave. Smear frames and
single-frame impact flashes on hits, speed lines, strong sakuga on action, held poses on
emotion. Dynamic anime camera. Cinematic dusk lighting. No text, no logos, no watermark.
```

## 2) NEGATIVE PROMPT (if your model supports it)

```
3D render, CGI, photorealistic, live action, glossy plastic skin, western cartoon, chibi,
blurry, extra limbs, extra fingers, deformed face, inconsistent character design, text,
subtitles, watermark, logo, flickering, low quality
```

## 3) CHARACTER SHEET (repeat the line for every scene they appear in)

```
KAI: young swordsman, messy silver hair, sharp amber eyes, long red scarf, black high-collar
coat with gold trim, a plain katana in a black sheath on his back.
MORO: tall masked sorcerer, long dark violet robe, white porcelain half-mask, glowing violet
eyes, pale long hair tied back, ring-shaped staff that floats beside him.
SETTING: ruined mountain-top temple city at dusk, broken stone stairs, floating ash and
embers, orange-purple sky, huge cracked moon.
```

## 4) CAMERA WORDS THAT WORK
`slow push-in` · `whip pan` · `snap zoom on eyes` · `low-angle hero shot` · `high crane shot` ·
`dutch angle` · `slow-motion hold` · `360-degree orbit around the characters, background
rotating with painted parallax` · `fast tracking shot` · `rack focus` · `impact frame`

## 5) THE 30 SCENES

1. Wide crane shot down onto the ruined temple city at dusk, ash drifting. KAI climbs the broken stairs, scarf blowing, hand resting on his sheath.
2. [360 orbit] Camera circles KAI as he stops at the top step and looks up, amber eyes narrowing, wind lifting his scarf.
3. Low-angle shot of MORO standing on a collapsed pillar, floating ring-staff beside him, violet eyes glowing under the mask.
4. Slow push-in on both faces, a silent stare-down, embers drifting between them, moon behind.
5. Close-up of KAI's thumb pushing the katana's guard open one inch, soft metallic click. Snap zoom to MORO's eyes.
6. KAI dashes forward in a smear frame, MORO's staff blocks with a ring of violet light, impact flash, stone dust bursts outward.
7. Fast sword-versus-staff exchange, sparks, whip pans between strikes, KAI pushed back sliding across the stones.
8. MORO raises one hand, ring-staff spins, violet shockwaves crack the ground, KAI leaps over them in slow motion.
9. [360 orbit] KAI mid-air, silhouetted against the huge cracked moon, drawing the katana, steel flashing.
10. KAI lands and slashes; a crescent of silver light cuts through a pillar, the top slides off and crashes down.
11. MORO calmly steps aside, the crescent passes him, a small cut opens on his mask. His eyes widen, then he laughs softly.
12. MORO summons five floating violet orbs that circle him, then launch at KAI like missiles, fast tracking shot.
13. KAI runs along a broken wall, orbs exploding behind him one by one, dust and fire, camera racing alongside.
14. KAI spins and cuts two orbs out of the air, the others hit him, he is thrown through a stone archway. Impact frame.
15. KAI lies in rubble, scarf torn, breathing hard. Close-up on his hand tightening on the sword. Heartbeat held pose.
16. Flashback, soft watercolor tones: a young KAI training at dawn with an old master, both laughing, warm light.
17. Back to the present, KAI's eyes open, the amber glows brighter, a faint silver aura rises around the blade.
18. MORO hesitates for the first time, staff slowing, as silver light climbs up KAI's arm. Slow push-in on MORO's mask.
19. [360 orbit] KAI stands, aura swirling, rubble floating up around him in a ring of silver wind.
20. KAI vanishes in a speed-line streak and appears behind MORO, a flurry of slashes in a fast montage of impact frames.
21. MORO blocks the last slash, his staff cracks, violet energy leaks out. He raises both arms to the sky.
22. The ring-staff expands into a giant violet ring behind MORO, the sky turns dark violet, the moon turns blood red.
23. Wide shot: giant ring lowers like a guillotine toward the city, KAI small in the frame, wind howling.
24. KAI sheaths his sword, closes his eyes, one breath. Total silence for a held moment, embers frozen in the air.
25. [360 orbit] KAI opens his eyes, draws in one motion, a huge silver crescent bursts out, slow motion.
26. The silver crescent meets the violet ring, a colossal clash, white-out, shockwave tears the clouds apart.
27. The ring cracks like glass, shards of violet light spray in all directions, MORO shields his face.
28. The crescent breaks through, slices the staff, and cuts MORO's mask in half. Slow motion as the pieces fall.
29. MORO, unmasked and calm, smiles, kneels, and fades into drifting violet petals. KAI lowers his blade, exhausted.
30. Dawn breaks over the ruins, warm orange light. KAI walks down the stairs, scarf fluttering, the cracked moon fading. Slow pull-out, fade to white.

## 6) HOW TO USE IT FOR A MODEL / PIPELINE
- Build each prompt as: `GLOBAL STYLE BLOCK` + `CHARACTER SHEET lines for that scene` + `scene text`.
- Keep the character sheet text IDENTICAL across scenes, so character design stays consistent.
- Use the last frame of scene N as the first frame of scene N+1 when your model supports image-to-video.
- Save every clip with its exact prompt (same filename, `.txt`) if you plan to use the data later.
