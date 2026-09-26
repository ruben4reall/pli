// Browser side of tools/export-images.mjs: renders glass frames of the real desktop (assets/desktop.webp,
// a picture of a real macOS desktop kept outside the repository) with the site's renderer.
import { GlassRenderer } from '../js/renderer.js';
import { DISPLAY_RATIO, PAGE_LID_REST, foldProgress, presetById } from '../js/optics.js';

const source = new Image();
source.src = '../assets/desktop.webp';
await source.decode();

window.__export = {
  /** A preset's glass at a lid `angle` (the page's lid rests at 110°), as a WebP data URL. */
  frame(presetId, angle, width, quality) {
    const preset = presetById(presetId);
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = Math.round(width / DISPLAY_RATIO);
    const renderer = new GlassRenderer(canvas);
    renderer.setSource(source);
    renderer.render({ progress: foldProgress(preset.motion, angle, PAGE_LID_REST), glass: preset.glass });
    const url = canvas.toDataURL('image/webp', quality);
    renderer.dispose();
    return url;
  },
};
window.__exportReady = true;
