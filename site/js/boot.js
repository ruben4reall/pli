// Runs before the first paint (render-blocking, a few hundred bytes): a Mac that will open starts closed,
// any other starts open. hero.js takes over from here.
(function () {
  var root = document.documentElement;
  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var webgl2 = typeof window.WebGL2RenderingContext === 'function';
  root.setAttribute('data-motion', !reduce && webgl2 ? 'full' : 'still');
  root.classList.add('js');
})();
