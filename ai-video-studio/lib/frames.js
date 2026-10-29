/** Browser-side image helpers: downscale photos before upload, grab the last frame of a clip. */
export async function prepareImage(file, maxSide = 1536) {
  try {
    const bmp = await createImageBitmap(file);
    const k = Math.min(1, maxSide / Math.max(bmp.width, bmp.height));
    if (k === 1 && file.size < 4 * 1024 * 1024 && /^image\/(jpeg|png|webp)$/.test(file.type)) { bmp.close?.(); return { blob: file, w: bmp.width, h: bmp.height }; }
    const w = Math.round(bmp.width * k), h = Math.round(bmp.height * k);
    const c = document.createElement("canvas"); c.width = w; c.height = h;
    c.getContext("2d").drawImage(bmp, 0, 0, w, h); bmp.close?.();
    const blob = await new Promise((r) => c.toBlob(r, "image/jpeg", 0.9));
    return { blob, w, h };
  } catch { return { blob: file, w: 0, h: 0 }; }
}

export async function makeThumb(blob, size = 120) {
  try {
    const bmp = await createImageBitmap(blob);
    const k = size / Math.max(bmp.width, bmp.height);
    const c = document.createElement("canvas"); c.width = Math.round(bmp.width * k); c.height = Math.round(bmp.height * k);
    c.getContext("2d").drawImage(bmp, 0, 0, c.width, c.height); bmp.close?.();
    return c.toDataURL("image/jpeg", 0.7);
  } catch { return ""; }
}

/** Returns a JPEG Blob of (almost) the last frame of a video Blob. */
export async function extractLastFrame(videoBlob) {
  try { return await videoLastFrame(videoBlob); }
  catch { const { lastFrameFF } = await import("@/lib/merge"); return lastFrameFF(videoBlob); }
}
function videoLastFrame(videoBlob) {
  return new Promise((resolve, reject) => {
    const v = document.createElement("video");
    const url = URL.createObjectURL(videoBlob);
    v.muted = true; v.playsInline = true; v.preload = "auto"; v.src = url;
    const done = (fn, x) => { URL.revokeObjectURL(url); fn(x); };
    v.onerror = () => done(reject, new Error("Could not read the clip to grab its last frame"));
    v.onloadedmetadata = () => { v.currentTime = Math.max(0, (v.duration || 1) - 0.12); };
    v.onseeked = () => {
      const c = document.createElement("canvas"); c.width = v.videoWidth; c.height = v.videoHeight;
      c.getContext("2d").drawImage(v, 0, 0);
      c.toBlob((b) => (b ? done(resolve, b) : done(reject, new Error("Last-frame capture failed"))), "image/jpeg", 0.92);
    };
  });
}
