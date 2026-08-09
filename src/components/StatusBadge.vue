<script setup>
import { computed } from 'vue'

const props = defineProps({
  status: {
    type: String,
    required: true,
  },
})

const styles = {
  pending:
    'bg-amber-100 text-amber-900 dark:bg-amber-500/15 dark:text-amber-200',
  paid: 'bg-sky-100 text-sky-900 dark:bg-sky-500/15 dark:text-sky-200',
  cancelled:
    'bg-stone-200 text-stone-600 dark:bg-neutral-500/20 dark:text-neutral-300',
}

const label = computed(() => {
  const s = props.status || ''
  return s.charAt(0).toUpperCase() + s.slice(1)
})

const className = computed(() => styles[props.status] || styles.cancelled)
</script>

<template>
  <span
    :class="[
      'inline-block rounded-md px-2 py-0.5 text-xs font-bold',
      className,
    ]"
  >
    {{ label }}
  </span>
</template>
