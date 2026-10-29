export const STYLES = {
  none: { label: "None", text: "" },
  cinematic: { label: "Cinematic", text: "Cinematic film look, dramatic lighting, shallow depth of field, rich colour grading, 35mm" },
  anime: { label: "Anime", text: "Hand-drawn 2D anime, ink linework, cel shading, painted background, film grain, dynamic anime camera" },
  scifi: { label: "Sci-Fi", text: "Futuristic sci-fi, neon holographic lights, sleek metal and glass, volumetric haze, high-tech atmosphere" },
};
export const CAMERAS = {
  none: { label: "Static / auto", text: "" },
  panLeft: { label: "Pan left", text: "camera pans smoothly to the left" },
  panRight: { label: "Pan right", text: "camera pans smoothly to the right" },
  zoomIn: { label: "Zoom in", text: "slow camera zoom in" },
  zoomOut: { label: "Zoom out", text: "slow camera zoom out" },
  orbit: { label: "Orbit 360", text: "camera orbits around the subject" },
  tracking: { label: "Tracking", text: "fast tracking shot following the subject" },
  crane: { label: "Crane up", text: "crane shot rising up and revealing the scene" },
};

export function buildPrompt(prompt, style, camera) {
  return [prompt.trim(), CAMERAS[camera]?.text, STYLES[style]?.text].filter(Boolean).join(". ").replace(/\.\./g, ".");
}
