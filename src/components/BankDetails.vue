<script setup>
import { ref } from 'vue'
import AppModal from './AppModal.vue'
import { useToast } from '../composables/useToast'

defineProps({
  /** Lift FAB above a page footer (e.g. public request bar) */
  aboveFooter: Boolean,
})

const open = ref(false)
const copiedId = ref('')
const toast = useToast()

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
    holder: 'Marcel Brown',
    number: '073678902',
  },
  {
    id: 'capitec',
    bank: 'Capitec',
    holder: 'Marcel Brown',
    number: '2324219081',
  },
]

const contact = {
  email: 'marcelbrown413@gmail.com',
  phone: '0812721154',
  phoneHref: 'tel:+27812721154',
}

function openPanel() {
  open.value = true
  copiedId.value = ''
}

function closePanel() {
  open.value = false
  copiedId.value = ''
}

async function writeClipboard(text) {
  if (navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(text)
    return
  }
  const input = document.createElement('textarea')
  input.value = text
  input.setAttribute('readonly', '')
  input.style.position = 'fixed'
  input.style.opacity = '0'
  document.body.appendChild(input)
  input.select()
  document.execCommand('copy')
  document.body.removeChild(input)
}

async function copyText(id, text, successMessage) {
  try {
    await writeClipboard(text)
    copiedId.value = id
    toast.success(successMessage)
    setTimeout(() => {
      if (copiedId.value === id) copiedId.value = ''
    }, 1600)
  } catch {
    copiedId.value = ''
    toast.error('Could not copy')
  }
}

async function copyAccount(account) {
  const text = [
    `Bank: ${account.bank}`,
    `Account holder: ${account.holder}`,
    `Account number: ${account.number.replace(/\s+/g, '')}`,
    'Reference: use your name',
  ].join('\n')
  await copyText(account.id, text, `${account.bank} details copied`)
}
</script>

<template>
  <button
    type="button"
    class="eft-fab fixed z-50 flex h-10 w-10 items-center justify-center rounded-full bg-accent text-white shadow-md shadow-black/10 transition-transform duration-200 active:scale-95 sm:h-11 sm:w-11"
    :class="{ 'eft-fab--above-footer': aboveFooter }"
    aria-label="Show payment methods"
    @click="openPanel"
  >
    <svg
      class="h-4 w-4 sm:h-[18px] sm:w-[18px]"
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

  <AppModal
    :open="open"
    labelled-by="eft-dialog-title"
    max-width-class="max-w-md"
    @close="closePanel"
  >
    <div class="flex items-start justify-between gap-3 border-b border-border px-4 py-3.5">
      <div>
        <h2 id="eft-dialog-title" class="text-base font-extrabold text-text">
          Payment methods
        </h2>
        <p class="mt-0.5 text-xs text-muted">
          EFT details for biscuit orders.
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
      <p class="rounded-xl border border-accent/25 bg-accent-soft px-3.5 py-3 text-sm font-semibold text-text">
        Use your <span class="font-extrabold text-accent">name</span> as the payment reference so we can match your order.
      </p>

      <div
        v-for="account in accounts"
        :key="account.id"
        class="rounded-xl border border-border bg-page p-3.5"
      >
        <div class="flex items-start justify-between gap-2">
          <p class="font-bold text-text">{{ account.bank }}</p>
          <button
            type="button"
            class="copy-icon-btn"
            :aria-label="
              copiedId === account.id
                ? 'Account details copied'
                : `Copy ${account.bank} details`
            "
            :title="copiedId === account.id ? 'Copied' : 'Copy bank details'"
            @click="copyAccount(account)"
          >
            <svg
              v-if="copiedId === account.id"
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2.25"
              stroke-linecap="round"
              stroke-linejoin="round"
              aria-hidden="true"
            >
              <path d="M20 6 9 17l-5-5" />
            </svg>
            <svg
              v-else
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
              <rect x="9" y="9" width="13" height="13" rx="2" />
              <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
            </svg>
          </button>
        </div>
        <div class="mt-2 space-y-1 text-sm">
          <div class="flex justify-between gap-3">
            <span class="text-muted">Account holder</span>
            <span class="text-right font-semibold text-text">{{ account.holder }}</span>
          </div>
          <div class="flex justify-between gap-3">
            <span class="text-muted">Account number</span>
            <span class="text-right font-bold tabular-nums text-text">{{ account.number }}</span>
          </div>
        </div>
      </div>

      <div class="rounded-xl border border-border bg-page p-3.5">
        <p class="font-bold text-text">Need help?</p>
        <p class="mt-0.5 text-xs text-muted">Questions about an order or payment.</p>
        <div class="mt-3 space-y-1 text-sm">
          <div class="flex justify-between gap-3">
            <span class="text-muted">Email</span>
            <a
              class="contact-link min-w-0 text-right font-semibold text-accent"
              :href="`mailto:${contact.email}`"
            >
              {{ contact.email }}
            </a>
          </div>
          <div class="flex justify-between gap-3">
            <span class="text-muted">Phone</span>
            <a
              class="contact-link text-right font-semibold tabular-nums text-accent"
              :href="contact.phoneHref"
            >
              {{ contact.phone }}
            </a>
          </div>
        </div>
      </div>
    </div>
  </AppModal>
</template>

<style scoped>
.eft-fab {
  right: 0.85rem;
  bottom: calc(4.5rem + env(safe-area-inset-bottom, 0px));
}

.eft-fab--above-footer {
  bottom: calc(5.75rem + env(safe-area-inset-bottom, 0px));
}

@media (min-width: 768px) {
  .eft-fab {
    bottom: 1.5rem;
    right: 1.5rem;
  }

  .eft-fab--above-footer {
    bottom: 6.5rem;
  }
}

@media (min-width: 1024px) {
  .eft-fab {
    right: 2rem;
    bottom: 2rem;
  }

  .eft-fab--above-footer {
    bottom: 6.75rem;
    right: 2rem;
  }
}

.copy-icon-btn {
  display: inline-flex;
  height: 2.25rem;
  width: 2.25rem;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--color-border);
  border-radius: 0.65rem;
  background: var(--color-surface);
  color: var(--color-accent);
  -webkit-tap-highlight-color: transparent;
}

.copy-icon-btn:active {
  background: var(--color-accent-soft);
}

.contact-link {
  text-decoration: underline;
  text-underline-offset: 0.15em;
}

.contact-link:hover {
  color: var(--color-accent-hover);
}
</style>
