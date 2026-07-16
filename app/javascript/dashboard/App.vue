<script>
import LoadingState from './components/widgets/LoadingState.vue';
import NetworkNotification from './components/NetworkNotification.vue';
import StatusBanner from './components/app/StatusBanner.vue';
import PaymentPendingBanner from './components/app/PaymentPendingBanner.vue';
import PendingEmailVerificationBanner from './components/app/PendingEmailVerificationBanner.vue';
import vueActionCable from './helper/actionCable';
import { useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useMapGetter } from 'dashboard/composables/store';
import WootSnackbarBox from './components/SnackbarContainer.vue';
import { setColorTheme } from './helper/themeHelper';
import { isOnOnboardingView } from 'v3/helpers/RouteHelper';
import { useAccount } from 'dashboard/composables/useAccount';
import { useFontSize } from 'dashboard/composables/useFontSize';
import {
  registerSubscription,
  verifyServiceWorkerExistence,
  setAppBadge,
} from './helper/pushHelper';
import ConversationApi from 'dashboard/api/inbox/conversation';
import { removeAppSplash } from 'shared/helpers/removeAppSplash';
import ReconnectService from 'dashboard/helper/ReconnectService';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { watch } from 'vue';

export default {
  name: 'App',

  components: {
    LoadingState,
    NetworkNotification,
    StatusBanner,
    PaymentPendingBanner,
    WootSnackbarBox,
    PendingEmailVerificationBanner,
  },
  setup() {
    const router = useRouter();
    const store = useStore();
    const { accountId } = useAccount();
    // Use the font size composable (it automatically sets up the watcher)
    const { currentFontSize } = useFontSize();
    const { uiSettings } = useUISettings();

    // Use composition API getters to avoid conflicts
    const getAccount = useMapGetter('accounts/getAccount');
    const isRTL = useMapGetter('accounts/isRTL');
    const currentUser = useMapGetter('getCurrentUser');
    const authUIFlags = useMapGetter('getAuthUIFlags');
    const unreadConversationsCount = useMapGetter(
      'conversations/getUnreadConversationsCount'
    );

    // The PWA badge mirrors the account-wide unread conversations count from
    // the backend — the same source as the push payload and the jSystem badge.
    // The local getter only sees loaded conversations, so it is used as a
    // change signal to re-fetch (e.g. after reading a conversation).
    const syncAppBadge = async () => {
      if (!accountId.value) return;
      try {
        const { data } = await ConversationApi.unreadCount();
        setAppBadge(data.count);
      } catch {
        // transient network error: keep the current badge
      }
    };
    watch(accountId, id => id && syncAppBadge(), { immediate: true });
    watch(unreadConversationsCount, syncAppBadge);

    return {
      router,
      store,
      currentAccountId: accountId,
      currentFontSize,
      uiSettings,
      getAccount,
      isRTL,
      currentUser,
      authUIFlags,
      syncAppBadge,
    };
  },
  data() {
    return {
      reconnectService: null,
    };
  },
  computed: {
    hideOnOnboardingView() {
      return !isOnOnboardingView(this.$route);
    },
  },

  watch: {
    currentAccountId: {
      immediate: true,
      handler() {
        if (this.currentAccountId) {
          this.initializeAccount();
        }
      },
    },
  },
  mounted() {
    this.initializeColorTheme();
    this.listenToThemeChanges();
    // Re-sync the badge whenever the PWA comes back to the foreground
    document.addEventListener('visibilitychange', this.onVisibilityChange);
    // If user locale is set, use it; otherwise use account locale
    this.setLocale(
      this.uiSettings?.locale || window.jChatConfig.selectedLocale
    );
    removeAppSplash();
  },
  unmounted() {
    document.removeEventListener('visibilitychange', this.onVisibilityChange);
    if (this.reconnectService) {
      this.reconnectService.disconnect();
    }
  },
  methods: {
    onVisibilityChange() {
      if (!document.hidden) this.syncAppBadge();
    },
    initializeColorTheme() {
      setColorTheme(window.matchMedia('(prefers-color-scheme: dark)').matches);
    },
    listenToThemeChanges() {
      const mql = window.matchMedia('(prefers-color-scheme: dark)');
      mql.onchange = e => setColorTheme(e.matches);
    },
    setLocale(locale) {
      if (locale) {
        this.$root.$i18n.locale = locale;
      }
    },
    async initializeAccount() {
      await this.$store.dispatch('accounts/get');
      this.$store.dispatch('setActiveAccount', {
        accountId: this.currentAccountId,
      });
      const account = this.getAccount(this.currentAccountId);
      const { locale } = account;
      const { pubsub_token: pubsubToken } = this.currentUser || {};
      // If user locale is set, use it; otherwise use account locale
      this.setLocale(this.uiSettings?.locale || locale);
      vueActionCable.init(this.store, pubsubToken);
      this.reconnectService = new ReconnectService(this.store, this.router);
      window.reconnectService = this.reconnectService;

      verifyServiceWorkerExistence(registration =>
        registration.pushManager.getSubscription().then(subscription => {
          if (subscription) {
            registerSubscription();
          }
        })
      );
    },
  },
};
</script>

<template>
  <div
    v-if="!authUIFlags.isFetching"
    id="app"
    class="flex flex-col w-full h-screen min-h-0 bg-n-background"
    :dir="isRTL ? 'rtl' : 'ltr'"
  >
    <StatusBanner />
    <template v-if="currentAccountId">
      <PendingEmailVerificationBanner v-if="hideOnOnboardingView" />
      <PaymentPendingBanner v-if="hideOnOnboardingView" />
    </template>
    <router-view v-slot="{ Component }">
      <transition name="fade" mode="out-in">
        <component :is="Component" />
      </transition>
    </router-view>
    <WootSnackbarBox />
    <NetworkNotification />
  </div>
  <LoadingState v-else />
</template>

<style lang="scss">
@import './assets/scss/app';

.v-popper--theme-tooltip .v-popper__inner {
  background: black !important;
  font-size: 0.75rem;
  padding: 4px 8px !important;
  border-radius: 6px;
  font-weight: 400;
}

.v-popper--theme-tooltip .v-popper__arrow-container {
  display: none;
}
</style>
