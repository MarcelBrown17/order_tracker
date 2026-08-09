<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useProductsStore } from '../stores/products'
import { useOrdersStore } from '../stores/orders'
import Money from '../components/Money.vue'
import BaseButton from '../components/BaseButton.vue'
import ToggleSwitch from '../components/ToggleSwitch.vue'
import BaseSelect from '../components/BaseSelect.vue'
import AppLoader from '../components/AppLoader.vue'
import { useToast } from '../composables/useToast'

const router = useRouter()
const auth = useAuthStore()
const productsStore = useProductsStore()
const ordersStore = useOrdersStore()
const toast = useToast()

const form = ref({
  customer_name: '',
  company: '',
  order_date: new Date().toISOString().slice(0, 10),
  pay_eom: false,
  notes: '',
  order_type: 'admin',
})

const orderTypeOptions = [
  { value: 'all', label: 'All' },
  { value: 'delton', label: 'Delton' },
  { value: 'richard', label: 'Richard' },
  { value: 'admin', label: 'Admin' },
]

function partnerOrderType() {
  const name = (auth.partner?.name || '').toLowerCase()
  if (name === 'richard') return 'richard'
  if (name === 'delton') return 'delton'
  return 'admin'
}

const cart = ref({})
const loading = ref(false)
const saving = ref(false)

const products = computed(() => productsStore.products)

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

const cartItems = computed(() =>
  products.value
    .filter((p) => qty(p.id) > 0)
    .map((p) => ({
      product_id: p.id,
      quantity: qty(p.id),
      unit_sell_price: Number(p.sell_price),
      unit_cost: Number(p.cost_price ?? 0),
      is_bulk: false,
    }))
)

const orderTotal = computed(() =>
  cartItems.value.reduce(
    (sum, line) => sum + Number(line.unit_sell_price) * Number(line.quantity),
    0
  )
)

const resolvedOrderType = computed(() =>
  auth.isAdmin ? form.value.order_type : partnerOrderType()
)

const profitTotal = computed(() =>
  cartItems.value.reduce(
    (sum, line) =>
      sum +
      (Number(line.unit_sell_price) - Number(line.unit_cost)) *
        Number(line.quantity),
    0
  )
)

const deltonCommission = computed(() =>
  ['delton', 'all'].includes(resolvedOrderType.value) ? 15 : 0
)
const richardCommission = computed(() =>
  ['richard', 'all'].includes(resolvedOrderType.value) ? 20 : 0
)
const commissionTotal = computed(
  () => deltonCommission.value + richardCommission.value
)

const resolvedDatePaid = computed(() => {
  if (form.value.pay_eom) {
    const d = new Date()
    return new Date(d.getFullYear(), d.getMonth() + 1, 0)
      .toISOString()
      .slice(0, 10)
  }
  return new Date().toISOString().slice(0, 10)
})

onMounted(async () => {
  loading.value = true
  try {
    form.value.order_type = auth.isAdmin ? 'admin' : partnerOrderType()
    await productsStore.fetchProducts({
      activeOnly: true,
      admin: auth.isAdmin,
    })
  } catch (e) {
    toast.error(e.message || 'Failed to load products')
  } finally {
    loading.value = false
  }
})

async function onSubmit() {
  if (!form.value.customer_name.trim()) {
    toast.error('Please enter a customer name')
    return
  }
  if (!cartItems.value.length) {
    toast.error('Add at least one biscuit')
    return
  }

  saving.value = true
  try {
    const shared = {
      customer_name: form.value.customer_name.trim(),
      company: form.value.company.trim() || null,
      order_date: form.value.order_date,
      date_paid: resolvedDatePaid.value,
      notes: form.value.notes.trim() || null,
      created_by: auth.partner?.id ?? null,
      order_type: resolvedOrderType.value,
    }

    const orderGroupId = crypto.randomUUID()
    const created = await ordersStore.createOrdersBatch({
      shared,
      items: cartItems.value,
      orderGroupId,
    })

    toast.success('Order created')
    router.push({ name: 'order-detail', params: { id: created[0].id } })
  } catch (e) {
    toast.error(e.message || 'Failed to save order')
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="bakery-shell bakery-stack pb-24 md:pb-0">
    <div>
      <h1 class="page-title">New order</h1>
      <p class="page-subtitle">
        Customer details and biscuits, same as the request form.
      </p>
    </div>

    <AppLoader v-if="loading" label="Loading form" />

    <form
      v-else
      class="bakery-stack"
      @submit.prevent="onSubmit"
    >
      <div class="surface-card space-y-3 p-4 md:p-5">
        <p class="section-label">Customer</p>
        <div class="form-field">
          <label for="customer_name">
            Customer name <span class="req" aria-hidden="true">*</span>
          </label>
          <input
            id="customer_name"
            v-model="form.customer_name"
            required
            placeholder="Customer full name"
          />
        </div>
        <div class="form-field">
          <label for="company">Company</label>
          <input id="company" v-model="form.company" placeholder="Company name" />
        </div>
        <div v-if="auth.isAdmin" class="form-field">
          <label for="order_type">
            Link order to <span class="req" aria-hidden="true">*</span>
          </label>
          <BaseSelect
            id="order_type"
            v-model="form.order_type"
            :options="orderTypeOptions"
            placeholder="Select who this order is for"
            required
          />
          <p class="mt-1.5 text-xs text-muted">
            Always linked to admin. Admin keeps it all. Delton gets R15 on Delton and All.
            Richard gets R20 on Richard and All.
          </p>
        </div>
      </div>

      <div class="surface-card space-y-3 p-4 md:p-5">
        <div class="flex items-center justify-between gap-3">
          <p class="section-label !mb-0">Biscuits</p>
          <p v-if="orderTotal" class="text-sm font-bold tabular-nums">
            <Money :value="orderTotal" />
          </p>
        </div>

        <p v-if="!products.length" class="text-sm text-muted">
          No biscuits available right now.
        </p>

        <div v-else class="product-pick-list">
          <div
            v-for="product in products"
            :key="product.id"
            class="product-pick"
            :class="{ 'product-pick--active': qty(product.id) > 0 }"
          >
            <div class="product-pick__info">
              <p class="product-pick__name">{{ product.name }}</p>
              <p class="product-pick__price">
                <Money :value="product.sell_price" /> each
              </p>
            </div>
            <div class="product-stepper">
              <button
                type="button"
                class="product-stepper__btn product-stepper__btn--minus"
                :disabled="qty(product.id) <= 0"
                aria-label="Decrease quantity"
                @click="removeOne(product.id)"
              >
                −
              </button>
              <span class="product-stepper__qty">{{ qty(product.id) }}</span>
              <button
                type="button"
                class="product-stepper__btn"
                aria-label="Increase quantity"
                @click="addOne(product.id)"
              >
                +
              </button>
            </div>
          </div>
        </div>
      </div>

      <div class="surface-card space-y-3 p-4 md:p-5">
        <p class="section-label">Payment & notes</p>
        <div class="form-field">
          <label for="order_date">
            Order date <span class="req" aria-hidden="true">*</span>
          </label>
          <input id="order_date" v-model="form.order_date" type="date" required />
        </div>
        <ToggleSwitch v-model="form.pay_eom" label="Pay end of month" />
        <div class="form-field">
          <label for="notes">Notes</label>
          <textarea
            id="notes"
            v-model="form.notes"
            rows="3"
            placeholder="Anything useful for the team"
          />
        </div>
      </div>

      <div
        v-if="auth.isAdmin"
        class="surface-card space-y-3 p-4 md:p-5"
      >
        <p class="section-label">Admin · commissions</p>
        <div class="space-y-1.5 text-sm">
          <p class="flex justify-between gap-3">
            <span class="text-muted">Profit</span>
            <Money :value="profitTotal" tone="profit" />
          </p>
          <p v-if="deltonCommission" class="flex justify-between gap-3">
            <span class="text-muted">Delton</span>
            <Money :value="deltonCommission" tone="owed" />
          </p>
          <p v-if="richardCommission" class="flex justify-between gap-3">
            <span class="text-muted">Richard</span>
            <Money :value="richardCommission" tone="owed" />
          </p>
          <p v-if="commissionTotal" class="flex justify-between gap-3 font-bold">
            <span>Commissions</span>
            <Money :value="commissionTotal" tone="owed" />
          </p>
          <p v-else class="text-muted">No partner commission on this link</p>
        </div>
      </div>

      <div class="order-footer">
        <div class="order-footer__inner">
          <div class="min-w-0">
            <p class="order-total__label">Total</p>
            <p class="order-total__amount">
              <Money :value="orderTotal" />
            </p>
          </div>
          <BaseButton
            type="submit"
            variant="primary"
            class="!min-w-[9.5rem] !rounded-[0.875rem] !px-6 !py-3.5"
            :disabled="saving || !products.length"
          >
            {{ saving ? 'Saving…' : 'Create order' }}
          </BaseButton>
        </div>
      </div>
    </form>
  </div>
</template>
