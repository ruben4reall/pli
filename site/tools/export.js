// Browser side of tools/export-images.mjs: renders glass frames of the real desktops (assets/desktop.webp with the Pro
// Black wallpaper, assets/desktop-tahoe.webp with macOS 26's Tahoe wallpaper; pictures of a real macOS desktop kept
// outside the repository) with the site's renderer.
import { GlassRenderer } from '../js/renderer.js';
import { DISPLAY_RATIO, PAGE_LID_REST, foldProgress, presetById } from '../js/optics.js';

async function load(path) {
  const image = new Image();
  image.src = path;
  await image.decode();
  return image;
}
const sources = { black: await load('../assets/desktop.webp'), tahoe: await load('../assets/desktop-tahoe.webp') };

window.__export = {
  /** A preset's glass at a lid `angle` (the page's lid rests at 110°), as a WebP data URL. */
  frame(presetId, angle, width, quality, wall = 'tahoe') {
    const preset = presetById(presetId);
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = Math.round(width / DISPLAY_RATIO);
    const renderer = new GlassRenderer(canvas);
    renderer.setSource(sources[wall]);
    renderer.render({ progress: foldProgress(preset.motion, angle, PAGE_LID_REST), glass: preset.glass });
    const url = canvas.toDataURL('image/webp', quality);
    renderer.dispose();
    return url;
  },
};
window.__exportReady = true;
