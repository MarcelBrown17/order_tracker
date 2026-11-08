<script setup>
defineProps({
  small: Boolean,
})
</script>

<template>
  <span class="brand-logo" :class="{ 'brand-logo--sm': small }">
    <svg class="brand-logo__mark" viewBox="0 0 40 40" aria-hidden="true">
      <circle cx="20" cy="20" r="19" fill="#c2255c" />
      <circle cx="20" cy="20" r="12" fill="#f5c84b" />
      <circle cx="16" cy="17" r="2" fill="#2a1a12" />
      <circle cx="23" cy="16" r="2" fill="#2a1a12" />
      <circle cx="21" cy="24" r="2" fill="#2a1a12" />
      <circle cx="14" cy="23" r="1.6" fill="#2a1a12" />
    </svg>
    <span class="brand-logo__name">Marcel</span>
  </span>
</template>
