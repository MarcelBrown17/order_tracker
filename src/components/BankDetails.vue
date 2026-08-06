<script setup>
import { ref, watch, onUnmounted } from 'vue'

const open = ref(false)
const copiedId = ref('')

const accounts = [
  {
    id: 'discovery',
    bank: 'Discovery Bank',
    holder: 'Marcel Brown',
    number: '15499225896',
  },
  {
    id: 'standard',
    bank: 'Standard Bank',
    holder: 'MR MARCEL MJ BROWN',
    number: '07 367 890 2',
  },
  {
    id: 'capitec',
    bank: 'Capitec',
    holder: 'Marcel Brown',
    number: '2324219081',
  },
]

function openPanel() {
  open.value = true
  copiedId.value = ''
}

function closePanel() {
  open.value = false
  copiedId.value = ''
}

function onKeydown(e) {
  if (e.key === 'Escape') closePanel()
}

watch(open, (isOpen) => {
  if (typeof document === 'undefined') return
  document.body.style.overflow = isOpen ? 'hidden' : ''
  if (isOpen) {
    window.addEventListener('keydown', onKeydown)
  } else {
    window.removeEventListener('keydown', onKeydown)
  }
})

onUnmounted(() => {
  if (typeof document !== 'undefined') {
    document.body.style.overflow = ''
  }
  window.removeEventListener('keydown', onKeydown)
})

async function copyNumber(account) {
  const digits = account.number.replace(/\s+/g, '')
  try {
    await navigator.clipboard.writeText(digits)
    copiedId.value = account.id
    setTimeout(() => {
      if (copiedId.value === account.id) copiedId.value = ''
    }, 1600)
  } catch {
    copiedId.value = ''
  }
}
</script>

<template>
  <!-- Floating EFT help button (above bottom nav on mobile) -->
  <button
    type="button"
    class="eft-fab fixed z-50 flex h-14 w-14 items-center justify-center rounded-full bg-accent text-white shadow-lg shadow-accent/25 transition-transform active:scale-95"
    aria-label="Show EFT banking details"
    @click="openPanel"
  >
    <svg
      width="22"
      height="22"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <rect x="2" y="5" width="20" height="14" rx="2" />
      <path d="M2 10h20" />
    </svg>
  </button>

  <Teleport to="body">
    <div
      v-if="open"
      class="fixed inset-0 z-[60] flex items-end justify-center sm:items-center sm:p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="eft-dialog-title"
    >
      <button
        type="button"
        class="absolute inset-0 bg-text/40 backdrop-blur-[2px]"
        aria-label="Close banking details"
        @click="closePanel"
      />

      <div
        class="relative z-10 flex max-h-[85dvh] w-full max-w-md flex-col rounded-t-2xl bg-surface shadow-xl sm:rounded-2xl"
      >
        <div class="flex items-start justify-between gap-3 border-b border-border px-4 py-3.5">
          <div>
            <h2 id="eft-dialog-title" class="text-base font-extrabold">
              EFT banking details
            </h2>
            <p class="mt-0.5 text-xs text-muted">
              For customer payments. Keep within the business.
            </p>
          </div>
          <button
            type="button"
            class="icon-btn !min-h-10 !min-w-10"
            aria-label="Close"
            @click="closePanel"
          >
            <svg
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              aria-hidden="true"
            >
              <path d="M18 6 6 18" />
              <path d="m6 6 12 12" />
            </svg>
          </button>
        </div>

        <div class="space-y-2.5 overflow-y-auto p-4">
          <div
            v-for="account in accounts"
            :key="account.id"
            class="rounded-xl border border-border bg-page p-3.5"
          >
            <div class="flex items-start justify-between gap-2">
              <p class="font-bold">{{ account.bank }}</p>
              <button
                type="button"
                class="shrink-0 rounded-lg px-2 py-1 text-xs font-bold text-accent"
                @click="copyNumber(account)"
              >
                {{ copiedId === account.id ? 'Copied' : 'Copy no.' }}
              </button>
            </div>
            <div class="mt-2 space-y-1 text-sm">
              <div class="flex justify-between gap-3">
                <span class="text-muted">Account holder</span>
                <span class="text-right font-semibold">{{ account.holder }}</span>
              </div>
              <div class="flex justify-between gap-3">
                <span class="text-muted">Account number</span>
                <span class="text-right font-bold tabular-nums">{{ account.number }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.eft-fab {
  right: 1rem;
  bottom: calc(4.75rem + env(safe-area-inset-bottom, 0px));
}

@media (min-width: 768px) {
  .eft-fab {
    bottom: 1.5rem;
    right: 1.5rem;
  }
}
</style>
