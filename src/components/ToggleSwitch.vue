<script setup>
defineProps({
  modelValue: {
    type: Boolean,
    default: false,
  },
  label: {
    type: String,
    default: '',
  },
  description: {
    type: String,
    default: '',
  },
  disabled: Boolean,
  compact: Boolean,
})

defineEmits(['update:modelValue'])
</script>

<template>
  <button
    type="button"
    role="switch"
    :aria-checked="modelValue"
    :aria-label="label || 'Toggle'"
    :disabled="disabled"
    class="toggle-row"
    :class="{
      'toggle-row--on': modelValue,
      'toggle-row--disabled': disabled,
      'toggle-row--compact': compact,
    }"
    @click="$emit('update:modelValue', !modelValue)"
  >
    <span v-if="label || description || $slots.default" class="toggle-row__text">
      <span v-if="label" class="toggle-row__label">{{ label }}</span>
      <span
        v-if="!compact && (description || $slots.default)"
        class="toggle-row__desc"
      >
        <slot>{{ description }}</slot>
      </span>
    </span>
    <span class="toggle-track" aria-hidden="true">
      <span class="toggle-thumb" />
    </span>
  </button>
</template>
