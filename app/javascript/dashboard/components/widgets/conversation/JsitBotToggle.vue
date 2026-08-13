<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { useJsitBotStore } from 'dashboard/stores/jsitBot';
import { isBotBlockedNumber } from 'dashboard/helper/jsitBotHelper';
import ConversationApi from 'dashboard/api/inbox/conversation';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  chat: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();
const jsitBotStore = useJsitBotStore();
const currentUser = useMapGetter('getCurrentUser');

// The store is the single client side source of truth, so this button and the
// chips in the conversation list always show the same state.
const isBotEnabled = computed(() => jsitBotStore.isEnabled(props.chat.id));
const isLoadingState = ref(false);
// Who flipped the bot last, so the header shows it without opening the timeline.
const lastChangedBy = ref('');
// The bot must never answer its own number, so the toggle is not offered there.
const isBlocked = computed(() =>
  isBotBlockedNumber(props.chat.meta?.sender?.phone_number)
);

const tooltip = computed(() => {
  const action = isBotEnabled.value
    ? t('CONVERSATION.HEADER.JSIT_BOT.TURN_OFF')
    : t('CONVERSATION.HEADER.JSIT_BOT.TURN_ON');
  if (!lastChangedBy.value) return action;

  return `${action} — ${t('CONVERSATION.HEADER.JSIT_BOT.LAST_CHANGED_BY', {
    name: lastChangedBy.value,
  })}`;
});

// Opening a conversation revalidates it against the jWorkflows Redis, which
// also corrects the store if the workflow changed the state on its own.
const fetchBotState = async conversationId => {
  if (!conversationId || isBlocked.value) return;
  isLoadingState.value = true;
  try {
    const { data } = await ConversationApi.fetchJsitBotState(conversationId);
    jsitBotStore.setState(conversationId, data.bot_enabled);
    lastChangedBy.value = data.bot_updated_by || '';
  } catch (error) {
    // Keep whatever the store already has
  } finally {
    isLoadingState.value = false;
  }
};

watch(() => props.chat.id, fetchBotState, { immediate: true });

const toggleBot = async () => {
  const wasEnabled = isBotEnabled.value;
  const done = await jsitBotStore.toggle(props.chat.id);
  if (!done) {
    useAlert(t('CONVERSATION.HEADER.JSIT_BOT.ERROR'));
    return;
  }
  lastChangedBy.value = currentUser.value?.name || '';
  useAlert(
    wasEnabled
      ? t('CONVERSATION.HEADER.JSIT_BOT.TURNED_OFF')
      : t('CONVERSATION.HEADER.JSIT_BOT.TURNED_ON')
  );
};
</script>

<template>
  <NextButton
    v-if="!isBlocked"
    v-tooltip.bottom="tooltip"
    size="sm"
    :label="
      isBotEnabled
        ? t('CONVERSATION.HEADER.JSIT_BOT.LABEL_ON')
        : t('CONVERSATION.HEADER.JSIT_BOT.LABEL_OFF')
    "
    :variant="isBotEnabled ? 'solid' : 'faded'"
    :color="isBotEnabled ? 'teal' : 'ruby'"
    :icon="isBotEnabled ? 'i-lucide-bot' : 'i-lucide-bot-off'"
    :is-loading="jsitBotStore.isPending(chat.id) || isLoadingState"
    @click="toggleBot"
  />
  <template v-else />
</template>
