import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import ConversationApi from 'dashboard/api/inbox/conversation';
import { useAlert } from 'dashboard/composables';

/**
 * Sends a command (on | off | respond) for a conversation to the JSIT
 * automation workflow through the Rails proxy.
 */
export function useJsitComando() {
  const { t } = useI18n();
  const isSending = ref(false);

  const sendComando = async ({ conversationId, comando }) => {
    isSending.value = true;
    try {
      await ConversationApi.sendJsitCommand({ conversationId, comando });
      return true;
    } catch (error) {
      useAlert(t('CONVERSATION.HEADER.JSIT_BOT.ERROR'));
      return false;
    } finally {
      isSending.value = false;
    }
  };

  return { isSending, sendComando };
}
