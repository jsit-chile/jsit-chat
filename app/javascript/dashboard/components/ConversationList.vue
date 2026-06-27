<script setup>
import { ref, computed, provide } from 'vue';
import { Virtualizer } from 'virtua/vue';
import { useBreakpoints } from '@vueuse/core';
import { useChatListKeyboardEvents } from 'dashboard/composables/chatlist/useChatListKeyboardEvents';
import { usePullToRefresh } from 'dashboard/composables/usePullToRefresh';
import ConversationItem from './ConversationItem.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import IntersectionObserver from 'dashboard/components/IntersectionObserver.vue';

import wootConstants from 'dashboard/constants/globals';

const props = defineProps({
  conversationList: { type: Array, default: () => [] },
  isLoading: { type: Boolean, default: false },
  showEndOfListMessage: { type: Boolean, default: false },
  label: { type: String, default: '' },
  teamId: { type: [String, Number], default: 0 },
  foldersId: { type: [String, Number], default: 0 },
  conversationType: { type: String, default: '' },
  showAssignee: { type: Boolean, default: false },
  isOnExpandedLayout: { type: Boolean, default: false },
  onRefresh: { type: Function, default: null },
});

const emit = defineEmits(['loadMore']);

const conversationListRef = ref(null);
const virtualListRef = ref(null);
const isContextMenuOpen = ref(false);

const { pullDistance, pullProgress, isPulling, isRefreshing } =
  usePullToRefresh(conversationListRef, () => props.onRefresh?.());

const pullStyle = computed(() => ({
  transform: `translate3d(0, ${pullDistance.value}px, 0)`,
  transition: isPulling.value ? 'none' : 'transform 0.2s ease',
}));

provide('contextMenuElementTarget', virtualListRef);

const breakpoints = useBreakpoints({
  lg: wootConstants.LARGE_SCREEN_BREAKPOINT,
});
const isLgScreen = breakpoints.greaterOrEqual('lg');
const showExpandedCards = computed(
  () => props.isOnExpandedLayout && isLgScreen.value
);

useChatListKeyboardEvents(conversationListRef);

const intersectionObserverOptions = computed(() => ({
  root: conversationListRef.value,
  rootMargin: '100px 0px 100px 0px',
}));

const onContextMenuToggle = state => {
  isContextMenuOpen.value = state;
};

const loadMoreConversations = () => {
  emit('loadMore');
};

provide('toggleContextMenu', onContextMenuToggle);

defineExpose({ conversationListRef });
</script>

<template>
  <div class="flex relative flex-col flex-1 min-h-0 overflow-hidden">
    <div
      class="flex absolute inset-x-0 top-0 z-10 justify-center items-end pb-2 pointer-events-none"
      :style="{
        height: `${pullDistance}px`,
        opacity: isRefreshing ? 1 : pullProgress,
      }"
    >
      <Spinner :size="20" class="text-n-brand" />
    </div>
    <div
      ref="conversationListRef"
      class="flex-1 min-h-0 overflow-y-auto conversations-list"
      :class="{ '!overflow-hidden': isContextMenuOpen }"
      :style="pullStyle"
    >
      <Virtualizer
        ref="virtualListRef"
        v-slot="{ item }"
        :data="conversationList"
        class="[&>div:has(+_div_.active)>*]:!border-n-surface-1 [&>div:has(+_div_.selected)>*]:!border-n-surface-1"
      >
        <ConversationItem
          :source="item"
          :label="label"
          :team-id="teamId"
          :folders-id="foldersId"
          :conversation-type="conversationType"
          :show-assignee="showAssignee"
          :show-expanded="showExpandedCards"
        />
      </Virtualizer>
      <div v-if="isLoading && !isRefreshing" class="flex justify-center my-4">
        <Spinner class="text-n-brand" />
      </div>
      <p
        v-else-if="showEndOfListMessage"
        class="p-4 text-center text-n-slate-11"
      >
        {{ $t('CHAT_LIST.EOF') }}
      </p>
      <IntersectionObserver
        v-else
        :options="intersectionObserverOptions"
        @observed="loadMoreConversations"
      />
    </div>
  </div>
</template>
