<script setup>
import { useRouter } from 'vue-router'

const props = defineProps({
  to: {
    type: [String, Object],
    default: null,
  },
  label: {
    type: String,
    default: 'Back',
  },
  fallback: {
    type: [String, Object],
    default: () => ({ name: 'orders' }),
  },
})

const router = useRouter()

function goBack() {
  if (props.to) {
    router.push(props.to)
    return
  }
  if (typeof window !== 'undefined' && window.history.length > 1) {
    router.back()
    return
  }
  router.push(props.fallback)
}
</script>

<template>
  <button type="button" class="page-back" @click="goBack">
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2.25"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path d="m15 18-6-6 6-6" />
    </svg>
    <span>{{ label }}</span>
  </button>
</template>
