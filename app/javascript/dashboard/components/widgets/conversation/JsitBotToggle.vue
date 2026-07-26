<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useJsitComando } from 'dashboard/composables/useJsitComando';
import ConversationApi from 'dashboard/api/inbox/conversation';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  chat: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();
const { isSending, sendComando } = useJsitComando();

// jWorkflows keeps the bot state in its own Redis, so it is fetched per
// conversation instead of derived from the conversation payload.
const isBotEnabled = ref(false);
const isLoadingState = ref(false);

const tooltip = computed(() =>
  isBotEnabled.value
    ? t('CONVERSATION.HEADER.JSIT_BOT.TURN_OFF')
    : t('CONVERSATION.HEADER.JSIT_BOT.TURN_ON')
);

const fetchBotState = async conversationId => {
  if (!conversationId) return;
  isLoadingState.value = true;
  try {
    const { data } = await ConversationApi.fetchJsitBotState(conversationId);
    isBotEnabled.value = data.bot_enabled;
  } catch (error) {
    isBotEnabled.value = false;
  } finally {
    isLoadingState.value = false;
  }
};

watch(() => props.chat.id, fetchBotState, { immediate: true });

const toggleBot = async () => {
  const nextState = !isBotEnabled.value;
  const sent = await sendComando({
    conversationId: props.chat.id,
    comando: nextState ? 'on' : 'off',
  });
  if (!sent) return;

  isBotEnabled.value = nextState;
  useAlert(
    nextState
      ? t('CONVERSATION.HEADER.JSIT_BOT.TURNED_ON')
      : t('CONVERSATION.HEADER.JSIT_BOT.TURNED_OFF')
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
    :is-loading="isSending || isLoadingState"
    @click="toggleBot"
  />
</template>
