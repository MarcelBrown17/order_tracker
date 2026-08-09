<script setup>
import { watch, nextTick } from 'vue'
import gsap from 'gsap'
import { useToastStore } from '../stores/toast'

const toastStore = useToastStore()
const elMap = new Map()

function setEl(id, el) {
  if (el) elMap.set(id, el)
  else elMap.delete(id)
}

watch(
  () => toastStore.toasts.map((t) => t.id),
  async (ids, prev = []) => {
    await nextTick()
    const prevSet = new Set(prev)
    for (const id of ids) {
      if (prevSet.has(id)) continue
      const el = elMap.get(id)
      if (!el) continue
      gsap.fromTo(
        el,
        { y: -18, opacity: 0, scale: 0.96 },
        { y: 0, opacity: 1, scale: 1, duration: 0.32, ease: 'power3.out' }
      )
    }
  }
)

function dismiss(id) {
  const el = elMap.get(id)
  if (!el) {
    toastStore.dismiss(id)
    return
  }
  gsap.to(el, {
    y: -12,
    opacity: 0,
    scale: 0.97,
    duration: 0.2,
    ease: 'power2.in',
    onComplete: () => toastStore.dismiss(id),
  })
}
</script>

<template>
  <Teleport to="body">
    <div class="toast-stack" aria-live="polite" aria-relevant="additions">
      <div
        v-for="toast in toastStore.toasts"
        :key="toast.id"
        :ref="(el) => setEl(toast.id, el)"
        class="toast"
        :class="`toast--${toast.type}`"
        role="status"
      >
        <span class="toast__icon" aria-hidden="true">
          <svg
            v-if="toast.type === 'success'"
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2.5"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M20 6 9 17l-5-5" />
          </svg>
          <svg
            v-else-if="toast.type === 'error'"
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2.5"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <circle cx="12" cy="12" r="9" />
            <path d="M12 8v5" />
            <path d="M12 16h.01" />
          </svg>
          <svg
            v-else
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2.5"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <circle cx="12" cy="12" r="9" />
            <path d="M12 8v4" />
            <path d="M12 16h.01" />
          </svg>
        </span>
        <p class="toast__message">{{ toast.message }}</p>
        <button
          type="button"
          class="toast__close"
          aria-label="Dismiss"
          @click="dismiss(toast.id)"
        >
          <svg
            width="14"
            height="14"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2.25"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <path d="M18 6 6 18" />
            <path d="m6 6 12 12" />
          </svg>
        </button>
      </div>
    </div>
  </Teleport>
</template>
