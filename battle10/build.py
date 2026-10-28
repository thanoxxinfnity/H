import csv, json
STYLE = "Hand-drawn 2D anime, ink linework, cel shading, painted background, film grain, dynamic anime camera, no text."
KAI = "KAI: silver messy hair, amber eyes, long red scarf, black gold-trim coat, plain katana."
MORO = "MORO: tall, white half-mask, long violet robe, glowing violet eyes, floating ring-staff."
SET = "Ruined mountain temple city at dusk, huge cracked moon, drifting ash."
# (act, who, scene)  who: K, M, KM
S = [
# ACT I - ARRIVAL AND FIRST CLASH
("I","K","Wide crane shot down onto the ruined temple city. KAI climbs the broken stairs, scarf blowing, hand on his sheath. Camera drops to a low-angle in front of him, wind and ash, calm and ominous."),
("I","K","360-degree orbit around KAI at the top step as he stops and looks up, amber eyes narrowing, scarf lifting. Slow push-in on his face, a single ember drifting past."),
("I","M","Low-angle shot of MORO standing on a collapsed pillar, ring-staff floating beside him, violet eyes glowing under the mask. Robe moves in the wind. He tilts his head with quiet amusement."),
("I","KM","Silent stare-down across the broken courtyard. Slow push-in on both faces, embers between them, the huge cracked moon behind. Snap zoom to KAI's thumb pushing the katana guard open, then to MORO's eyes."),
("I","KM","KAI dashes in a smear frame, MORO's staff blocks with a ring of violet light, impact flash, stone dust bursts. Fast sword-versus-staff exchange with whip pans, sparks, KAI sliding back across the stones."),
("I","KM","MORO spins the ring-staff, violet shockwaves crack the ground in a line. KAI leaps over them in slow motion, rolls, and counters with a rising slash. Camera tracks low along the cracks."),
("I","KM","360-degree orbit around the two locked in a blade-and-staff struggle, faces inches apart, sparks flying. They shove apart; MORO glides back across the air on a violet disc, KAI skids to a stop."),
("I","K","KAI draws and slashes: a silver crescent of light cuts through a stone pillar, the top slides off and crashes. Slow motion on the falling stone, dust rolling toward the camera."),
# ACT II - POWERS ESCALATE
("II","M","MORO calmly steps aside as the crescent passes him; a small crack opens on his mask. He laughs softly, then raises his hand and five violet orbs begin circling him. Dutch angle, violet glow."),
("II","KM","The five orbs launch at KAI like missiles. KAI runs along a broken wall, orbs exploding behind him one by one in fire and dust. Fast tracking shot racing alongside him."),
("II","KM","KAI spins and cuts two orbs out of the air, the rest hit him and throw him through a stone archway. Impact frame, debris, camera whips to follow him into the rubble."),
("II","K","KAI lies in rubble, scarf torn, breathing hard. Extreme close-up of his hand tightening on the sword. Heartbeat held pose, embers falling slowly across the frame."),
("II","M","MORO walks toward KAI across the courtyard, the staff trailing violet light on the stones. Low camera behind his feet, then rising to a high-angle shot over the ruins as he towers over the fallen swordsman."),
("II","KM","KAI rolls aside as the staff slams the ground, a violet explosion blasts the stones. He springs up and trades fast strikes with MORO, each clash a ring of violet and silver light, whip pans."),
("II","KM","360-degree orbit as they fight on a crumbling bridge over a dark gorge. Planks fall away, KAI jumps to a floating slab, MORO follows on his violet disc, blades and staff flashing in the moonlight."),
("II","KM","MORO's staff catches KAI and slams him down; the bridge collapses. KAI falls through the dark gorge, reaching up toward the cracked moon, MORO's silhouette shrinking above him. Slow motion."),
# ACT III - FLASHBACK AND AWAKENING
("III","K","Soft watercolor flashback at dawn: a young KAI, scarf too long for him, practices sword swings in a mountain meadow while an old master watches and smiles. Warm golden light, gentle breeze, slow pan."),
("III","K","Flashback: the old master hands the young KAI a plain katana, ties the red scarf around his neck and says something quiet. Close-ups of their hands and smiles. Warm light, soft focus, petals drifting."),
("III","K","Flashback turns cold: the same temple city under a violet sky, the old master falling before a distant masked figure. Young KAI reaching out, held pose, color drains to grey. Sharp cut to black."),
("III","K","Back to the gorge: KAI lands on a ledge, his amber eyes snap open. A faint silver aura rises around the katana, the red scarf lifting as if in a rising wind. Slow push-in, a heartbeat sound feel."),
("III","K","KAI climbs the gorge wall in a fast montage: hand, boot, hand, silver light trailing from his sword. Crane shot up the cliff toward the cracked moon, rock fragments floating upward around him."),
("III","KM","KAI bursts over the cliff edge in a silver streak and lands in front of MORO. MORO's staff slows for the first time. Low-angle shot of KAI rising, aura swirling, rubble floating up around him in a ring."),
("III","KM","360-degree orbit around KAI and MORO as KAI vanishes in speed lines and reappears behind MORO. A flurry of slashes in a fast montage of impact frames, silver arcs filling the screen."),
("III","M","MORO blocks the last slash, his staff cracks and violet energy leaks out. He staggers, then steadies, raising both arms. The mask's crack widens. Slow push-in on his glowing violet eyes."),
# ACT IV - THE RING OF THE SKY
("IV","M","MORO raises the ring-staff to the sky. It grows into a giant violet ring behind him; the sky turns deep violet and the moon turns blood red. Ash rises in a spiral. Low-angle shot, epic scale."),
("IV","KM","Wide shot: the giant ring slowly descends toward the city like a guillotine, KAI tiny in the frame, wind howling, stones lifting. Slow pull-back, violet light washing across the ruins."),
("IV","K","KAI sheathes his sword and closes his eyes, one calm breath. Total silence for a held moment, embers frozen in the air, the red scarf perfectly still. Extreme close-up on his closed eyes."),
("IV","K","KAI opens his eyes and draws in one motion, a huge silver crescent bursts out. 360-degree orbit in slow motion around the sword arc, the sparks and dust hanging in the air."),
("IV","KM","The silver crescent meets the violet ring: a colossal clash, white-out, a shockwave tears the clouds apart. Camera shakes violently, whip pan across the ruins as stones fly outward."),
("IV","KM","The ring cracks like glass, shards of violet light spray in all directions. MORO shields his face with his arm as the shards pass him. KAI pushes forward through the flying shards, scarf streaming."),
("IV","KM","KAI's crescent breaks through, slices the ring-staff in two, and cuts MORO's mask in half. Slow motion as the pieces of the mask fall and spin. Close-up on MORO's unmasked, calm face."),
("IV","M","MORO, unmasked, stands calm among the falling violet shards. A faint peaceful smile. He looks up at the red moon, then back at KAI, nodding once. Slow push-in on his face, violet light fading to gold."),
# ACT V - FINAL CLASH AND DAWN
("V","KM","MORO's calm turns to fierce resolve. He throws the broken staff halves like blades, each trailing violet light. KAI deflects both and charges, camera tracking at ground level, dust trails behind them."),
("V","KM","Final duel on the broken stairs: KAI and MORO trade fast sword-and-fist strikes, every clash a flash of silver and violet. 360-degree orbit, speed lines, impact frames on the heaviest hits."),
("V","KM","MORO grabs KAI's blade with his bare hand, violet energy flaring around it. KAI pulls his scarf off in one move, wraps the blade, and twists free. Slow motion, close-ups of hands and eyes."),
("V","K","KAI leaps high in front of the red moon, silhouetted, katana raised with both hands, silver aura blazing. Slow motion at the top of the jump, scarf unwinding behind him, one ember glowing at the blade tip."),
("V","KM","KAI comes down in a single huge slash. MORO opens his arms and takes the cut. A silver flash, white-out, then slow-motion dust. Camera pulls out wide as the shockwave rolls across the whole ruined city."),
("V","M","MORO kneels, unharmed in body but his violet robe turning to petals that drift upward. He smiles gently, whispers silently, and slowly fades into drifting violet petals. Close-up on his face, then on the petals rising."),
("V","K","KAI sinks to one knee, exhausted, katana planted in the stones. The red moon fades to a pale white. Slow push-in on his tired face, the first thin line of dawn light touching his silver hair."),
("V","K","Dawn breaks over the ruins in warm orange light. KAI walks down the broken stairs, scarf fluttering, the cracked moon fading. Slow pull-out to a wide shot of the temple city small behind him. Fade to white."),
]
assert len(S) == 40, len(S)
ACT = {"I":"Arrival and first clash","II":"Powers escalate","III":"Flashback and awakening","IV":"The ring of the sky","V":"Final clash and dawn"}
rows = []
for i, (act, who, scene) in enumerate(S, 1):
    chars = {"K": KAI, "M": MORO, "KM": KAI + " " + MORO}[who]
    prompt = f"{STYLE} {SET} {chars} {scene}"
    t0 = (i - 1) * 15; t1 = i * 15
    rows.append(dict(clip=i, act=act, start=f"{t0//60}:{t0%60:02d}", end=f"{t1//60}:{t1%60:02d}", chars=len(prompt), prompt=prompt))
bad = [r for r in rows if r["chars"] > 800]
print("max chars:", max(r["chars"] for r in rows), "| over 800:", [(r["clip"], r["chars"]) for r in bad])
json.dump(rows, open("prompts.json", "w"), indent=1, ensure_ascii=False)
with open("prompts.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=["clip", "act", "start", "end", "chars", "prompt"]); w.writeheader(); w.writerows(rows)
md = ["# 10-MINUTE ANIME BATTLE - 40 CLIPS x 15 s (original characters: KAI vs MORO)\n",
 "Made for **Triverse Studio > Video** (prompt limit 800 chars, 480P, 15 s = 75 credits per clip). Every prompt below is already under 800 characters and self-contained: style + setting + characters + scene.\n",
 "## Credits\n- 480P / 15 s = **75 credits** per clip -> all 40 clips = **3,000 credits**.\n- You have **1,030 credits** -> **13 clips (0:00-3:15)** now. Do clips in order, 1 to 13, then continue when you top up.\n- Credits are shared with 3D tasks on the same account, so don't spend them on 3D in between.\n",
 "## How to chain clips (so KAI and MORO do not change look)\n1. Clip 1: first, make a start image in Triverse **Image** with the *Start image prompt* below (or any image of this design).\n2. Open Video > **Image** tab, load the start image as *First Frame*, paste the clip prompt, 480P, **15S**, Sound Effects **off**, Generate.\n3. For clip N+1: save the **last frame** of clip N (screenshot / export) and use it as the *First Frame*. Optional: use *Add End Frame* when a scene must end in a known pose.\n4. Name every download `clip_01.mp4` ... `clip_40.mp4`. If a clip drifts (wrong hair/costume), regenerate only that clip.\n",
 "## Start image prompt (clip 1)\n```\nHand-drawn 2D anime key art, ink linework, painted background. A young swordsman with messy silver hair, amber eyes, a long red scarf and a black gold-trim coat, a plain katana on his back, climbing broken stone stairs of a ruined mountain temple city at dusk, a huge cracked moon behind, drifting ash. Wide shot.\n```\n",
 "## Reference portrait prompts (optional, for consistency)\n```\nKAI portrait: hand-drawn 2D anime, silver messy hair, amber eyes, long red scarf, black coat with gold trim, plain katana, calm determined face.\nMORO portrait: hand-drawn 2D anime, tall man, white porcelain half-mask, long violet robe, glowing violet eyes, pale hair tied back, floating ring-shaped staff.\n```\n",
 "## Story in 5 acts (2:30 each)\n" + "\n".join(f"- **Act {a}** (clips {min(r['clip'] for r in rows if r['act']==a)}-{max(r['clip'] for r in rows if r['act']==a)}): {n}" for a, n in ACT.items()) + "\n",
 "## The 40 prompts\nAlso saved as `prompts.csv` and `prompts.json` (same folder).\n"]
for r in rows:
    md.append(f"### CLIP {r['clip']:02d}  ({r['start']} - {r['end']})  - Act {r['act']} - {r['chars']} chars\n```\n{r['prompt']}\n```\n")
open("PROMPTS_40_CLIPS.md", "w", encoding="utf-8").write("\n".join(md))
print("written", len(rows))
