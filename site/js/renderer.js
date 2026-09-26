// The glass renderer in WebGL2, a port of PliRender's GlassRenderer: one blur pyramid per picture,
// one fragment pass per frame, uniforms from the same optical model (optics.js).
import { DOWNSAMPLE_FRAGMENT, FULLSCREEN_VERTEX, GLASS_FRAGMENT } from './shader.js';
import { displayGeometry, glassUniforms, mipLevelCount } from './optics.js';

export class RenderError extends Error {}

/** Largest drawing buffer the page asks for: about a 14-inch display at 2x, cropped. */
export const MAX_PIXELS = 2_400_000;

function compile(gl, type, source) {
  const shader = gl.createShader(type);
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS) && !gl.isContextLost()) {
    throw new RenderError(`Shader failed to compile: ${gl.getShaderInfoLog(shader)}`);
  }
  return shader;
}

function link(gl, fragmentSource, uniformNames) {
  const program = gl.createProgram();
  gl.attachShader(program, compile(gl, gl.VERTEX_SHADER, FULLSCREEN_VERTEX));
  gl.attachShader(program, compile(gl, gl.FRAGMENT_SHADER, fragmentSource));
  gl.linkProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS) && !gl.isContextLost()) {
    throw new RenderError(`Program failed to link: ${gl.getProgramInfoLog(program)}`);
  }
  const uniforms = {};
  for (const name of uniformNames) uniforms[name] = gl.getUniformLocation(program, name);
  return { program, uniforms };
}

export class GlassRenderer {
  /**
   * @param {HTMLCanvasElement} canvas
   * @param {{ allowSoftware?: boolean }} options  software WebGL is refused unless allowed (too slow for 60 fps)
   */
  constructor(canvas, { allowSoftware = false } = {}) {
    const gl = canvas.getContext('webgl2', {
      alpha: false, antialias: false, depth: false, stencil: false,
      premultipliedAlpha: true, preserveDrawingBuffer: false,
      failIfMajorPerformanceCaveat: !allowSoftware,
    });
    if (!gl) throw new RenderError('WebGL2 is unavailable');
    this.canvas = canvas;
    this.gl = gl;
    this.glass = link(gl, GLASS_FRAGMENT, ['uSource', 'uSizeAndProgress', 'uOptics', 'uBlur', 'uShape', 'uTint', 'uColor']);
    this.downsample = link(gl, DOWNSAMPLE_FRAGMENT, ['uSource', 'uTargetSize']);
    this.vao = gl.createVertexArray();
    this.framebuffer = gl.createFramebuffer();
    this.source = null;
    this.lost = false;
    this.onLost = null;
    this.handleLost = (event) => {
      event.preventDefault();
      this.lost = true;
      this.onLost?.();
    };
    canvas.addEventListener('webglcontextlost', this.handleLost);
  }

  /** Sizes the drawing buffer to the canvas's CSS box at up to 2x, within MAX_PIXELS. Returns true when it changed. */
  resize(cssWidth, cssHeight, devicePixelRatio = 1) {
    let scale = Math.min(devicePixelRatio, 2);
    const pixels = cssWidth * cssHeight * scale * scale;
    if (pixels > MAX_PIXELS) scale *= Math.sqrt(MAX_PIXELS / pixels);
    const width = Math.max(1, Math.round(cssWidth * scale));
    const height = Math.max(1, Math.round(cssHeight * scale));
    if (this.canvas.width === width && this.canvas.height === height) return false;
    this.canvas.width = width;
    this.canvas.height = height;
    return true;
  }

  /** Uploads the picture and builds its blur pyramid in the mip levels of one texture (spec 7.2). */
  setSource(image) {
    const gl = this.gl;
    const width = image.naturalWidth || image.width;
    const height = image.naturalHeight || image.height;
    if (!(width > 0 && height > 0)) throw new RenderError('The picture is empty');
    const levels = mipLevelCount(width, height);
    if (this.source) gl.deleteTexture(this.source.texture);
    const texture = gl.createTexture();
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texStorage2D(gl.TEXTURE_2D, levels, gl.RGBA8, width, height);
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, false);
    gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false);
    gl.pixelStorei(gl.UNPACK_COLORSPACE_CONVERSION_WEBGL, gl.NONE);
    gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, gl.RGBA, gl.UNSIGNED_BYTE, image);
    // An <img> with srcset reports a density-corrected naturalWidth, smaller than the pixels WebGL uploads.
    if (gl.getError() !== gl.NO_ERROR) {
      gl.deleteTexture(texture);
      throw new RenderError('The picture could not be uploaded: give the <img> a single src, no srcset');
    }
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);

    gl.useProgram(this.downsample.program);
    gl.uniform1i(this.downsample.uniforms.uSource, 0);
    gl.bindVertexArray(this.vao);
    gl.bindFramebuffer(gl.FRAMEBUFFER, this.framebuffer);
    for (let level = 1; level < levels; level++) {
      const w = Math.max(width >> level, 1);
      const h = Math.max(height >> level, 1);
      // Sample only the level above while writing this one, so the texture never feeds back into itself.
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_BASE_LEVEL, level - 1);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAX_LEVEL, level - 1);
      gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture, level);
      gl.viewport(0, 0, w, h);
      gl.uniform2f(this.downsample.uniforms.uTargetSize, w, h);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
    }
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, null, 0);
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_BASE_LEVEL, 0);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAX_LEVEL, levels - 1);
    this.source = { texture, width, height, mipLevels: levels };
  }

  /**
   * Draws one frame into the canvas.
   * @param {{ progress: number, glass: object, taps?: number, reduceMotion?: boolean, pixelsPerMM?: number }} frame
   * @returns {boolean} false when there is nothing to draw (no picture yet, or the context is lost)
   */
  render({ progress, glass, taps = 8, reduceMotion = false, pixelsPerMM }) {
    if (!this.source || this.lost) return false;
    const gl = this.gl;
    const width = gl.drawingBufferWidth;
    const height = gl.drawingBufferHeight;
    const geometry = displayGeometry(width, height, pixelsPerMM);
    const u = glassUniforms({ progress, glass, geometry, taps, reduceMotion }, this.source);
    const names = this.glass.uniforms;
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    gl.viewport(0, 0, width, height);
    gl.useProgram(this.glass.program);
    gl.bindVertexArray(this.vao);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.source.texture);
    gl.uniform1i(names.uSource, 0);
    gl.uniform4fv(names.uSizeAndProgress, u.sizeAndProgress);
    gl.uniform4fv(names.uOptics, u.optics);
    gl.uniform4fv(names.uBlur, u.blur);
    gl.uniform4fv(names.uShape, u.shape);
    gl.uniform4fv(names.uTint, u.tint);
    gl.uniform4fv(names.uColor, u.color);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    return true;
  }

  dispose() {
    const gl = this.gl;
    this.canvas.removeEventListener('webglcontextlost', this.handleLost);
    if (this.source) gl.deleteTexture(this.source.texture);
    gl.deleteFramebuffer(this.framebuffer);
    gl.deleteVertexArray(this.vao);
    gl.deleteProgram(this.glass.program);
    gl.deleteProgram(this.downsample.program);
    gl.getExtension('WEBGL_lose_context')?.loseContext(); // frees the GPU memory now rather than at collection
    this.source = null;
  }
}
