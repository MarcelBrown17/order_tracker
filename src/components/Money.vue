<script setup>
import { computed } from 'vue'

const props = defineProps({
  value: {
    type: [Number, String],
    default: 0,
  },
  tone: {
    type: String,
    default: 'neutral',
    validator: (v) => ['neutral', 'owed', 'profit'].includes(v),
  },
})

const formatted = computed(() => {
  const num = Number(props.value) || 0
  const abs = Math.abs(num)
  const fixed = abs.toFixed(2)
  const [whole, decimal] = fixed.split('.')
  const withSpaces = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ' ')
  const sign = num < 0 ? '-' : ''
  return `R${sign}${withSpaces}.${decimal}`
})

const toneClass = computed(() => {
  if (props.tone === 'owed') return 'font-bold tabular-nums text-accent'
  if (props.tone === 'profit') return 'font-bold tabular-nums text-profit'
  return 'tabular-nums'
})
</script>

<template>
  <span :class="toneClass">{{ formatted }}</span>
</template>
