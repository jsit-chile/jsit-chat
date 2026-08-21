import { computed, watch } from 'vue';
import { useStore } from './store';
import { useAccount } from './useAccount';

// The account is loaded once when the app boots and `accounts/get` swallows its
// errors, so a single failed request leaves the record empty for the rest of the
// session and the bot controls silently disappear until a full reload. Every
// component that needs the switch asks for the account, sharing one request:
// the conversation list mounts one chip per row.
let pendingFetch = null;
const ensureAccountLoaded = store => {
  if (!pendingFetch) {
    pendingFetch = store.dispatch('accounts/get').finally(() => {
      pendingFetch = null;
    });
  }
  return pendingFetch;
};

/**
 * Account level switch, flipped from the super admin console, that decides
 * whether the JSIT bot controls are available in the dashboard.
 */
export function useJsitAiFunctions() {
  const store = useStore();
  const { accountId, currentAccount } = useAccount();

  watch(
    () => [accountId.value, currentAccount.value?.id],
    ([id, loadedId]) => {
      if (id && loadedId !== id) ensureAccountLoaded(store);
    },
    { immediate: true }
  );

  const isAiFunctionsEnabled = computed(
    () => currentAccount.value?.custom_attributes?.jsit_ai_functions === true
  );

  return { isAiFunctionsEnabled };
}
