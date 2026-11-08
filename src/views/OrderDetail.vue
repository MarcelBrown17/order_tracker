<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useOrdersStore } from '../stores/orders'
import { useProductsStore } from '../stores/products'
import { sellTotal } from '../lib/orderGroups'
import { groupProducts } from '../lib/productGroups'
import { formatDate } from '../lib/formatDate'
import Money from '../components/Money.vue'
import StatusBadge from '../components/StatusBadge.vue'
import BaseButton from '../components/BaseButton.vue'
import ToggleSwitch from '../components/ToggleSwitch.vue'
import BaseSelect from '../components/BaseSelect.vue'
import PageBack from '../components/PageBack.vue'
import AppLoader from '../components/AppLoader.vue'
import { useToast } from '../composables/useToast'

const route = useRoute()
const auth = useAuthStore()
const ordersStore = useOrdersStore()
const productsStore = useProductsStore()
const toast = useToast()

const loading = ref(true)
const statusSaving = ref(false)
const saving = ref(false)
const dirty = ref(false)

const form = ref({
  customer_name: '',
  order_date: '',
  pay_eom: false,
  order_type: 'admin',
})
const cart = ref({})
const lineMeta = ref({})
const snapshot = ref('')

const order = computed(() => ordersStore.currentOrder)
const lines = computed(() => ordersStore.currentOrderGroup)

const orderTypeOptions = [
  { value: 'all', label: 'All' },
  { value: 'delton', label: 'Delton' },
  { value: 'richard', label: 'Richard' },
  { value: 'admin', label: 'Admin' },
]

const editableProducts = computed(() => {
  const byId = new Map(
    productsStore.products.map((p) => [p.id, p])
  )
  for (const line of lines.value) {
    if (!byId.has(line.product_id)) {
      byId.set(line.product_id, {
        id: line.product_id,
        name: line.product_name || 'Product',
        sell_price: Number(line.unit_sell_price),
        cost_price: Number(line.unit_cost),
        active: false,
      })
    }
  }
  return [...byId.values()].sort((a, b) =>
    String(a.name).localeCompare(String(b.name))
  )
})

const editableProductGroups = computed(() =>
  groupProducts(editableProducts.value)
)

const canManageOrder = computed(() => {
  if (!auth.partner || !lines.value.length) return false
  if (auth.isAdmin) return true
  const name = (auth.partner.name || '').toLowerCase()
  const type = order.value?.order_type
  if (name === 'delton' && ['delton', 'all'].includes(type)) return true
  if (name === 'richard' && ['richard', 'all'].includes(type)) return true
  return lines.value.some((line) => line.created_by === auth.partner.id)
})

const isCancelled = computed(() => order.value?.status === 'cancelled')
const isPaid = computed(() => order.value?.status === 'paid')
const canEdit = computed(
  () => canManageOrder.value && !!order.value && !loading.value && !isCancelled.value
)

const partnerSellTotal = computed(() =>
  lines.value.reduce((sum, line) => sum + sellTotal(line), 0)
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
  return form.value.order_date || today()
})

function qty(productId) {
  return Number(cart.value[productId] || 0)
}

function ensureMeta(productId) {
  if (lineMeta.value[productId]) return lineMeta.value[productId]
  const product = editableProducts.value.find((p) => p.id === productId)
  const meta = {
    id: null,
    unit_sell_price: Number(product?.sell_price ?? 0),
    unit_cost: Number(product?.cost_price ?? 0),
    is_bulk: false,
  }
  lineMeta.value = { ...lineMeta.value, [productId]: meta }
  return meta
}

function setQty(productId, next) {
  const value = Math.max(0, Math.min(99, Number(next) || 0))
  cart.value = { ...cart.value, [productId]: value }
  if (value > 0) ensureMeta(productId)
}

function addOne(productId) {
  setQty(productId, qty(productId) + 1)
}

function removeOne(productId) {
  setQty(productId, qty(productId) - 1)
}

function unitPrice(productId) {
  const meta = lineMeta.value[productId]
  if (meta) return Number(meta.unit_sell_price)
  const product = editableProducts.value.find((p) => p.id === productId)
  return Number(product?.sell_price ?? 0)
}

function unitCost(productId) {
  const meta = lineMeta.value[productId]
  if (meta?.is_bulk) return Number(meta.unit_cost) || 0
  const product = editableProducts.value.find((p) => p.id === productId)
  return Number(product?.cost_price ?? meta?.unit_cost ?? 0)
}

const liveSellTotal = computed(() =>
  editableProducts.value.reduce(
    (sum, product) => sum + unitPrice(product.id) * qty(product.id),
    0
  )
)

const liveProfitTotal = computed(() =>
  editableProducts.value.reduce((sum, product) => {
    const q = qty(product.id)
    if (!q) return sum
    return sum + (unitPrice(product.id) - unitCost(product.id)) * q
  }, 0)
)

const deltonCommission = computed(() =>
  ['delton', 'all'].includes(form.value.order_type) ? 15 : 0
)
const richardCommission = computed(() =>
  ['richard', 'all'].includes(form.value.order_type) ? 20 : 0
)

function serializeState() {
  return JSON.stringify({
    form: form.value,
    cart: cart.value,
    lineMeta: lineMeta.value,
  })
}

function markClean() {
  snapshot.value = serializeState()
  dirty.value = false
}

function checkDirty() {
  if (!canEdit.value || !snapshot.value) return
  dirty.value = serializeState() !== snapshot.value
}

watch([form, cart, lineMeta], checkDirty, { deep: true })

function hydrateForm() {
  if (!lines.value.length) return
  const primary = lines.value[0]
  form.value = {
    customer_name: primary.customer_name || '',
    order_date: primary.order_date || today(),
    pay_eom: isLastDayOfMonth(primary.date_paid),
    order_type: primary.order_type || 'admin',
  }

  const nextCart = {}
  const nextMeta = {}
  for (const line of lines.value) {
    nextCart[line.product_id] = Number(line.quantity)
    nextMeta[line.product_id] = {
      id: line.id,
      unit_sell_price: Number(line.unit_sell_price),
      unit_cost: Number(line.unit_cost),
      is_bulk: !!line.is_bulk,
    }
  }
  cart.value = nextCart
  lineMeta.value = nextMeta
  markClean()
}

async function load() {
  loading.value = true
  try {
    await ordersStore.fetchOrderGroup(route.params.id)
    const manage =
      !!auth.partner &&
      (auth.isAdmin ||
        (() => {
          const name = (auth.partner.name || '').toLowerCase()
          const type = ordersStore.currentOrder?.order_type
          if (name === 'delton' && ['delton', 'all'].includes(type)) return true
          if (name === 'richard' && ['richard', 'all'].includes(type)) return true
          return ordersStore.currentOrderGroup.some(
            (line) => line.created_by === auth.partner.id
          )
        })())

    if (manage && ordersStore.currentOrder?.status !== 'cancelled') {
      await productsStore.fetchProducts({
        activeOnly: true,
        admin: auth.isAdmin,
      })
      hydrateForm()
    }
  } catch (e) {
    toast.error(e.message || 'Failed to load order')
  } finally {
    loading.value = false
  }
}

onMounted(load)

watch(
  () => route.params.id,
  () => {
    if (route.params.id) load()
  }
)

async function saveChanges() {
  if (!canEdit.value || !dirty.value) return

  const selected = editableProducts.value.filter((p) => qty(p.id) > 0)
  if (!selected.length) {
    toast.error('Add at least one biscuit')
    return
  }

  saving.value = true
  try {
    const primary = lines.value[0]
    const groupId = primary.order_group_id || primary.id
    const shared = {
      customer_name: form.value.customer_name.trim(),
      customer_contact: primary.customer_contact || null,
      order_date: form.value.order_date,
      date_paid: resolvedDatePaid.value,
      order_type: auth.isAdmin ? form.value.order_type : primary.order_type,
      status: primary.status,
      created_by: primary.created_by ?? auth.partner?.id ?? null,
    }

    // Upsert lines with qty > 0 first so the group never goes empty
    for (const product of selected) {
      const meta = ensureMeta(product.id)
      const payload = {
        ...shared,
        product_id: product.id,
        quantity: qty(product.id),
        unit_sell_price: auth.isAdmin
          ? Number(meta.unit_sell_price)
          : Number(meta.unit_sell_price || product.sell_price),
        unit_cost: Number(product.cost_price ?? meta.unit_cost ?? 0),
        // Bulk override disabled until we get bulk receipts
        // unit_cost: auth.isAdmin && meta.is_bulk
        //   ? Number(meta.unit_cost)
        //   : Number(product.cost_price ?? meta.unit_cost ?? 0),
        is_bulk: false,
        // is_bulk: auth.isAdmin ? !!meta.is_bulk : false,
        order_group_id: groupId,
      }

      if (meta.id) {
        await ordersStore.updateOrder(meta.id, payload)
      } else {
        await ordersStore.createOrder(payload)
      }
    }

    // Remove biscuits that were cleared to 0
    for (const line of lines.value) {
      if (qty(line.product_id) <= 0) {
        await ordersStore.deleteOrderLine(line.id)
      }
    }

    toast.success('Order saved')
    await load()
  } catch (e) {
    toast.error(e.message || 'Failed to save changes')
  } finally {
    saving.value = false
  }
}

function discardChanges() {
  hydrateForm()
  toast.info('Changes discarded')
}

async function setStatus(status) {
  if (!canManageOrder.value) return
  if (dirty.value) {
    toast.error('Save or discard your edits before changing status')
    return
  }
  statusSaving.value = true
  try {
    await ordersStore.updateStatus(route.params.id, status)
    toast.success(status === 'paid' ? 'Marked as paid' : 'Order cancelled')
    await load()
  } catch (err) {
    toast.error(err.message || 'Failed to update status')
  } finally {
    statusSaving.value = false
  }
}

async function onCancelOrder() {
  if (!confirm('Cancel this order?')) return
  await setStatus('cancelled')
}

async function onMarkPaid() {
  await setStatus('paid')
}
</script>

<template>
  <div class="bakery-shell bakery-stack" :class="{ 'pb-24': canEdit }">
    <div>
      <PageBack label="Back" :fallback="{ name: 'orders' }" />
      <div class="mt-1 flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 class="page-title">Order</h1>
          <p class="page-subtitle">
            <template v-if="canEdit">Edit details, biscuits, and payment</template>
            <template v-else>Order details</template>
          </p>
        </div>
        <StatusBadge v-if="order" :status="order.status" />
      </div>
    </div>

    <AppLoader v-if="loading" label="Loading order" />

    <!-- Editable order (admin or linked partner) -->
    <template v-else-if="order && canEdit">
      <form class="bakery-stack" @submit.prevent="saveChanges">
        <div class="surface-card space-y-3 p-4 md:p-5">
          <p class="section-label">Customer</p>
          <div class="form-field">
            <label for="customer_name">Customer name <span class="req" aria-hidden="true">*</span></label>
            <input id="customer_name" v-model="form.customer_name" required />
          </div>
          <div v-if="order?.customer_contact" class="rounded-xl bg-page px-3.5 py-3 text-sm">
            <p class="section-label">Contact</p>
            <p class="mt-0.5 font-semibold">{{ order.customer_contact }}</p>
          </div>
          <div v-if="auth.isAdmin" class="form-field">
            <label for="order_type">Link order to <span class="req" aria-hidden="true">*</span></label>
            <BaseSelect
              id="order_type"
              v-model="form.order_type"
              :options="orderTypeOptions"
              required
            />
          </div>
        </div>

        <div class="surface-card space-y-3 p-4 md:p-5">
          <div class="flex items-center justify-between gap-3">
            <p class="section-label !mb-0">Products</p>
            <p class="text-sm font-bold tabular-nums">
              <Money :value="liveSellTotal" />
            </p>
          </div>

          <div
            v-for="group in editableProductGroups"
            :key="group.key"
            class="product-group"
          >
            <p class="product-group__title">{{ group.label }}</p>
            <div class="product-pick-list">
              <div
                v-for="product in group.items"
                :key="product.id"
                class="product-pick"
                :class="{ 'product-pick--active': qty(product.id) > 0 }"
              >
                <div class="product-pick__info min-w-0">
                  <p class="product-pick__name">{{ product.name }}</p>
                  <p class="product-pick__price">
                    <Money :value="unitPrice(product.id)" /> each
                  </p>
                  <!-- Price edits live on the Products tab
                  <div
                    v-if="auth.isAdmin && qty(product.id) > 0 && lineMeta[product.id]"
                    class="mt-1.5"
                  >
                    <div class="form-field mb-0">
                      <label :for="`price_${product.id}`">Price each</label>
                      <input
                        :id="`price_${product.id}`"
                        v-model.number="lineMeta[product.id].unit_sell_price"
                        type="number"
                        min="0"
                        step="0.01"
                        inputmode="decimal"
                      />
                    </div>
                  </div>
                  -->
                  <!-- Bulk orders hidden until we get bulk receipts
                  <ToggleSwitch
                    v-model="lineMeta[product.id].is_bulk"
                    label="Bulk order"
                    description="Override unit cost for this line"
                    compact
                  />
                  <div
                    v-if="lineMeta[product.id].is_bulk"
                    class="form-field bulk-highlight mb-0"
                  >
                    <label :for="`cost_${product.id}`">Unit cost</label>
                    <input
                      :id="`cost_${product.id}`"
                      v-model.number="lineMeta[product.id].unit_cost"
                      type="number"
                      min="0"
                      step="0.01"
                      inputmode="decimal"
                    />
                  </div>
                  -->
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
        </div>

        <div class="surface-card space-y-3 p-4 md:p-5">
          <p class="section-label">Payment</p>
          <div class="form-field">
            <label for="order_date">Order date <span class="req" aria-hidden="true">*</span></label>
            <input id="order_date" v-model="form.order_date" type="date" required />
          </div>
          <ToggleSwitch v-model="form.pay_eom" label="Pay end of month" />
        </div>

        <div
          v-if="auth.isAdmin"
          class="surface-card space-y-1.5 p-4 md:p-5 text-sm"
        >
          <p class="section-label">Admin · commissions</p>
          <p class="flex justify-between gap-3">
            <span class="text-muted">Profit</span>
            <Money :value="liveProfitTotal" tone="profit" />
          </p>
          <p
            v-if="deltonCommission"
            class="mt-1.5 flex justify-between gap-3"
          >
            <span class="text-muted">Delton</span>
            <Money :value="deltonCommission" tone="owed" />
          </p>
          <p
            v-if="richardCommission"
            class="mt-1.5 flex justify-between gap-3"
          >
            <span class="text-muted">Richard</span>
            <Money :value="richardCommission" tone="owed" />
          </p>
          <p
            v-if="!deltonCommission && !richardCommission"
            class="mt-1.5 text-muted"
          >
            No partner commission on this link
          </p>
        </div>
      </form>

      <div v-if="dirty" class="order-save-bar">
        <p class="text-xs font-semibold text-muted sm:text-sm">Unsaved changes</p>
        <div class="flex shrink-0 gap-2">
          <BaseButton
            type="button"
            variant="secondary"
            class="!min-h-10 !rounded-lg !px-3 !py-1.5"
            :disabled="saving"
            @click="discardChanges"
          >
            Discard
          </BaseButton>
          <BaseButton
            type="button"
            variant="primary"
            class="!min-h-10 !rounded-lg !px-3 !py-1.5"
            :disabled="saving"
            @click="saveChanges"
          >
            {{ saving ? 'Saving…' : 'Save' }}
          </BaseButton>
        </div>
      </div>

      <div v-else-if="canManageOrder" class="order-save-bar">
        <p class="text-xs font-semibold text-muted sm:text-sm">
          Total <Money :value="liveSellTotal" />
        </p>
        <div class="flex shrink-0 gap-2">
          <BaseButton
            type="button"
            variant="destructive"
            class="!min-h-10 !rounded-lg !px-3 !py-1.5"
            :disabled="statusSaving"
            @click="onCancelOrder"
          >
            Cancel order
          </BaseButton>
          <BaseButton
            v-if="!isPaid"
            type="button"
            variant="primary"
            class="!min-h-10 !rounded-lg !px-3 !py-1.5"
            :disabled="statusSaving"
            @click="onMarkPaid"
          >
            {{ statusSaving ? 'Saving…' : 'Mark paid' }}
          </BaseButton>
        </div>
      </div>
    </template>

    <!-- Read-only (cancelled or no manage access) -->
    <template v-else-if="order">
      <div class="surface-card space-y-4 p-4">
        <div class="min-w-0">
          <p class="text-lg font-extrabold">{{ order.customer_name }}</p>
          <p v-if="order.customer_contact" class="text-sm text-muted">
            {{ order.customer_contact }}
          </p>
        </div>

        <div class="space-y-2.5">
          <p class="section-label">Biscuits</p>
          <div
            v-for="line in lines"
            :key="line.id"
            class="flex items-center justify-between gap-3 rounded-xl bg-page px-3.5 py-3 text-sm"
          >
            <div class="min-w-0">
              <p class="font-semibold">{{ line.product_name }}</p>
              <p class="text-muted">Qty {{ line.quantity }}</p>
            </div>
            <Money :value="sellTotal(line)" />
          </div>
        </div>

        <div class="grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
          <div>
            <p class="section-label">Order total</p>
            <p class="mt-0.5 font-semibold">
              <Money :value="partnerSellTotal" />
            </p>
          </div>
          <div>
            <p class="section-label">Order date</p>
            <p class="mt-0.5 font-semibold">{{ formatDate(order.order_date) }}</p>
          </div>
          <div>
            <p class="section-label">Date paid</p>
            <p class="mt-0.5 font-semibold">{{ formatDate(order.date_paid) }}</p>
          </div>
        </div>

        <p v-if="isCancelled" class="text-sm text-muted">
          This order has been cancelled.
        </p>
      </div>
    </template>
  </div>
</template>
