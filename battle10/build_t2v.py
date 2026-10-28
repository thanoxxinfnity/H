import csv, json
STYLE = "Hand-drawn 2D anime, ink linework, cel shading, painted background, film grain, dynamic anime camera, no text."
SET = "Ruined floating-island city at dusk, broken stone bridges, drifting ash, huge pale moon."
ARAN = "ARAN: broad-shouldered warrior, short black hair with a gold streak, scar on left cheek, long dark-green coat with silver shoulder plates, long straight sword with a blue glowing blade."
VORTH = "VORTH: slim sorcerer, long crimson hair, pale skin, black high-collar robe with red runes, four red blades floating around him."
S = [
# ACT I - ARRIVAL
("I","A","Wide crane shot over the broken bridges of the floating-island city. ARAN walks alone along a cracked bridge toward the camera, sword on his shoulder, coat blowing in the wind. Camera drops to a low-angle in front of him, calm and confident."),
("I","A","360-degree orbit around ARAN as he stops at the centre of the bridge. He lowers the sword point to the stones, closes his eyes for a moment, then opens them with a quiet smile. Slow push-in on his scarred face, an ember drifting past."),
("I","V","Low-angle shot of VORTH standing on a broken tower far across the gap, the four red blades slowly circling him. His crimson hair streams in the wind. He looks down at ARAN with a bored, curious expression."),
("I","AV","Wide shot: ARAN and VORTH face each other across a collapsed bridge gap, a hundred metres of air between them. Silent stare-down, ash drifting through the frame, the pale moon behind. Slow push-in on both."),
("I","V","VORTH lifts one finger; the four red blades stop spinning and point at ARAN. A thin smile. Extreme close-up on his red eyes, then a quick snap zoom to the tips of the blades glowing."),
("I","A","ARAN rests the blue blade on his shoulder, grins, and gestures with two fingers for VORTH to come. Close-up on the blue glow running up the blade, cracks of light on the stone below his boots."),
("I","AV","VORTH launches the four red blades; ARAN sprints along the bridge, blades slamming into the stones behind him one by one in red explosions. Fast tracking shot beside ARAN, debris flying."),
("I","AV","ARAN leaps across the gap in slow motion, the blue blade swinging; VORTH meets him mid-air with all four red blades. A huge clash, blue and red flash, impact frame, both thrown back to opposite towers."),
# ACT II - DUEL
("II","AV","ARAN lands on VORTH's tower and slashes; VORTH steps back and catches the blade between two red blades, sparks fly. Fast exchange of cuts and parries, whip pans, stone dust bursting around their feet."),
("II","AV","360-degree orbit around the two locked in a blade struggle on the tower top, faces inches apart. VORTH whispers something and smiles; ARAN answers with a headbutt and a kick that sends him sliding back."),
("II","V","VORTH wipes blood from his lip and laughs. The four red blades merge into one huge crimson sword. He swings it once, a red wave of light sweeping across the whole tower. Low-angle slow motion."),
("II","A","ARAN raises the blue blade and cuts the crimson wave in half; the two halves slide past him and slice through the neighbouring towers. His coat is torn at the shoulder, he exhales and steadies himself."),
("II","AV","The towers begin to collapse. ARAN and VORTH leap between falling stones, trading strikes in mid-air, the camera spinning around them. Debris, dust, glints of blue and red steel."),
("II","AV","They crash onto a wide bridge. VORTH drives ARAN back with a rain of red strikes; ARAN blocks every one with his blade, feet sliding, sparks lighting his face. Camera pushes in tight on the clashing steel."),
("II","A","ARAN suddenly stops blocking and steps forward into a strike, taking it on his shoulder armour. Close-up of his smile as he swings upward in a rising blue arc. Slow motion, blue light trails."),
("II","V","The blue arc cuts VORTH's cheek and the long crimson hair is severed at one side. His eyes widen, then narrow with rage. He touches the cut, looks at the blood, and the air around him turns dark red."),
# ACT III - THE RED MOON
("III","V","VORTH raises both hands; the pale moon turns blood red. Red runes spread across the sky like cracks in glass. He floats upward, robe rippling, red blades circling. Wide low-angle shot, epic scale."),
("III","AV","A red dome of light closes over the floating island, sealing it. ARAN turns, runs to the edge, and strikes the dome with his blade; it flashes and holds. He looks back at VORTH, who smiles. Slow push-in."),
("III","A","Inside the red dome, ARAN's blue glow dims; the red light drains it from his blade. Close-up of his hand shaking on the hilt, sweat on his scarred face. Slow motion, heartbeat feel, red embers floating."),
("III","V","VORTH drifts down and speaks softly in the red light, the blades slowly spinning around his shoulders. Close-up on his face, smirk, then a shot of the blades turning to point at ARAN's heart."),
("III","AV","The four red blades fly at ARAN from four directions. He spins and parries three, the fourth pierces his left arm. Impact frame, red spray, ARAN grits his teeth and rips the blade out. Fast whip pans."),
("III","A","ARAN kneels on one knee, left arm bleeding, breathing hard. Flashback montage in warm watercolor: a younger ARAN laughing with two friends and a little girl on a sunny hillside. Soft golden light, slow dissolves."),
("III","A","Flashback turns grey: the same hillside burned, the friends gone, ARAN standing alone in ash holding the blue blade. Cut back to the present: ARAN's eyes open, a faint blue light rekindles in the blade. Slow push-in."),
("III","AV","ARAN rises, the blue glow growing against the red dome, a column of blue light shooting to the sky. VORTH steps back, surprised. Low-angle, 360-degree orbit around ARAN as blue and red energy collide around him."),
# ACT IV - THE STAND
("IV","A","ARAN plants the sword in the stones and the blue light spreads across the bridge like water, pushing back the red glow. Overhead shot of the blue ripple expanding across the whole floating city, cracks of light in the dome."),
("IV","AV","The red dome shatters like glass, shards falling in slow motion as the moon returns to pale white. VORTH shields his face, the four blades pulled out of orbit. ARAN walks forward through the falling shards."),
("IV","V","VORTH smiles through the shock, lowers his arm, and calls the four red blades back; they merge into one huge crimson sword. His robe turns to ash, revealing a black battle armour with red lines. Close-ups on his face and hands."),
("IV","AV","They charge each other across the bridge. Slow-motion clash: blue blade against crimson sword, the shockwave tearing the bridge apart. 360-degree orbit around the impact, stone fragments hanging in the air."),
("IV","AV","Fast final-style exchange: ARAN and VORTH cut through the air in streaks, only trails of blue and red visible, the camera cutting between close-ups of their eyes and their blades. Impact frames, sparks, a roar of wind."),
("IV","V","VORTH breaks the rhythm, steps inside ARAN's guard and drives the crimson sword through ARAN's side. Close-up of both faces, ARAN's eyes wide, VORTH's calm. Held pose, dust slowly settling around them."),
("IV","A","ARAN grabs the crimson blade with his bare hand, blood running down it, and pulls himself closer to VORTH. A faint smile. Extreme close-up on his hand on the blade, blue light flaring through the blood."),
("IV","AV","ARAN headbutts VORTH and slams his blue blade through the crimson sword, shattering it into red shards. Both are thrown back across the bridge. Slow motion, shards of red and blue light spinning in the air."),
# ACT V - THE END
("V","V","VORTH rises from the rubble, armour cracked, one eye bleeding red. He laughs with a shaken voice and raises both hands: the shattered red shards fly back and form a spear of crimson light above him. Low-angle, slow."),
("V","A","ARAN stands, bleeding from side and arm, holds the blue blade with both hands. The whole blade ignites with blue fire, the light wrapping his body. He whispers a farewell. Close-up on his scarred face, calm acceptance."),
("V","AV","The two charge for the last time: crimson spear against blue blade across the broken bridge. 360-degree orbit in extreme slow motion as the weapons meet, a sphere of blue and red light forming at the point of impact."),
("V","AV","White-out; then silence. The light fades: VORTH's spear is shattered and ARAN's blade has passed through VORTH's chest. VORTH looks down, smiles with something like respect, and falls to dust in the wind."),
("V","A","ARAN stands alone, then staggers. The crimson spear fragment has pierced his chest from behind; he looks down at it, then up at the pale moon with a calm smile. The blue blade slips from his hand and clatters on the stones."),
("V","A","Slow push-in on ARAN as he falls to his knees on the bridge, the scarred face peaceful, blue light from his coat fading. Camera lifts slowly away, wide shot of the broken floating city and the lone figure small in the middle."),
("V","A","ARAN falls onto his back, eyes on the sky as dawn breaks, warm orange light touching the clouds. His last breath leaves in a cloud of drifting blue embers. Close-up of his face, eyes closing slowly. Held pose, ash falling."),
("V","A","Wide pull-out: the lone sword standing upright in the broken bridge, the green coat lying still beside it, golden dawn rising over the ruined floating city. The blue glow of the blade fades out. Slow fade to black. THE END."),
]
assert len(S) == 40, len(S)
ACT = {"I":"Arrival","II":"The duel","III":"The red moon","IV":"The stand","V":"The end"}
rows = []
for i, (act, who, scene) in enumerate(S, 1):
    chars = {"A": ARAN, "V": VORTH, "AV": ARAN + " " + VORTH}[who]
    prompt = f"{STYLE} {SET} {chars} {scene}"
    t0 = (i-1)*15; t1 = i*15
    rows.append(dict(clip=i, act=act, start=f"{t0//60}:{t0%60:02d}", end=f"{t1//60}:{t1%60:02d}", chars=len(prompt), prompt=prompt))
print("max chars:", max(r["chars"] for r in rows), "| over 800:", [(r["clip"], r["chars"]) for r in rows if r["chars"] > 800])
with open("t2v_prompts.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=["clip","act","start","end","chars","prompt"]); w.writeheader(); w.writerows(rows)
md = ["# 10-MINUTE ANIME BATTLE - TEXT-TO-VIDEO - 40 CLIPS x 15 s (original: ARAN vs VORTH)\n",
 "For **Triverse Studio > Video > Prompt** tab (text-to-video, no first frame). Every prompt is self-contained (style + setting + character descriptions + scene) and under 800 characters. The story ends with ARAN's death; nothing is shown after it.\n",
 "## Credits\n- 480P / 15 s = **75 credits** per clip (check the Generate button, text-to-video may differ). All 40 clips = **3,000 credits**; with 1,030 credits do clips **1-13 (0:00-3:15)** first, in order.\n- Credits are shared with 3D tasks on the same account.\n",
 "## Tips for text-to-video\n1. Paste the prompt exactly as written. The character descriptions at the start of each prompt must stay identical, that is what keeps ARAN and VORTH looking the same from clip to clip.\n2. Settings: Prompt tab, 480P, 15S, Sound Effects **off**.\n3. Text-to-video has no first frame, so the look can drift a little between clips. If a clip comes out wrong (wrong hair or coat colour), just regenerate that one clip with the same prompt.\n4. For better continuity use the **Image** tab (see `PROMPTS_40_CLIPS.md`) and chain last frames; use this pack when you want to start every clip fresh.\n5. Download as `t2v_clip_01.mp4` ... `t2v_clip_40.mp4` and send them; I will merge, add the AI disclaimer intro, and upscale.\n",
 "## Story (5 acts, 2:30 each)\n" + "\n".join(f"- **Act {a}** (clips {min(r['clip'] for r in rows if r['act']==a)}-{max(r['clip'] for r in rows if r['act']==a)}): {n}" for a, n in ACT.items()) + "\n",
 "## The 40 prompts (also in `t2v_prompts.csv`)\n"]
for r in rows:
    md.append(f"### CLIP {r['clip']:02d}  ({r['start']} - {r['end']})  - Act {r['act']} - {r['chars']} chars\n```\n{r['prompt']}\n```\n")
open("T2V_40_CLIPS.md", "w", encoding="utf-8").write("\n".join(md))
print("written", len(rows))
