import { defineStore } from 'pinia';
import JsitBotApi from 'dashboard/api/jsitBot';
import ConversationApi from 'dashboard/api/inbox/conversation';

// Holds the bot on/off state of every conversation in the account, fetched in a
// single call so the conversation list does not hit the API per row.
// The backend only sends the conversations that differ from the account
// default, so an account where the bot answers everything (defaultEnabled)
// reports the paused ones instead of the active ones.
export const useJsitBotStore = defineStore('jsitBot', {
  state: () => ({
    defaultEnabled: false,
    exceptionIds: [],
    pendingIds: [],
    isFetching: false,
  }),

  getters: {
    isEnabled: state => conversationId =>
      state.exceptionIds.includes(conversationId)
        ? !state.defaultEnabled
        : state.defaultEnabled,
    isPending: state => conversationId =>
      state.pendingIds.includes(conversationId),
  },

  actions: {
    async fetchStates() {
      this.isFetching = true;
      try {
        const { data } = await JsitBotApi.get();
        this.defaultEnabled = data.default_enabled === true;
        this.exceptionIds = data.exception_conversation_ids || [];
      } catch (error) {
        // Redis unreachable or not configured, keep whatever we have
      } finally {
        this.isFetching = false;
      }
    },

    async toggle(conversationId) {
      if (this.isPending(conversationId)) return false;

      const nextState = !this.isEnabled(conversationId);
      this.pendingIds = [...this.pendingIds, conversationId];
      try {
        await ConversationApi.sendJsitCommand({
          conversationId,
          comando: nextState ? 'on' : 'off',
        });
        this.setState(conversationId, nextState);
        return true;
      } catch (error) {
        return false;
      } finally {
        this.pendingIds = this.pendingIds.filter(id => id !== conversationId);
      }
    },

    setState(conversationId, enabled) {
      const withoutId = this.exceptionIds.filter(id => id !== conversationId);
      const isException = enabled !== this.defaultEnabled;
      this.exceptionIds = isException
        ? [...withoutId, conversationId]
        : withoutId;
    },
  },
});
