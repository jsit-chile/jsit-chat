<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useJsitBotStore } from 'dashboard/stores/jsitBot';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  conversationId: { type: Number, required: true },
});

const { t } = useI18n();
const jsitBotStore = useJsitBotStore();

const isEnabled = computed(() => jsitBotStore.isEnabled(props.conversationId));
const isPending = computed(() => jsitBotStore.isPending(props.conversationId));

const toggle = async () => {
  const wasEnabled = isEnabled.value;
  const done = await jsitBotStore.toggle(props.conversationId);
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
  <button
    v-tooltip.top="
      isEnabled
        ? $t('CONVERSATION.HEADER.JSIT_BOT.TURN_OFF')
        : $t('CONVERSATION.HEADER.JSIT_BOT.TURN_ON')
    "
    type="button"
    class="flex items-center gap-1 h-5 px-1.5 rounded-md flex-shrink-0 text-xxs font-medium transition-colors"
    :class="[
      isEnabled
        ? 'bg-n-teal-9/15 text-n-teal-11 hover:bg-n-teal-9/25'
        : 'bg-n-alpha-2 text-n-slate-11 hover:bg-n-alpha-3',
      isPending ? 'opacity-50 pointer-events-none' : '',
    ]"
    @click.stop.prevent="toggle"
  >
    <Icon
      :icon="isEnabled ? 'i-lucide-bot' : 'i-lucide-bot-off'"
      class="size-3.5"
    />
    <span>
      {{
        isEnabled
          ? $t('CONVERSATION.HEADER.JSIT_BOT.LABEL_ON')
          : $t('CONVERSATION.HEADER.JSIT_BOT.LABEL_OFF')
      }}
    </span>
  </button>
</template>
