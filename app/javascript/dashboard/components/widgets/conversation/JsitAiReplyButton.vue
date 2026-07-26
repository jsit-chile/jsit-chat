<script setup>
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

const { t } = useI18n();
const { isSending, sendComando } = useJsitComando();

const requestAiReply = async () => {
  const sent = await sendComando({
    conversationId: props.chat.id,
    comando: 'respond',
  });
  if (sent) useAlert(t('CONVERSATION.HEADER.JSIT_BOT.REPLY_REQUESTED'));
};
</script>

<template>
  <NextButton
    v-tooltip.bottom="$t('CONVERSATION.HEADER.JSIT_BOT.REPLY')"
    size="sm"
    variant="solid"
    color="blue"
    :label="$t('CONVERSATION.HEADER.JSIT_BOT.REPLY_LABEL')"
    icon="i-lucide-bot-message-square"
    :is-loading="isSending"
    @click="requestAiReply"
  />
</template>
