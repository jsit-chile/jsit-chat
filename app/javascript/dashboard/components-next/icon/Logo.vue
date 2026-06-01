<script setup>
import { useAttrs } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

const attrs = useAttrs();
const globalConfig = useMapGetter('globalConfig/get');
</script>

<template>
  <img
    v-if="globalConfig.logoThumbnail"
    v-bind="attrs"
    :src="globalConfig.logoThumbnail"
  />
  <svg
    v-else
    v-once
    v-bind="attrs"
    width="16"
    height="16"
    viewBox="0 0 16 16"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
  >
    <rect width="16" height="16" rx="3" fill="#0D1117" />
    <path
      d="M10.5 4.5V9.6c0 1.5-1 2.4-2.5 2.4-1.3 0-2.2-.7-2.5-1.9l1.4-.4c.1.6.5 1 1.1 1 .6 0 1-.4 1-1.1V4.5h1.5Z"
      fill="#E6EDF3"
    />
  </svg>
</template>
