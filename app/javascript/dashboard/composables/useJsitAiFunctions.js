import { computed } from 'vue';
import { useAccount } from './useAccount';

/**
 * Account level switch, flipped from the super admin console, that decides
 * whether the JSIT bot controls are available in the dashboard.
 */
export function useJsitAiFunctions() {
  const { currentAccount } = useAccount();

  const isAiFunctionsEnabled = computed(
    () => currentAccount.value?.custom_attributes?.jsit_ai_functions === true
  );

  return { isAiFunctionsEnabled };
}
