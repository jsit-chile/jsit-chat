// Fades out and removes the branded #app-loading splash painted by the
// vueapp layout, keeping it visible at least `minVisibleMs` from navigation
// start while the app finishes loading behind it.
export const removeAppSplash = (minVisibleMs = 2500) => {
  const loadingEl = document.getElementById('app-loading');
  if (!loadingEl) {
    return;
  }
  const remaining = Math.max(0, minVisibleMs - performance.now());
  setTimeout(() => {
    loadingEl.style.opacity = '0';
    loadingEl.style.transition = 'opacity 0.3s ease-out';
    setTimeout(() => loadingEl.remove(), 300);
  }, remaining);
};
