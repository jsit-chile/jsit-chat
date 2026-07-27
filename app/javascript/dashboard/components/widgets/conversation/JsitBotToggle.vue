<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useJsitBotStore } from 'dashboard/stores/jsitBot';
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

// The store is the single client side source of truth, so this button and the
// chips in the conversation list always show the same state.
const isBotEnabled = computed(() => jsitBotStore.isEnabled(props.chat.id));
const isLoadingState = ref(false);

const tooltip = computed(() =>
  isBotEnabled.value
    ? t('CONVERSATION.HEADER.JSIT_BOT.TURN_OFF')
    : t('CONVERSATION.HEADER.JSIT_BOT.TURN_ON')
);

// Opening a conversation revalidates it against the jWorkflows Redis, which
// also corrects the store if the workflow changed the state on its own.
const fetchBotState = async conversationId => {
  if (!conversationId) return;
  isLoadingState.value = true;
  try {
    const { data } = await ConversationApi.fetchJsitBotState(conversationId);
    jsitBotStore.setState(conversationId, data.bot_enabled);
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
  useAlert(
    wasEnabled
      ? t('CONVERSATION.HEADER.JSIT_BOT.TURNED_OFF')
      : t('CONVERSATION.HEADER.JSIT_BOT.TURNED_ON')
  );
};
</script>

<template>
  <NextButton
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
</template>
