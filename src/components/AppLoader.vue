<script setup>
defineProps({
  label: {
    type: String,
    default: 'Loading',
  },
  compact: Boolean,
})
</script>

<template>
  <div class="app-loader" :class="{ 'app-loader--compact': compact }" role="status">
    <div class="app-loader__mark" aria-hidden="true">
      <span class="app-loader__crumb app-loader__crumb--a" />
      <span class="app-loader__crumb app-loader__crumb--b" />
      <span class="app-loader__crumb app-loader__crumb--c" />
    </div>
    <p class="app-loader__label">{{ label }}</p>
  </div>
</template>
