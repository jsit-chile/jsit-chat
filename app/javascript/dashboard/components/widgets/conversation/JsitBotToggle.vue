<script setup>
import { computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useJsitComando } from 'dashboard/composables/useJsitComando';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  chat: {
    type: Object,
    default: () => ({}),
  },
});

const store = useStore();
const { t } = useI18n();
const { isSending, sendComando } = useJsitComando();

// The bot is off until an agent turns it on, which is what writes the Redis
// record on the jWorkflows side.
const isBotEnabled = computed(
  () => props.chat.custom_attributes?.jsit_bot_enabled === true
);

const tooltip = computed(() =>
  isBotEnabled.value
    ? t('CONVERSATION.HEADER.JSIT_BOT.TURN_OFF')
    : t('CONVERSATION.HEADER.JSIT_BOT.TURN_ON')
);

const toggleBot = async () => {
  const nextState = !isBotEnabled.value;
  const sent = await sendComando({
    conversationId: props.chat.id,
    comando: nextState ? 'on' : 'off',
  });
  if (!sent) return;

  await store.dispatch('updateCustomAttributes', {
    conversationId: props.chat.id,
    customAttributes: {
      ...(props.chat.custom_attributes || {}),
      jsit_bot_enabled: nextState,
    },
  });
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
    sm
    ghost
    :color="isBotEnabled ? 'teal' : 'slate'"
    :icon="isBotEnabled ? 'i-lucide-bot' : 'i-lucide-bot-off'"
    :is-loading="isSending"
    @click="toggleBot"
  />
</template>
