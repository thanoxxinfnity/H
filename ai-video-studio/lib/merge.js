/* Concatenates clips in the browser with ffmpeg.wasm (single-thread core, no special headers needed).
   Loaded from a CDN as UMD builds so Next.js does not have to bundle the worker. */
const FF_BASE = "https://cdn.jsdelivr.net/npm/@ffmpeg/ffmpeg@0.12.10/dist/umd";
const UTIL_URL = "https://cdn.jsdelivr.net/npm/@ffmpeg/util@0.12.1/dist/umd/index.js";
const CORE_BASE = "https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.6/dist/umd";

function loadScript(src, globalName) {
  return new Promise((resolve, reject) => {
    if (window[globalName]) return resolve(window[globalName]);
    const s = document.createElement("script");
    s.src = src; s.async = true;
    s.onload = () => (window[globalName] ? resolve(window[globalName]) : reject(new Error(`${globalName} missing after load`)));
    s.onerror = () => reject(new Error(`Could not load ${src}`));
    document.head.appendChild(s);
  });
}

let ffmpegP;
async function getFFmpeg(onLog) {
  if (!ffmpegP) ffmpegP = (async () => {
    const [{ FFmpeg }, util] = await Promise.all([loadScript(`${FF_BASE}/ffmpeg.js`, "FFmpegWASM"), loadScript(UTIL_URL, "FFmpegUtil")]);
    const ff = new FFmpeg();
    ff.on("log", ({ message }) => onLog?.(message));
    await ff.load({
      classWorkerURL: await util.toBlobURL(`${FF_BASE}/814.ffmpeg.js`, "text/javascript"),
      coreURL: await util.toBlobURL(`${CORE_BASE}/ffmpeg-core.js`, "text/javascript"),
      wasmURL: await util.toBlobURL(`${CORE_BASE}/ffmpeg-core.wasm`, "application/wasm"),
    });
    return { ff, util };
  })().catch((e) => { ffmpegP = undefined; throw e; });
  return ffmpegP;
}

/** blobs: array of video Blobs in order. Returns one mp4 Blob. */
export async function mergeVideos(blobs, { onProgress, onLog } = {}) {
  if (!blobs.length) throw new Error("Nothing to merge");
  if (blobs.length === 1) return blobs[0];
  const { ff, util } = await getFFmpeg(onLog);
  const progress = ({ progress: p }) => onProgress?.(Math.max(0, Math.min(1, p)));
  ff.on("progress", progress);
  const names = [];
  try {
    for (let i = 0; i < blobs.length; i++) {
      const n = `in${i}.mp4`; names.push(n);
      await ff.writeFile(n, await util.fetchFile(blobs[i]));
    }
    await ff.writeFile("list.txt", names.map((n) => `file '${n}'`).join("\n"));
    let code = await ff.exec(["-f", "concat", "-safe", "0", "-i", "list.txt", "-c", "copy", "-movflags", "+faststart", "out.mp4"]);
    let ok = code === 0;
    if (ok) { const d = await ff.readFile("out.mp4"); ok = d.length > 1000; }
    if (!ok) { // clips differ in codec/size: re-encode to be safe
      code = await ff.exec(["-f", "concat", "-safe", "0", "-i", "list.txt", "-c:v", "libx264", "-preset", "veryfast", "-crf", "23", "-pix_fmt", "yuv420p", "-c:a", "aac", "-movflags", "+faststart", "out.mp4"]);
      if (code !== 0) throw new Error("ffmpeg could not merge these clips");
    }
    const data = await ff.readFile("out.mp4");
    return new Blob([data.buffer], { type: "video/mp4" });
  } finally {
    ff.off("progress", progress);
    for (const n of [...names, "list.txt", "out.mp4"]) { try { await ff.deleteFile(n); } catch {} }
  }
}
