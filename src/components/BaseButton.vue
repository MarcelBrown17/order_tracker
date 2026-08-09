<script setup>
defineProps({
  variant: {
    type: String,
    default: 'primary',
    validator: (v) => ['primary', 'secondary', 'destructive'].includes(v),
  },
  type: {
    type: String,
    default: 'button',
  },
  disabled: Boolean,
  block: Boolean,
})

const variants = {
  primary:
    'bg-accent text-white hover:bg-accent-hover active:bg-accent-hover disabled:opacity-50 shadow-[0_10px_20px_-8px_color-mix(in_srgb,var(--color-accent)_55%,transparent)]',
  secondary:
    'bg-surface text-text border border-border hover:bg-page active:bg-page disabled:opacity-50',
  destructive:
    'bg-red-700 text-white hover:bg-red-800 active:bg-red-800 disabled:opacity-50 shadow-sm',
}
</script>

<template>
  <button
    :type="type"
    :disabled="disabled"
    :class="[
      'inline-flex min-h-11 items-center justify-center gap-2 rounded-xl px-4 py-2.5 text-sm font-bold transition-colors',
      variants[variant],
      block ? 'w-full' : '',
    ]"
  >
    <slot />
  </button>
</template>
