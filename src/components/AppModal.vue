<script setup>
import { ref, watch, nextTick, onUnmounted } from 'vue'
import gsap from 'gsap'

const props = defineProps({
  open: Boolean,
  labelledBy: {
    type: String,
    default: '',
  },
  maxWidthClass: {
    type: String,
    default: 'max-w-lg',
  },
  panelClass: {
    type: String,
    default: '',
  },
})

const emit = defineEmits(['close'])

const visible = ref(false)
const backdropEl = ref(null)
const panelEl = ref(null)
let activeTween = null

function isMobile() {
  return typeof window !== 'undefined' && window.matchMedia('(max-width: 639px)').matches
}

function killTween() {
  if (activeTween) {
    activeTween.kill()
    activeTween = null
  }
}

async function animateIn() {
  visible.value = true
  await nextTick()
  killTween()

  const mobile = isMobile()
  gsap.set(backdropEl.value, { opacity: 0 })
  gsap.set(
    panelEl.value,
    mobile
      ? { yPercent: 100, opacity: 1, scale: 1 }
      : { y: 28, opacity: 0, scale: 0.96 }
  )

  activeTween = gsap
    .timeline({
      defaults: { ease: 'power3.out' },
    })
    .to(backdropEl.value, { opacity: 1, duration: 0.32 }, 0)
    .to(
      panelEl.value,
      mobile
        ? { yPercent: 0, duration: 0.42 }
        : { y: 0, opacity: 1, scale: 1, duration: 0.38 },
      0.04
    )
}

function animateOut() {
  return new Promise((resolve) => {
    if (!visible.value) {
      resolve()
      return
    }
    killTween()
    const mobile = isMobile()
    activeTween = gsap
      .timeline({
        defaults: { ease: 'power2.in' },
        onComplete: () => {
          visible.value = false
          activeTween = null
          resolve()
        },
      })
      .to(backdropEl.value, { opacity: 0, duration: 0.22 }, 0)
      .to(
        panelEl.value,
        mobile
          ? { yPercent: 100, duration: 0.3 }
          : { y: 18, opacity: 0, scale: 0.97, duration: 0.24 },
        0
      )
  })
}

watch(
  () => props.open,
  async (isOpen) => {
    if (typeof document === 'undefined') return
    if (isOpen) {
      document.body.style.overflow = 'hidden'
      await animateIn()
    } else {
      await animateOut()
      document.body.style.overflow = ''
    }
  }
)

function onKeydown(e) {
  if (e.key === 'Escape' && props.open) emit('close')
}

watch(
  () => props.open,
  (isOpen) => {
    if (isOpen) window.addEventListener('keydown', onKeydown)
    else window.removeEventListener('keydown', onKeydown)
  }
)

onUnmounted(() => {
  killTween()
  window.removeEventListener('keydown', onKeydown)
  if (typeof document !== 'undefined') {
    document.body.style.overflow = ''
  }
})
</script>

<template>
  <Teleport to="body">
    <div
      v-if="visible"
      class="modal-root fixed inset-0 z-[60] flex items-end justify-center sm:items-center sm:p-4"
      role="dialog"
      aria-modal="true"
      :aria-labelledby="labelledBy || undefined"
    >
      <button
        ref="backdropEl"
        type="button"
        class="modal-backdrop absolute inset-0"
        aria-label="Close dialog"
        @click="emit('close')"
      />

      <div
        ref="panelEl"
        class="modal-panel relative z-10 flex max-h-[90dvh] w-full flex-col"
        :class="[maxWidthClass, panelClass]"
      >
        <slot />
      </div>
    </div>
  </Teleport>
</template>
