<script setup>
import { computed, nextTick, onUnmounted, ref, watch } from 'vue'

const props = defineProps({
  modelValue: {
    type: [String, Number],
    default: '',
  },
  options: {
    type: Array,
    default: () => [],
  },
  placeholder: {
    type: String,
    default: 'Select…',
  },
  disabled: Boolean,
  id: {
    type: String,
    default: '',
  },
  required: Boolean,
})

const emit = defineEmits(['update:modelValue', 'change'])

const open = ref(false)
const root = ref(null)
const listId = `select-list-${Math.random().toString(36).slice(2, 9)}`

const selectedLabel = computed(() => {
  const match = props.options.find((o) => String(o.value) === String(props.modelValue))
  return match?.label || ''
})

function close() {
  open.value = false
}

function toggle() {
  if (props.disabled) return
  open.value = !open.value
}

function selectOption(option) {
  if (option.disabled) return
  emit('update:modelValue', option.value)
  emit('change', option.value)
  close()
}

function onDocumentPointer(e) {
  if (!open.value || !root.value) return
  if (!root.value.contains(e.target)) close()
}

function onKeydown(e) {
  if (!open.value) return
  if (e.key === 'Escape') {
    e.preventDefault()
    close()
  }
}

watch(open, async (isOpen) => {
  if (isOpen) {
    await nextTick()
    document.addEventListener('pointerdown', onDocumentPointer)
    document.addEventListener('keydown', onKeydown)
  } else {
    document.removeEventListener('pointerdown', onDocumentPointer)
    document.removeEventListener('keydown', onKeydown)
  }
})

onUnmounted(() => {
  document.removeEventListener('pointerdown', onDocumentPointer)
  document.removeEventListener('keydown', onKeydown)
})
</script>

<template>
  <div ref="root" class="base-select" :class="{ 'base-select--open': open, 'base-select--disabled': disabled }">
    <button
      :id="id || undefined"
      type="button"
      class="base-select__trigger"
      :disabled="disabled"
      aria-haspopup="listbox"
      :aria-expanded="open"
      :aria-controls="listId"
      :aria-required="required || undefined"
      @click="toggle"
    >
      <span
        class="base-select__value"
        :class="{ 'base-select__value--placeholder': !selectedLabel }"
      >
        {{ selectedLabel || placeholder }}
      </span>
      <svg
        class="base-select__chevron"
        width="16"
        height="16"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        aria-hidden="true"
      >
        <path d="m6 9 6 6 6-6" />
      </svg>
    </button>

    <ul
      v-show="open"
      :id="listId"
      class="base-select__menu"
      role="listbox"
      :aria-labelledby="id || undefined"
    >
      <li
        v-for="option in options"
        :key="String(option.value)"
        role="option"
        class="base-select__option"
        :class="{
          'base-select__option--selected': String(option.value) === String(modelValue),
          'base-select__option--disabled': option.disabled,
        }"
        :aria-selected="String(option.value) === String(modelValue)"
        :aria-disabled="option.disabled || undefined"
        @click="selectOption(option)"
      >
        {{ option.label }}
      </li>
    </ul>
  </div>
</template>

<style scoped>
.base-select {
  position: relative;
  width: 100%;
}

.base-select__trigger {
  display: flex;
  width: 100%;
  height: 2.75rem;
  min-height: 2.75rem;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0 0.875rem;
  border: 1px solid var(--color-border);
  border-radius: 0.625rem;
  background-color: var(--color-page);
  color: var(--color-text);
  font: inherit;
  font-size: 1rem;
  text-align: left;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
  transition:
    border-color 0.15s ease,
    background-color 0.15s ease,
    box-shadow 0.15s ease;
}

.base-select__trigger:focus {
  outline: none;
  border-color: var(--color-accent);
  background-color: var(--color-surface);
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--color-accent) 22%, transparent);
}

.base-select--open .base-select__trigger {
  border-color: var(--color-accent);
  background-color: var(--color-surface);
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--color-accent) 22%, transparent);
}

.base-select--disabled .base-select__trigger {
  opacity: 0.55;
  cursor: not-allowed;
}

.base-select__value {
  min-width: 0;
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.base-select__value--placeholder {
  color: var(--color-muted);
}

.base-select__chevron {
  flex-shrink: 0;
  color: var(--color-muted);
  transition: transform 0.15s ease;
}

.base-select--open .base-select__chevron {
  transform: rotate(180deg);
}

.base-select__menu {
  position: absolute;
  z-index: 30;
  top: calc(100% + 0.35rem);
  left: 0;
  right: 0;
  margin: 0;
  padding: 0.35rem;
  list-style: none;
  max-height: 16rem;
  overflow-y: auto;
  border: 1px solid var(--color-border);
  border-radius: 0.75rem;
  background: var(--color-surface);
  box-shadow: 0 10px 30px rgb(0 0 0 / 0.18);
}

.base-select__option {
  padding: 0.7rem 0.75rem;
  border-radius: 0.5rem;
  font-size: 0.9375rem;
  font-weight: 600;
  color: var(--color-text);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

.base-select__option:hover,
.base-select__option:active {
  background: var(--color-page);
}

.base-select__option--selected {
  background: var(--color-accent-soft);
  color: var(--color-accent);
}

.base-select__option--disabled {
  opacity: 0.45;
  cursor: not-allowed;
}

.base-select__option--disabled:hover {
  background: transparent;
}
</style>
