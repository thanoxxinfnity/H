"""Drive the Colab Gradio server: generate every clip from the agent prompt file.

usage: python client.py <public gradio.live URL> <start_image> [first_clip] [last_clip]
Each 10 s clip = 2 chained 5 s segments (second one starts from the first one's last frame).
Output: out/clip_NN_a.mp4, clip_NN_b.mp4 -> merged to clip_NN.mp4
"""
import re, sys, os, subprocess, shutil
from gradio_client import Client, handle_file

url, start_img = sys.argv[1], sys.argv[2]
lo = int(sys.argv[3]) if len(sys.argv) > 3 else 1
hi = int(sys.argv[4]) if len(sys.argv) > 4 else 30
src = os.path.join(os.path.dirname(__file__), "..", "gojo_vs_sukuna_agent_prompt.md")
text = open(src, encoding="utf-8").read()
prompts = {int(n): p.strip() for n, p in re.findall(r"--- CLIP (\d+) \([^)]*\) --- (.+)", text)}
STYLE = ("hand-drawn 2D anime cel animation, ink linework, painted background, film grain, "
         "dynamic anime camera, ruined Shinjuku at dusk, Gojo (white spiky hair, black blindfold, "
         "black uniform) vs Sukuna (black spiky hair, face markings, dark uniform). ")
c = Client(url)
os.makedirs("out", exist_ok=True)
frame = start_img
for n in range(lo, hi + 1):
    segs = []
    for part, tag in enumerate("ab"):
        video, last = c.predict(handle_file(frame), STYLE + prompts[n], 121, 40, n * 10 + part,
                                api_name="/generate")
        v = f"out/clip_{n:02d}_{tag}.mp4"; shutil.copy(video if isinstance(video, str) else video["video"], v)
        frame = last if isinstance(last, str) else last["path"]
        segs.append(v)
    with open(f"out/c{n}.txt", "w") as f:
        f.writelines(f"file '{os.path.abspath(s)}'\n" for s in segs)
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", f"out/c{n}.txt",
                    "-c", "copy", f"out/clip_{n:02d}.mp4"], check=True)
    print("done clip", n, flush=True)
