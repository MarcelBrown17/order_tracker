<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useProductsStore } from '../stores/products'
import { useOrdersStore } from '../stores/orders'
import Money from '../components/Money.vue'
import BaseButton from '../components/BaseButton.vue'
import ToggleSwitch from '../components/ToggleSwitch.vue'
import BaseSelect from '../components/BaseSelect.vue'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const productsStore = useProductsStore()
const ordersStore = useOrdersStore()

const isEdit = computed(() => !!route.params.id && route.name === 'edit-order')

const form = ref({
  customer_name: '',
  company: '',
  product_id: '',
  quantity: 1,
  unit_sell_price: 0,
  unit_cost: 0,
  is_bulk: false,
  order_date: new Date().toISOString().slice(0, 10),
  pay_eom: false,
  notes: '',
})

const loading = ref(false)
const saving = ref(false)
const error = ref('')

const profitTotal = computed(() => {
  const cost = Number(form.value.unit_cost) || 0
  const sell = Number(form.value.unit_sell_price) || 0
  const qty = Number(form.value.quantity) || 0
  return (sell - cost) * qty
})

const profitPerPartner = computed(() => profitTotal.value / 3)

const orderTotal = computed(() => {
  const sell = Number(form.value.unit_sell_price) || 0
  const qty = Number(form.value.quantity) || 0
  return sell * qty
})

const productOptions = computed(() =>
  productsStore.products.map((p) => ({
    value: p.id,
    label: p.name,
  }))
)

function today() {
  return new Date().toISOString().slice(0, 10)
}

function lastDayOfMonth(dateStr) {
  const d = new Date(`${dateStr}T12:00:00`)
  const last = new Date(d.getFullYear(), d.getMonth() + 1, 0)
  const y = last.getFullYear()
  const m = String(last.getMonth() + 1).padStart(2, '0')
  const day = String(last.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

function isLastDayOfMonth(dateStr) {
  if (!dateStr) return false
  return dateStr === lastDayOfMonth(dateStr)
}

const resolvedDatePaid = computed(() => {
  if (form.value.pay_eom) {
    return lastDayOfMonth(form.value.order_date || today())
  }
  return today()
})

function applyProductDefaults(productId) {
  const product = productsStore.products.find((p) => p.id === productId)
  if (!product) return
  if (product.cost_price != null) {
    form.value.unit_cost = Number(product.cost_price)
  }
  form.value.unit_sell_price = Number(product.sell_price)
  form.value.is_bulk = false
}

watch(
  () => form.value.product_id,
  (id, prev) => {
    if (!id || !prev) return
    applyProductDefaults(id)
  }
)

async function load() {
  loading.value = true
  error.value = ''
  try {
    await productsStore.fetchProducts({
      activeOnly: !isEdit.value,
      admin: auth.isAdmin,
    })
    if (isEdit.value) {
      const order = await ordersStore.fetchOrder(route.params.id)
      form.value = {
        customer_name: order.customer_name,
        company: order.company || '',
        product_id: order.product_id,
        quantity: order.quantity,
        unit_sell_price: Number(order.unit_sell_price),
        unit_cost: Number(order.unit_cost),
        is_bulk: order.is_bulk,
        order_date: order.order_date,
        pay_eom: isLastDayOfMonth(order.date_paid),
        notes: order.notes || '',
      }
      if (!productsStore.products.find((p) => p.id === order.product_id)) {
        await productsStore.fetchProducts({ activeOnly: false, admin: auth.isAdmin })
      }
    } else if (productsStore.products.length) {
      form.value.product_id = productsStore.products[0].id
      applyProductDefaults(form.value.product_id)
      form.value.order_date = today()
    }
  } catch (e) {
    error.value = e.message || 'Failed to load form'
  } finally {
    loading.value = false
  }
}

onMounted(load)

async function onSubmit() {
  error.value = ''
  saving.value = true
  try {
    const product = productsStore.products.find((p) => p.id === form.value.product_id)
    const payload = {
      customer_name: form.value.customer_name.trim(),
      company: form.value.company.trim() || null,
      product_id: form.value.product_id,
      quantity: Number(form.value.quantity),
      unit_sell_price: Number(form.value.unit_sell_price),
      unit_cost:
        auth.isAdmin && form.value.is_bulk
          ? Number(form.value.unit_cost)
          : Number(product?.cost_price ?? 0),
      is_bulk: auth.isAdmin ? !!form.value.is_bulk : false,
      order_date: form.value.order_date,
      date_paid: resolvedDatePaid.value,
      notes: form.value.notes.trim() || null,
      created_by: auth.partner?.id ?? null,
    }

    if (isEdit.value) {
      if (!auth.isAdmin) {
        throw new Error('Only admin can edit orders')
      }
      await ordersStore.updateOrder(route.params.id, payload)
      router.push({ name: 'order-detail', params: { id: route.params.id } })
    } else {
      const created = await ordersStore.createOrder(payload)
      if (auth.isAdmin) {
        router.push({ name: 'order-detail', params: { id: created.id } })
      } else {
        router.push({ name: 'orders' })
      }
    }
  } catch (e) {
    error.value = e.message || 'Failed to save order'
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="mx-auto max-w-xl space-y-5">
    <div>
      <h1 class="page-title">
        {{ isEdit ? 'Edit order' : 'New order' }}
      </h1>
      <p class="page-subtitle">
        Customer, product, and sell price. Cost comes from the product.
      </p>
    </div>

    <p v-if="loading" class="text-sm text-muted">Loading…</p>

    <form
      v-else
      class="surface-card space-y-0 p-4"
      @submit.prevent="onSubmit"
    >
      <div class="form-section">
        <p class="section-label">Customer</p>
        <div class="form-field">
          <label for="customer_name">Customer name</label>
          <input id="customer_name" v-model="form.customer_name" required />
        </div>
        <div class="form-field">
          <label for="company">Company (optional)</label>
          <input id="company" v-model="form.company" />
        </div>
      </div>

      <div class="form-section">
        <p class="section-label">Order</p>
        <div class="form-field">
          <label for="product_id">Product</label>
          <BaseSelect
            id="product_id"
            v-model="form.product_id"
            :options="productOptions"
            placeholder="Select product"
            required
          />
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div class="form-field">
            <label for="quantity">Quantity</label>
            <input
              id="quantity"
              v-model.number="form.quantity"
              type="number"
              min="1"
              step="1"
              inputmode="numeric"
              required
            />
          </div>
          <div class="form-field">
            <label for="unit_sell_price">Price each</label>
            <input
              id="unit_sell_price"
              v-model.number="form.unit_sell_price"
              type="number"
              min="0"
              step="0.01"
              inputmode="decimal"
              required
              :disabled="!auth.isAdmin"
            />
          </div>
        </div>
        <div class="form-field">
          <label for="order_date">Order date</label>
          <input id="order_date" v-model="form.order_date" type="date" required />
        </div>
        <div class="flex items-center justify-between gap-3 rounded-xl bg-page px-3.5 py-3">
          <p class="text-sm font-semibold text-muted">Order total</p>
          <p class="text-base font-bold tabular-nums text-text">
            <Money :value="orderTotal" />
          </p>
        </div>
      </div>

      <div class="form-section">
        <p class="section-label">Payment & notes</p>
        <ToggleSwitch v-model="form.pay_eom" label="Pay end of month (EOM)">
          <template v-if="form.pay_eom">
            Date paid: <strong>{{ resolvedDatePaid }}</strong> (last day of month)
          </template>
          <template v-else>
            Date paid: <strong>{{ resolvedDatePaid }}</strong> (today)
          </template>
        </ToggleSwitch>
        <div class="form-field">
          <label for="notes">Notes (optional)</label>
          <textarea id="notes" v-model="form.notes" rows="2" />
        </div>
      </div>

      <div
        v-if="auth.isAdmin"
        class="mt-4 space-y-3 rounded-xl border border-border bg-page p-3.5"
      >
        <p class="section-label">Admin · cost</p>
        <ToggleSwitch
          v-model="form.is_bulk"
          label="Bulk order"
          description="Override the product unit cost for this order"
        />
        <div class="form-field" :class="{ 'bulk-highlight': form.is_bulk }">
          <label for="unit_cost">Unit cost</label>
          <input
            id="unit_cost"
            v-model.number="form.unit_cost"
            type="number"
            min="0"
            step="0.01"
            inputmode="decimal"
            :readonly="!form.is_bulk"
          />
        </div>
        <p class="text-sm">
          Profit:
          <Money :value="profitTotal" tone="profit" />
          · Split:
          <Money :value="profitPerPartner" tone="owed" />
          each
        </p>
      </div>

      <p v-if="error" class="mt-3 text-sm text-red-700">{{ error }}</p>

      <div class="mt-4 flex flex-col gap-2.5 sm:flex-row">
        <BaseButton type="submit" variant="primary" block :disabled="saving">
          {{ saving ? 'Saving…' : isEdit ? 'Save changes' : 'Create order' }}
        </BaseButton>
        <BaseButton type="button" variant="secondary" block @click="router.back()">
          Cancel
        </BaseButton>
      </div>
    </form>
  </div>
</template>
