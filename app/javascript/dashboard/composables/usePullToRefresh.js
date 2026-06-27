import { ref, computed, onMounted, onBeforeUnmount } from 'vue';

const TRIGGER_THRESHOLD = 64; // px the user must pull to trigger a refresh
const MAX_PULL = 96; // px the indicator can travel
const RESISTANCE = 0.5; // dampens the pull so it feels elastic

/**
 * Adds a native-like pull-to-refresh gesture to a scrollable element.
 * Only engages when the element is scrolled to the top and the user drags
 * down, so it never interferes with regular scrolling. Designed for touch /
 * PWA usage (touch events do not fire with a mouse).
 *
 * @param {import('vue').Ref<HTMLElement|null>} scrollElRef - scroll container ref
 * @param {() => (Promise<unknown>|unknown)} onRefresh - called on trigger; awaited
 */
export function usePullToRefresh(scrollElRef, onRefresh) {
  const pullDistance = ref(0);
  const isPulling = ref(false);
  const isRefreshing = ref(false);

  let startY = 0;
  let tracking = false;

  const pullProgress = computed(() =>
    Math.min(1, pullDistance.value / TRIGGER_THRESHOLD)
  );

  const onTouchStart = e => {
    if (isRefreshing.value) return;
    const el = scrollElRef.value;
    if (!el || el.scrollTop > 0) return;
    startY = e.touches[0].clientY;
    tracking = true;
  };

  const onTouchMove = e => {
    if (!tracking || isRefreshing.value) return;
    const el = scrollElRef.value;
    if (!el) return;

    const delta = e.touches[0].clientY - startY;
    // Cancel if the user scrolls up or the list is no longer at the top
    if (delta <= 0 || el.scrollTop > 0) {
      tracking = false;
      isPulling.value = false;
      pullDistance.value = 0;
      return;
    }

    // Prevent the native overscroll/bounce while we own the gesture
    e.preventDefault();
    isPulling.value = true;
    pullDistance.value = Math.min(MAX_PULL, delta * RESISTANCE);
  };

  const onTouchEnd = async () => {
    if (!tracking) return;
    tracking = false;
    isPulling.value = false;

    if (pullDistance.value < TRIGGER_THRESHOLD || isRefreshing.value) {
      pullDistance.value = 0;
      return;
    }

    isRefreshing.value = true;
    pullDistance.value = TRIGGER_THRESHOLD;
    try {
      await onRefresh();
    } finally {
      isRefreshing.value = false;
      pullDistance.value = 0;
    }
  };

  onMounted(() => {
    const el = scrollElRef.value;
    if (!el) return;
    el.addEventListener('touchstart', onTouchStart, { passive: true });
    el.addEventListener('touchmove', onTouchMove, { passive: false });
    el.addEventListener('touchend', onTouchEnd, { passive: true });
    el.addEventListener('touchcancel', onTouchEnd, { passive: true });
  });

  onBeforeUnmount(() => {
    const el = scrollElRef.value;
    if (!el) return;
    el.removeEventListener('touchstart', onTouchStart);
    el.removeEventListener('touchmove', onTouchMove);
    el.removeEventListener('touchend', onTouchEnd);
    el.removeEventListener('touchcancel', onTouchEnd);
  });

  return { pullDistance, pullProgress, isPulling, isRefreshing };
}
