<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { RouterLink } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useTheme } from '../composables/useTheme'
import Money from '../components/Money.vue'
import BaseButton from '../components/BaseButton.vue'
import BankDetails from '../components/BankDetails.vue'
import AppModal from '../components/AppModal.vue'
import { useToast } from '../composables/useToast'

const { theme, setTheme } = useTheme()
const toast = useToast()

const products = ref([])
const loading = ref(true)
const saving = ref(false)
const submitted = ref(false)
const showGallery = ref(false)
let previousTheme = 'light'

const form = ref({
  customer_name: '',
  company: '',
  contact: '',
  notes: '',
})

const cart = ref({})

const cartItems = computed(() =>
  products.value
    .filter((p) => Number(cart.value[p.id] || 0) > 0)
    .map((p) => ({
      ...p,
      quantity: Number(cart.value[p.id] || 0),
      lineTotal: Number(p.sell_price) * Number(cart.value[p.id] || 0),
    }))
)

const orderTotal = computed(() =>
  cartItems.value.reduce((sum, item) => sum + item.lineTotal, 0)
)

function qty(productId) {
  return Number(cart.value[productId] || 0)
}

function setQty(productId, next) {
  const value = Math.max(0, Math.min(99, Number(next) || 0))
  cart.value = { ...cart.value, [productId]: value }
}

function addOne(productId) {
  setQty(productId, qty(productId) + 1)
}

function removeOne(productId) {
  setQty(productId, qty(productId) - 1)
}

async function loadProducts() {
  loading.value = true
  try {
    const { data, error } = await supabase.rpc('list_public_products')
    if (error) throw error
    products.value = data ?? []
  } catch (e) {
    toast.error(e.message || 'Could not load biscuits')
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  previousTheme = theme.value
  setTheme('light', { persist: false })
  loadProducts()
})

onUnmounted(() => {
  setTheme(previousTheme, { persist: false })
})

async function onSubmit() {
  if (!form.value.customer_name.trim()) {
    toast.error('Please enter your name')
    return
  }
  if (!cartItems.value.length) {
    toast.error('Add at least one biscuit')
    return
  }

  saving.value = true
  try {
    const { error } = await supabase.rpc('submit_biscuit_request', {
      p_customer_name: form.value.customer_name.trim(),
      p_company: form.value.company.trim() || null,
      p_contact: form.value.contact.trim() || null,
      p_notes: form.value.notes.trim() || null,
      p_items: cartItems.value.map((item) => ({
        product_id: item.id,
        quantity: item.quantity,
      })),
    })
    if (error) throw error
    submitted.value = true
    toast.success('Request sent')
  } catch (e) {
    toast.error(e.message || 'Could not send request')
  } finally {
    saving.value = false
  }
}

function resetForm() {
  form.value = {
    customer_name: '',
    company: '',
    contact: '',
    notes: '',
  }
  cart.value = {}
  submitted.value = false
}
</script>

<template>
  <div class="request-page">
    <header class="request-header">
      <div class="request-topbar">
        <p class="request-brand"><span class="request-brand__dot" aria-hidden="true" />Biscuits</p>
        <RouterLink :to="{ name: 'login' }" class="request-login">Login</RouterLink>
      </div>

      <div class="request-hero">
        <h1>Order fresh<br />biscuits</h1>
        <p>Pick what you want, leave your details, and we’ll sort the rest.</p>
        <p class="request-tag">Baked to order, every batch</p>
      </div>
    </header>

    <svg
      class="request-scallop"
      viewBox="0 0 400 18"
      preserveAspectRatio="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
    >
      <path
        d="M0,0 C 16.6,18 33.3,18 50,0 C 66.6,18 83.3,18 100,0 C 116.6,18 133.3,18 150,0 C 166.6,18 183.3,18 200,0 C 216.6,18 233.3,18 250,0 C 266.6,18 283.3,18 300,0 C 316.6,18 333.3,18 350,0 C 366.6,18 383.3,18 400,0 L400,18 L0,18 Z"
        fill="currentColor"
      />
    </svg>

    <main class="request-main" :class="{ 'request-main--with-footer': !submitted }">
      <section v-if="submitted" class="request-card request-success">
        <p class="request-success__title">Request received</p>
        <p class="request-success__copy">
          Thanks {{ form.customer_name.trim() }}. Your biscuit order is in - someone will follow up with you.
        </p>
        <BaseButton class="mt-4" variant="primary" @click="resetForm">
          Place another request
        </BaseButton>
      </section>

      <form
        v-else
        class="request-form"
        @submit.prevent="onSubmit"
      >
        <div class="request-card">
          <p class="request-eyebrow">Your details</p>

          <div class="request-field">
            <label for="req_name">
              Name <span class="request-req" aria-hidden="true">*</span>
            </label>
            <input
              id="req_name"
              v-model="form.customer_name"
              required
              autocomplete="name"
              placeholder="Your full name"
            />
          </div>

          <div class="request-field">
            <label for="req_company">
              Company <span class="request-opt">(optional)</span>
            </label>
            <input
              id="req_company"
              v-model="form.company"
              autocomplete="organization"
              placeholder="Company name"
            />
          </div>

          <div class="request-field">
            <label for="req_contact">
              Phone <span class="request-req" aria-hidden="true">*</span>
            </label>
            <input
              id="req_contact"
              v-model="form.contact"
              type="tel"
              inputmode="tel"
              autocomplete="tel"
              required
              placeholder="+27 00 000 0000"
            />
          </div>

          <div class="request-field request-field--last">
            <label for="req_notes">
              Notes <span class="request-opt">(optional)</span>
            </label>
            <textarea
              id="req_notes"
              v-model="form.notes"
              rows="3"
              placeholder="Allergies, delivery instructions, anything else"
            />
          </div>
        </div>

        <div class="request-card">
          <p class="request-eyebrow">Biscuits</p>

          <button
            type="button"
            class="request-gallery"
            aria-label="View biscuit varieties"
            @click="showGallery = true"
          >
            <img
              src="/images/biscuit-varieties.png?v=2"
              alt="Assorted biscuit boxes: normal mix, chocolate, Hertzoggies, Choc Crust, butter mix, and Romaney creams"
              width="642"
              height="1024"
              loading="lazy"
            />
            <span class="request-gallery__hint">See what they look like</span>
          </button>

          <p v-if="loading" class="request-empty">Loading biscuits…</p>
          <p v-else-if="!products.length" class="request-empty">
            No biscuits available right now.
          </p>

          <div v-else class="request-biscuit-list">
            <div
              v-for="product in products"
              :key="product.id"
              class="request-biscuit"
              :class="{ 'request-biscuit--active': qty(product.id) > 0 }"
            >
              <div class="request-biscuit__info">
                <p class="request-biscuit__name">{{ product.name }}</p>
                <p class="request-biscuit__price">
                  <Money :value="product.sell_price" /> each
                </p>
              </div>
              <div class="request-stepper">
                <button
                  type="button"
                  class="request-stepper__btn request-stepper__btn--minus"
                  :disabled="qty(product.id) <= 0"
                  aria-label="Decrease quantity"
                  @click="removeOne(product.id)"
                >
                  −
                </button>
                <span class="request-stepper__qty">{{ qty(product.id) }}</span>
                <button
                  type="button"
                  class="request-stepper__btn"
                  aria-label="Increase quantity"
                  @click="addOne(product.id)"
                >
                  +
                </button>
              </div>
            </div>
          </div>
        </div>

        <div class="request-footer">
          <div class="request-footer__inner">
            <div class="request-total">
              <p class="request-total__label">Total</p>
              <p class="request-total__amount">
                <Money :value="orderTotal" />
              </p>
            </div>
            <button
              type="submit"
              class="request-send"
              :disabled="saving || loading || !products.length"
            >
              {{ saving ? 'Sending…' : 'Send request' }}
              <span v-if="!saving" aria-hidden="true">→</span>
            </button>
          </div>
        </div>
      </form>
    </main>

    <BankDetails :above-footer="!submitted" />

    <AppModal
      :open="showGallery"
      labelled-by="biscuit-gallery-title"
      max-width-class="max-w-3xl"
      @close="showGallery = false"
    >
      <div class="flex items-start justify-between gap-3 border-b border-border px-4 py-3.5">
        <div>
          <h2 id="biscuit-gallery-title" class="text-base font-extrabold text-text">
            Biscuit varieties
          </h2>
          <p class="mt-0.5 text-xs text-muted">Tap outside or close when you’re done.</p>
        </div>
        <button
          type="button"
          class="request-icon-btn"
          aria-label="Close"
          @click="showGallery = false"
        >
          <svg
            width="18"
            height="18"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            aria-hidden="true"
          >
            <path d="M18 6 6 18M6 6l12 12" />
          </svg>
        </button>
      </div>
      <div class="request-gallery-modal">
        <img
          src="/images/biscuit-varieties.png?v=2"
          alt="Assorted biscuit boxes showing each mix variety"
          width="642"
          height="1024"
        />
      </div>
    </AppModal>
  </div>
</template>

<style scoped>
.request-page {
  --rq-blush: #f2c6b4;
  --rq-blush-soft: #f7d9c8;
  --rq-terracotta: #d97d54;
  --rq-terracotta-dark: #c2673f;
  --rq-cream: #fff8f0;
  --rq-sage: #8b9a7a;
  --rq-sage-dark: #71806a;
  --rq-espresso: #3b2a20;
  --rq-espresso-soft: #6b564a;
  --rq-card: #ffffff;
  --rq-line: #ecdfd5;
  --rq-field: #fefcf9;
  --rq-radius-lg: 1.5rem;
  --rq-radius-md: 1rem;
  --rq-radius-sm: 0.625rem;

  min-height: 100dvh;
  background: var(--rq-cream);
  color: var(--rq-espresso);
}

.request-header {
  position: relative;
  overflow: hidden;
  padding: 1.25rem 1.25rem 1.75rem;
  background: linear-gradient(135deg, var(--rq-blush) 0%, var(--rq-blush-soft) 100%);
}

.request-header::after {
  content: '';
  position: absolute;
  top: -1.875rem;
  right: -1.875rem;
  width: 8.75rem;
  height: 8.75rem;
  border-radius: 50%;
  background: color-mix(in srgb, var(--rq-terracotta) 18%, transparent);
  pointer-events: none;
}

.request-topbar {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
}

.request-brand {
  margin: 0;
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  font-family: 'Fraunces', var(--font-sans);
  font-size: 1.375rem;
  font-weight: 700;
  letter-spacing: -0.02em;
  color: var(--rq-terracotta-dark);
}

.request-brand__dot {
  width: 0.5rem;
  height: 0.5rem;
  border-radius: 50%;
  background: var(--rq-sage);
}

.request-icon-btn {
  display: inline-flex;
  width: 2.375rem;
  height: 2.375rem;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--rq-line);
  border-radius: 0.75rem;
  background: var(--rq-card);
  color: var(--rq-espresso);
  cursor: pointer;
}

.request-login {
  display: inline-flex;
  height: 2.375rem;
  align-items: center;
  padding: 0 1rem;
  border: none;
  border-radius: 0.75rem;
  background: var(--rq-espresso);
  color: var(--rq-cream);
  font-size: 0.8125rem;
  font-weight: 700;
  text-decoration: none;
}

.request-hero {
  position: relative;
  z-index: 1;
  margin-top: 1.6rem;
}

.request-hero h1 {
  margin: 0 0 0.625rem;
  font-family: 'Fraunces', var(--font-sans);
  font-size: clamp(1.85rem, 7vw, 1.875rem);
  font-weight: 600;
  line-height: 1.08;
  letter-spacing: -0.02em;
  color: var(--rq-espresso);
}

.request-hero p {
  margin: 0;
  max-width: 17.5rem;
  color: var(--rq-espresso-soft);
  font-size: 0.875rem;
  line-height: 1.5;
  font-weight: 500;
}

.request-tag {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  margin-top: 0.875rem;
  padding: 0.3rem 0.65rem;
  border-radius: 999px;
  background: color-mix(in srgb, var(--rq-sage) 15%, transparent);
  color: var(--rq-sage-dark);
  font-size: 0.6875rem;
  font-weight: 700;
}

.request-tag::before {
  content: '●';
  font-size: 0.45rem;
}

.request-scallop {
  display: block;
  width: 100%;
  height: 1.125rem;
  margin-top: -1px;
  color: var(--rq-cream);
}

.request-main {
  width: min(25rem, 100%);
  margin: -1px auto 0;
  padding: 0 1.25rem 1.25rem;
}

.request-main--with-footer {
  padding-bottom: calc(6.75rem + env(safe-area-inset-bottom, 0px));
}

.request-form {
  display: flex;
  flex-direction: column;
  gap: 1.125rem;
}

.request-card {
  margin-top: 1.125rem;
  padding: 1.25rem 1.125rem 1.375rem;
  border: 1px solid var(--rq-line);
  border-radius: var(--rq-radius-lg);
  background: var(--rq-card);
  box-shadow: 0 10px 24px -16px rgba(59, 42, 32, 0.15);
}

.request-form .request-card {
  margin-top: 0;
}

.request-eyebrow {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin: 0 0 1rem;
  color: var(--rq-sage-dark);
  font-size: 0.6875rem;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.request-eyebrow::before {
  content: '';
  width: 0.875rem;
  height: 2px;
  border-radius: 2px;
  background: var(--rq-terracotta);
}

.request-field {
  margin-bottom: 1rem;
}

.request-field--last {
  margin-bottom: 0;
}

.request-field label {
  display: block;
  margin-bottom: 0.45rem;
  color: var(--rq-espresso);
  font-size: 0.8125rem;
  font-weight: 700;
}

.request-req {
  color: var(--rq-terracotta);
}

.request-opt {
  color: var(--rq-espresso-soft);
  font-size: 0.75rem;
  font-weight: 500;
}

.request-field input,
.request-field textarea {
  width: 100%;
  border: 1.5px solid var(--rq-line);
  border-radius: var(--rq-radius-sm);
  background: var(--rq-field);
  color: var(--rq-espresso);
  font: inherit;
  font-size: 0.875rem;
  padding: 0.75rem 0.875rem;
  outline: none;
  transition:
    border-color 0.15s ease,
    box-shadow 0.15s ease;
}

.request-field textarea {
  min-height: 4.75rem;
  resize: vertical;
}

.request-field input::placeholder,
.request-field textarea::placeholder {
  color: #c9baae;
}

.request-field input:focus,
.request-field textarea:focus {
  border-color: var(--rq-terracotta);
  box-shadow: 0 0 0 4px color-mix(in srgb, var(--rq-terracotta) 14%, transparent);
}

.request-gallery {
  display: block;
  width: 100%;
  margin: 0 0 0.9rem;
  padding: 0;
  border: 1.5px solid var(--rq-line);
  border-radius: var(--rq-radius-md);
  overflow: hidden;
  background: var(--rq-field);
  cursor: pointer;
  text-align: left;
  transition: transform 0.15s ease;
}

.request-gallery:active {
  transform: scale(0.99);
}

.request-gallery img {
  display: block;
  width: 100%;
  aspect-ratio: 5 / 4;
  object-fit: cover;
  object-position: center;
}

.request-gallery__hint {
  display: block;
  padding: 0.65rem 0.85rem 0.85rem;
  color: var(--rq-terracotta);
  font-size: 0.8125rem;
  font-weight: 800;
}

.request-empty {
  margin: 0;
  color: var(--rq-espresso-soft);
  font-size: 0.875rem;
}

.request-biscuit-list {
  display: flex;
  flex-direction: column;
  gap: 0.625rem;
}

.request-biscuit {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.65rem 0.7rem;
  border: 1.5px solid var(--rq-line);
  border-radius: var(--rq-radius-md);
  background: var(--rq-field);
  transition:
    border-color 0.15s ease,
    background 0.15s ease;
}

.request-biscuit--active {
  border-color: var(--rq-terracotta);
  background: color-mix(in srgb, var(--rq-terracotta) 10%, var(--rq-card));
}

.request-biscuit__info {
  min-width: 0;
  flex: 1;
}

.request-biscuit__name {
  margin: 0 0 0.125rem;
  font-size: 0.875rem;
  font-weight: 800;
  color: var(--rq-espresso);
}

.request-biscuit__price {
  margin: 0;
  color: var(--rq-espresso-soft);
  font-size: 0.78125rem;
  font-weight: 600;
}

.request-stepper {
  display: inline-flex;
  align-items: center;
  gap: 0.55rem;
  flex-shrink: 0;
  padding: 0.25rem 0.4rem;
  border: 1px solid var(--rq-line);
  border-radius: 0.625rem;
  background: var(--rq-cream);
}

.request-stepper__btn {
  display: inline-flex;
  width: 1.4rem;
  height: 1.4rem;
  align-items: center;
  justify-content: center;
  border: none;
  border-radius: 0.375rem;
  background: var(--rq-terracotta);
  color: #fff;
  font-size: 0.85rem;
  font-weight: 800;
  line-height: 1;
  cursor: pointer;
}

.request-stepper__btn--minus {
  background: var(--rq-sage);
}

.request-stepper__btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.request-stepper__qty {
  min-width: 0.9rem;
  text-align: center;
  font-size: 0.8125rem;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  color: var(--rq-espresso);
}

.request-success__title {
  margin: 0;
  color: var(--rq-terracotta);
  font-family: 'Fraunces', var(--font-sans);
  font-size: 1.25rem;
  font-weight: 700;
}

.request-success__copy {
  margin: 0.5rem 0 0;
  color: var(--rq-espresso-soft);
  font-size: 0.875rem;
  line-height: 1.5;
}

.request-gallery-modal {
  padding: 0.75rem;
  overflow: auto;
  max-height: min(78dvh, 42rem);
}

.request-gallery-modal img {
  display: block;
  width: 100%;
  height: auto;
  border-radius: 0.65rem;
}

.request-footer {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 40;
  padding: 0.875rem 1.25rem 1.125rem;
  padding-bottom: calc(1.125rem + env(safe-area-inset-bottom, 0px));
  border-top: 1px solid var(--rq-line);
  background: var(--rq-cream);
}

.request-footer__inner {
  display: flex;
  width: min(25rem, 100%);
  margin: 0 auto;
  align-items: center;
  justify-content: space-between;
  gap: 0.875rem;
}

.request-total__label {
  margin: 0;
  color: var(--rq-espresso-soft);
  font-size: 0.65625rem;
  font-weight: 800;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}

.request-total__amount {
  margin: 0;
  font-family: 'Fraunces', var(--font-sans);
  font-size: 1.375rem;
  font-weight: 600;
  color: var(--rq-espresso);
  font-variant-numeric: tabular-nums;
}

.request-send {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  border: none;
  border-radius: 0.875rem;
  padding: 0.875rem 1.5rem;
  background: var(--rq-terracotta);
  color: #fff;
  font: inherit;
  font-size: 0.90625rem;
  font-weight: 800;
  box-shadow: 0 10px 20px -8px color-mix(in srgb, var(--rq-terracotta) 55%, transparent);
  cursor: pointer;
}

.request-send:hover:not(:disabled) {
  background: var(--rq-terracotta-dark);
}

.request-send:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>
