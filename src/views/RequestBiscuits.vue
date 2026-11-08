<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { RouterLink } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useTheme } from '../composables/useTheme'
import Money from '../components/Money.vue'
import BankDetails from '../components/BankDetails.vue'
import BrandLogo from '../components/BrandLogo.vue'
import ProductArt from '../components/ProductArt.vue'
import { useToast } from '../composables/useToast'
import { PRODUCT_CATEGORIES } from '../lib/productGroups'
import { productArt } from '../lib/productArt'

const { theme, setTheme } = useTheme()
const toast = useToast()

const products = ref([])
const loading = ref(true)
const saving = ref(false)
const submittedName = ref('')
const customerName = ref('')
const cart = ref({})
const filter = ref('all')
const cartOpen = ref(false)
const payWhen = ref('now')

function formatDay(date) {
  return date.toLocaleDateString('en-ZA', { day: 'numeric', month: 'long', year: 'numeric' })
}

const paymentOptions = computed(() => {
  const now = new Date()
  const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0)
  return [
    { value: 'now', label: 'Now', date: formatDay(now) },
    { value: 'eom', label: 'End of month', date: formatDay(monthEnd) },
  ]
})
let previousTheme = 'light'

const filters = computed(() => [
  { value: 'all', label: 'All' },
  ...PRODUCT_CATEGORIES.filter((c) =>
    products.value.some((p) => (p.category || 'biscuits') === c.value)
  ),
])

const catalog = computed(() =>
  products.value.map((p, index) => ({
    ...p,
    art: productArt(p, index),
    categoryLabel:
      PRODUCT_CATEGORIES.find((c) => c.value === (p.category || 'biscuits'))
        ?.label || 'Biscuits',
  }))
)

const visibleProducts = computed(() =>
  filter.value === 'all'
    ? catalog.value
    : catalog.value.filter((p) => (p.category || 'biscuits') === filter.value)
)

const cartItems = computed(() =>
  catalog.value
    .filter((p) => qty(p.id) > 0)
    .map((p) => ({
      ...p,
      quantity: qty(p.id),
      lineTotal: Number(p.sell_price) * qty(p.id),
    }))
)

const cartCount = computed(() =>
  cartItems.value.reduce((sum, item) => sum + item.quantity, 0)
)

const subtotal = computed(() =>
  cartItems.value.reduce((sum, item) => sum + item.lineTotal, 0)
)

function qty(productId) {
  return Number(cart.value[productId] || 0)
}

function adjust(productId, delta) {
  const next = Math.max(0, Math.min(99, qty(productId) + delta))
  const updated = { ...cart.value }
  if (next) updated[productId] = next
  else delete updated[productId]
  cart.value = updated
}

function addToCart(product) {
  adjust(product.id, 1)
  toast.success(`${product.name} added`)
}

function openCart() {
  cartOpen.value = true
}

function closeCart() {
  cartOpen.value = false
}

function onKeydown(e) {
  if (e.key === 'Escape' && cartOpen.value) closeCart()
}

watch(cartOpen, (open) => {
  document.body.style.overflow = open ? 'hidden' : ''
})

async function loadProducts() {
  loading.value = true
  try {
    const { data, error } = await supabase.rpc('list_public_products')
    if (error) throw error
    products.value = data ?? []
  } catch (e) {
    toast.error(e.message || 'Could not load products')
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  previousTheme = theme.value
  setTheme('light', { persist: false })
  window.addEventListener('keydown', onKeydown)
  loadProducts()
})

onUnmounted(() => {
  window.removeEventListener('keydown', onKeydown)
  document.body.style.overflow = ''
  setTheme(previousTheme, { persist: false })
})

async function checkout() {
  const name = customerName.value.trim()
  if (!name) {
    toast.error('Please enter your name')
    return
  }
  if (!cartItems.value.length) {
    toast.error('Add at least one item')
    return
  }

  saving.value = true
  try {
    const { error } = await supabase.rpc('submit_biscuit_request', {
      p_customer_name: name,
      p_company: null,
      p_contact: null,
      p_notes: null,
      p_items: cartItems.value.map((item) => ({
        product_id: item.id,
        quantity: item.quantity,
      })),
      p_pay_eom: payWhen.value === 'eom',
    })
    if (error) throw error
    submittedName.value = name
    cart.value = {}
    customerName.value = ''
    payWhen.value = 'now'
    closeCart()
    window.scrollTo({ top: 0, behavior: 'smooth' })
    toast.success('Order sent')
  } catch (e) {
    toast.error(e.message || 'Could not send order')
  } finally {
    saving.value = false
  }
}

function startAgain() {
  submittedName.value = ''
}
</script>

<template>
  <div class="shop">
    <p class="shop-announce">Baked in small batches. Packed by hand.</p>

    <header class="shop-header">
      <RouterLink :to="{ name: 'request-biscuits' }" class="brand-logo">
        <BrandLogo />
      </RouterLink>
      <div class="shop-header__actions">
        <RouterLink :to="{ name: 'login' }" class="pill-btn">
          <svg
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <circle cx="12" cy="8" r="4" />
            <path d="M4 21a8 8 0 0 1 16 0" />
          </svg>
          Login
        </RouterLink>
        <button
          type="button"
          class="pill-btn"
          :aria-label="`Open cart, ${cartCount} items`"
          @click="openCart"
        >
          <svg
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <path d="M5 8h14l-1.2 11H6.2z" />
            <path d="M9 8V6a3 3 0 0 1 6 0v2" />
          </svg>
          <span class="shop-header__cart-label">Cart</span>
          <span class="shop-count">{{ cartCount }}</span>
        </button>
      </div>
    </header>

    <section class="shop-hero">
      <div class="shop-hero__copy">
        <span class="shop-tag">BAKED TO ORDER</span>
        <h1>Biscuits worth hiding from the family.</h1>
        <p>Pick a few, add them to your cart, and we bake them fresh.</p>
      </div>
      <svg
        class="shop-hero__art"
        viewBox="0 0 480 440"
        aria-hidden="true"
      >
        <circle cx="240" cy="220" r="206" fill="#c2255c" />
        <circle cx="168" cy="236" r="96" fill="#e9b563" />
        <circle
          cx="168"
          cy="236"
          r="80"
          fill="none"
          stroke="#8a5a22"
          stroke-opacity="0.35"
          stroke-width="3"
          stroke-dasharray="2 10"
          stroke-linecap="round"
        />
        <circle cx="136" cy="206" r="10" fill="#5a3320" />
        <circle cx="190" cy="196" r="9" fill="#5a3320" />
        <circle cx="214" cy="250" r="10" fill="#5a3320" />
        <circle cx="150" cy="268" r="9" fill="#5a3320" />
        <circle cx="184" cy="286" r="8" fill="#5a3320" />
        <circle cx="120" cy="244" r="7" fill="#5a3320" />
        <circle cx="328" cy="170" r="78" fill="#6b3e28" />
        <circle cx="296" cy="150" r="13" fill="#f2d3a4" />
        <circle cx="346" cy="144" r="11" fill="#f2d3a4" />
        <circle cx="352" cy="196" r="12" fill="#f2d3a4" />
        <circle cx="304" cy="200" r="10" fill="#f2d3a4" />
        <circle cx="326" cy="168" r="8" fill="#2a1a12" />
        <circle cx="296" cy="336" r="76" fill="#f2d4a0" />
        <circle cx="304" cy="328" r="70" fill="#f5c84b" />
        <circle cx="312" cy="320" r="64" fill="#f2d4a0" />
        <circle cx="312" cy="320" r="20" fill="#c2255c" />
      </svg>
    </section>

    <main class="shop-main">
      <section v-if="submittedName" class="shop-success">
        <h2>Order received</h2>
        <p>
          Thanks {{ submittedName }}. Your order is in. Someone will follow up
          with you.
        </p>
        <button type="button" class="shop-btn" @click="startAgain">
          Place another order
        </button>
      </section>

      <template v-else>
        <div class="shop-section-head">
          <div>
            <h2>Fresh from the oven</h2>
            <p>Every pack is baked to order.</p>
          </div>
          <div
            v-if="filters.length > 2"
            role="group"
            aria-label="Filter by type"
            class="shop-chips"
          >
            <button
              v-for="chip in filters"
              :key="chip.value"
              type="button"
              class="shop-chip"
              :class="{ 'shop-chip--active': filter === chip.value }"
              :aria-pressed="filter === chip.value"
              @click="filter = chip.value"
            >
              {{ chip.label }}
            </button>
          </div>
        </div>

        <p v-if="loading" class="shop-empty">Loading products…</p>
        <p v-else-if="!products.length" class="shop-empty">
          Nothing available right now.
        </p>

        <div v-else class="shop-grid">
          <article
            v-for="product in visibleProducts"
            :key="product.id"
            class="shop-card"
          >
            <div class="shop-card__art" :style="{ background: product.art.bg }">
              <ProductArt :art="product.art" />
            </div>
            <div class="shop-card__body">
              <span class="shop-card__category">
                {{ product.categoryLabel }}
              </span>
              <h3>{{ product.name }}</h3>
            </div>
            <div class="shop-card__foot">
              <span class="shop-card__price">
                <Money :value="product.sell_price" />
              </span>
              <button
                type="button"
                class="shop-btn shop-btn--sm"
                @click="addToCart(product)"
              >
                {{ qty(product.id) ? `Add another (${qty(product.id)})` : 'Add to cart' }}
              </button>
            </div>
          </article>
        </div>
      </template>
    </main>

    <button
      v-if="cartCount && !cartOpen && !submittedName"
      type="button"
      class="shop-cartbar"
      @click="openCart"
    >
      <span>View cart ({{ cartCount }})</span>
      <span class="shop-cartbar__total"><Money :value="subtotal" /></span>
    </button>

    <footer class="shop-footer">
      <BrandLogo />
      <p>Small-batch biscuits, baked fresh and packed by hand.</p>
    </footer>

    <BankDetails :above-footer="!!cartCount && !submittedName" />

    <Teleport to="body">
      <Transition name="shop-drawer">
        <div v-if="cartOpen" class="shop-drawer">
          <button
            type="button"
            class="shop-drawer__scrim"
            aria-label="Close cart"
            @click="closeCart"
          />
          <form
            class="shop-drawer__panel"
            aria-label="Your cart"
            @submit.prevent="checkout"
          >
            <div class="shop-drawer__head">
              <h2>Your cart</h2>
              <button
                type="button"
                class="shop-round-btn"
                aria-label="Close cart"
                @click="closeCart"
              >
                <svg
                  width="18"
                  height="18"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2.5"
                  stroke-linecap="round"
                  aria-hidden="true"
                >
                  <path d="M5 5l14 14M19 5L5 19" />
                </svg>
              </button>
            </div>

            <div class="shop-drawer__items">
              <p v-if="!cartItems.length" class="shop-empty">
                Nothing in here yet. Add something from the shop and it will
                show up.
              </p>
              <div
                v-for="item in cartItems"
                :key="item.id"
                class="shop-line"
              >
                <div class="shop-line__thumb" :style="{ background: item.art.bg }">
                  <ProductArt :art="item.art" />
                </div>
                <div class="shop-line__info">
                  <span class="shop-line__name">{{ item.name }}</span>
                  <div class="shop-line__qty">
                    <button
                      type="button"
                      class="shop-round-btn"
                      :aria-label="`Remove one ${item.name}`"
                      @click="adjust(item.id, -1)"
                    >
                      −
                    </button>
                    <span>{{ item.quantity }}</span>
                    <button
                      type="button"
                      class="shop-round-btn"
                      :aria-label="`Add one ${item.name}`"
                      @click="adjust(item.id, 1)"
                    >
                      +
                    </button>
                  </div>
                </div>
                <span class="shop-line__total"><Money :value="item.lineTotal" /></span>
              </div>
            </div>

            <div class="shop-drawer__foot">
              <div class="shop-field">
                <label for="shop_name">
                  Your name <span class="shop-req" aria-hidden="true">*</span>
                </label>
                <input
                  id="shop_name"
                  v-model="customerName"
                  required
                  autocomplete="name"
                  placeholder="Your full name"
                />
              </div>
              <fieldset class="shop-pay">
                <legend>When will you pay?</legend>
                <div class="shop-pay__options">
                  <label
                    v-for="option in paymentOptions"
                    :key="option.value"
                    class="shop-pay__option"
                    :class="{ 'is-active': payWhen === option.value }"
                  >
                    <input
                      v-model="payWhen"
                      type="radio"
                      name="shop_pay_when"
                      :value="option.value"
                    />
                    <span class="shop-pay__label">{{ option.label }}</span>
                    <span class="shop-pay__date">{{ option.date }}</span>
                  </label>
                </div>
              </fieldset>
              <div class="shop-subtotal">
                <span>Subtotal</span>
                <strong><Money :value="subtotal" /></strong>
              </div>
              <button
                type="submit"
                class="shop-btn shop-btn--block"
                :disabled="saving || !cartItems.length"
              >
                {{ saving ? 'Sending…' : 'Place order' }}
              </button>
            </div>
          </form>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<style scoped>
.shop,
.shop-drawer {
  --sf-ink: #2a1a12;
  --sf-ink-soft: #5a4338;
  --sf-cream: #fff9ee;
  --sf-accent: #c2255c;
  --sf-accent-dark: #a01d4b;
  --sf-butter: #f5c84b;
  --sf-pink: #f7c9d4;
  --sf-plum: #8a2d52;
}

.shop {
  display: flex;
  min-height: 100dvh;
  flex-direction: column;
  background: var(--sf-cream);
  color: var(--sf-ink);
  font-family: var(--font-sans);
}

.shop-announce {
  margin: 0;
  padding: 0.6rem 1rem;
  background: var(--sf-ink);
  color: var(--sf-cream);
  text-align: center;
  font-size: 0.8125rem;
  font-weight: 500;
}

.shop-header {
  display: flex;
  width: 100%;
  max-width: 85rem;
  margin: 0 auto;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 1rem 1.25rem;
}

.shop-header__actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.shop-count {
  display: inline-flex;
  min-width: 1.6rem;
  height: 1.6rem;
  align-items: center;
  justify-content: center;
  padding: 0 0.4rem;
  border-radius: 999px;
  background: var(--sf-accent);
  color: #fff;
  font-size: 0.8125rem;
}

.shop-hero {
  display: flex;
  align-items: center;
  gap: 2rem;
  margin: 0 1rem;
  padding: 2rem 1.5rem;
  border-radius: 2rem;
  background: var(--sf-butter);
}

.shop-hero__copy {
  display: flex;
  flex: 1 1 26rem;
  flex-direction: column;
  align-items: flex-start;
  gap: 1rem;
}

.shop-hero__art {
  display: none;
  width: 100%;
  max-width: 28rem;
  height: auto;
  flex: 1 1 20rem;
}

.shop-tag {
  padding: 0.4rem 0.9rem;
  border-radius: 999px;
  background: var(--sf-ink);
  color: var(--sf-cream);
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.04em;
}

.shop-hero h1 {
  max-width: 14ch;
  margin: 0;
  font-family: var(--font-display);
  font-size: clamp(2.25rem, 9vw, 4.5rem);
  font-weight: 800;
  line-height: 0.95;
  letter-spacing: -0.035em;
}

.shop-hero p {
  max-width: 32rem;
  margin: 0;
  font-size: 1.05rem;
  line-height: 1.5;
}

.shop-main {
  width: 100%;
  max-width: 85rem;
  margin: 0 auto;
  padding: 2.5rem 1.25rem 3rem;
}

.shop-section-head {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  justify-content: space-between;
  gap: 1.25rem;
  margin-bottom: 1.5rem;
}

.shop-section-head h2,
.shop-success h2 {
  margin: 0;
  font-family: var(--font-display);
  font-size: clamp(2rem, 6vw, 3.25rem);
  font-weight: 800;
  line-height: 1;
  letter-spacing: -0.03em;
}

.shop-section-head p {
  margin: 0.5rem 0 0;
  font-size: 1rem;
}

.shop-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.shop-chip {
  min-height: 2.75rem;
  padding: 0 1.15rem;
  border: 2px solid var(--sf-ink);
  border-radius: 999px;
  background: transparent;
  color: var(--sf-ink);
  font-size: 0.9375rem;
  font-weight: 700;
  cursor: pointer;
}

.shop-chip--active {
  background: var(--sf-ink);
  color: var(--sf-cream);
}

.shop-empty {
  margin: 0;
  color: var(--sf-ink-soft);
  font-size: 1rem;
  line-height: 1.5;
}

.shop-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(15.5rem, 1fr));
  gap: 1.25rem;
}

.shop-card {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding: 0.875rem 0.875rem 1.25rem;
  border: 2px solid var(--sf-ink);
  border-radius: 1.75rem;
  background: #fff;
}

.shop-card__art {
  display: flex;
  aspect-ratio: 1 / 1;
  align-items: center;
  justify-content: center;
  border-radius: 1.25rem;
}

.shop-card__art svg {
  width: 72%;
  height: 72%;
}

.shop-card__body {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  padding: 0 0.35rem;
}

.shop-card__category {
  color: var(--sf-plum);
  font-size: 0.8125rem;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.shop-card h3 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 1.4rem;
  font-weight: 800;
  line-height: 1.1;
  letter-spacing: -0.02em;
}

.shop-card__foot {
  display: flex;
  margin-top: auto;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0 0.35rem;
}

.shop-card__price {
  font-family: var(--font-display);
  font-size: 1.5rem;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}

.shop-btn {
  display: inline-flex;
  min-height: 3.25rem;
  align-items: center;
  justify-content: center;
  padding: 0 1.75rem;
  border: 0;
  border-radius: 999px;
  background: var(--sf-accent);
  color: #fff;
  font-size: 1rem;
  font-weight: 700;
  cursor: pointer;
}

.shop-btn:hover:not(:disabled) {
  background: var(--sf-accent-dark);
}

.shop-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.shop-btn--sm {
  min-height: 3rem;
  padding: 0 1.1rem;
  font-size: 0.9rem;
}

.shop-btn--block {
  width: 100%;
}

.shop-success {
  display: flex;
  max-width: 36rem;
  flex-direction: column;
  align-items: flex-start;
  gap: 1rem;
  padding: 2rem 1.5rem;
  border: 2px solid var(--sf-ink);
  border-radius: 1.75rem;
  background: #fff;
}

.shop-success p {
  margin: 0;
  font-size: 1.05rem;
  line-height: 1.5;
}

.shop-cartbar {
  position: fixed;
  right: 1rem;
  bottom: calc(1rem + env(safe-area-inset-bottom, 0px));
  left: 1rem;
  z-index: 40;
  display: flex;
  min-height: 3.5rem;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 0 1.5rem;
  border: 0;
  border-radius: 999px;
  background: var(--sf-ink);
  color: var(--sf-cream);
  font-size: 1rem;
  font-weight: 700;
  cursor: pointer;
  box-shadow: 0 12px 28px -12px rgb(42 26 18 / 0.55);
}

.shop-cartbar__total {
  font-family: var(--font-display);
  font-size: 1.2rem;
  font-weight: 800;
}

.shop-footer {
  display: flex;
  margin-top: auto;
  flex-direction: column;
  gap: 0.75rem;
  padding: 2.5rem 1.5rem calc(6rem + env(safe-area-inset-bottom, 0px));
  background: var(--sf-ink);
  color: var(--sf-cream);
}

.shop-footer :deep(.brand-logo__name) {
  color: var(--sf-cream);
}

.shop-footer p {
  margin: 0;
  color: #e3d4c0;
  font-size: 0.9375rem;
}

.shop-drawer {
  position: fixed;
  inset: 0;
  z-index: 60;
  display: flex;
  justify-content: flex-end;
  font-family: var(--font-sans);
  color: #2a1a12;
}

.shop-drawer__scrim {
  position: absolute;
  inset: 0;
  border: 0;
  background: rgb(42 26 18 / 0.55);
  cursor: default;
}

.shop-drawer__panel {
  position: relative;
  display: flex;
  width: 26.25rem;
  max-width: 100%;
  height: 100%;
  flex-direction: column;
  border-left: 2px solid #2a1a12;
  background: #fff9ee;
}

.shop-drawer__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1.25rem 1.5rem;
  border-bottom: 2px solid #2a1a12;
}

.shop-drawer__head h2 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 1.85rem;
  font-weight: 800;
  letter-spacing: -0.02em;
}

.shop-round-btn {
  display: inline-flex;
  width: 2.75rem;
  height: 2.75rem;
  flex: none;
  align-items: center;
  justify-content: center;
  border: 2px solid #2a1a12;
  border-radius: 999px;
  background: transparent;
  color: #2a1a12;
  font-size: 1.25rem;
  font-weight: 700;
  cursor: pointer;
}

.shop-drawer__items {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 1.25rem;
  overflow-y: auto;
  padding: 1.5rem;
}

.shop-line {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.shop-line__thumb {
  display: flex;
  width: 4rem;
  height: 4rem;
  flex: none;
  align-items: center;
  justify-content: center;
  border-radius: 1rem;
}

.shop-line__thumb svg {
  width: 70%;
  height: 70%;
}

.shop-line__info {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 0.4rem;
}

.shop-line__name {
  font-size: 1rem;
  font-weight: 700;
}

.shop-line__qty {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.shop-line__qty span {
  min-width: 1.25rem;
  text-align: center;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}

.shop-line__total {
  font-family: var(--font-display);
  font-size: 1.2rem;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}

.shop-drawer__foot {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding: 1.5rem;
  padding-bottom: calc(1.5rem + env(safe-area-inset-bottom, 0px));
  border-top: 2px solid #2a1a12;
}

.shop-field label {
  display: block;
  margin-bottom: 0.45rem;
  font-size: 0.9375rem;
  font-weight: 700;
}

.shop-req {
  color: #c2255c;
}

.shop-field input {
  width: 100%;
  height: auto;
  min-height: 3.25rem;
  max-height: none;
  padding: 0.75rem 1.25rem;
  border: 2px solid #2a1a12;
  border-radius: 999px;
  background: #fff;
  color: #2a1a12;
  font: inherit;
  font-size: 1rem;
  line-height: 1.2;
  outline: none;
}

.shop-field input:focus {
  box-shadow: 0 0 0 3px #f7c9d4;
}

.shop-pay {
  margin: 0;
  padding: 0;
  border: 0;
  min-width: 0;
}

.shop-pay legend {
  margin-bottom: 0.45rem;
  padding: 0;
  font-size: 0.9375rem;
  font-weight: 700;
}

.shop-pay__options {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.6rem;
}

.shop-pay__option {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
  padding: 0.7rem 1rem;
  border: 2px solid #2a1a12;
  border-radius: 1rem;
  background: #fff;
  cursor: pointer;
  transition: background 0.15s ease, box-shadow 0.15s ease;
}

.shop-pay__option input {
  position: absolute;
  opacity: 0;
  pointer-events: none;
}

.shop-pay__option:focus-within {
  box-shadow: 0 0 0 3px #f7c9d4;
}

.shop-pay__option.is-active {
  background: #f5c84b;
  box-shadow: 3px 3px 0 #2a1a12;
}

.shop-pay__label {
  font-weight: 800;
}

.shop-pay__date {
  font-size: 0.8125rem;
  color: #5a4338;
}

.shop-subtotal {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  font-size: 1.1rem;
  font-weight: 500;
}

.shop-subtotal strong {
  font-family: var(--font-display);
  font-size: 1.9rem;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}

.shop-drawer-enter-active,
.shop-drawer-leave-active {
  transition: opacity 0.2s ease;
}

.shop-drawer-enter-active .shop-drawer__panel,
.shop-drawer-leave-active .shop-drawer__panel {
  transition: transform 0.25s ease;
}

.shop-drawer-enter-from,
.shop-drawer-leave-to {
  opacity: 0;
}

.shop-drawer-enter-from .shop-drawer__panel,
.shop-drawer-leave-to .shop-drawer__panel {
  transform: translateX(100%);
}

@media (max-width: 420px) {
  .shop-header__cart-label {
    display: none;
  }
}

@media (max-width: 639px) {
  .shop-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 0.75rem;
  }

  .shop-card {
    gap: 0.65rem;
    padding: 0.5rem 0.5rem 0.75rem;
    border-radius: 1.25rem;
  }

  .shop-card__art {
    border-radius: 0.9rem;
  }

  .shop-card__body,
  .shop-card__foot {
    padding: 0 0.2rem;
  }

  .shop-card__category {
    font-size: 0.6875rem;
  }

  .shop-card h3 {
    font-size: 1.05rem;
  }

  .shop-card__foot {
    flex-direction: column;
    align-items: stretch;
    gap: 0.5rem;
  }

  .shop-card__price {
    font-size: 1.2rem;
  }

  .shop-btn--sm {
    min-height: 2.75rem;
    padding: 0 0.75rem;
    font-size: 0.8125rem;
  }
}

@media (min-width: 768px) {
  .shop-header {
    padding: 1.25rem 3rem;
  }

  .shop-hero {
    margin: 0 1.5rem;
    padding: 4rem 3rem;
    border-radius: 2.5rem;
  }

  .shop-hero__art {
    display: block;
  }

  .shop-main {
    padding: 4rem 3rem 3rem;
  }

  .shop-grid {
    gap: 1.75rem;
  }

  .shop-cartbar {
    display: none;
  }

  .shop-footer {
    padding: 3rem;
  }
}
</style>
