<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useOrdersStore } from '../stores/orders'
import Money from '../components/Money.vue'
import StatusBadge from '../components/StatusBadge.vue'
import BaseButton from '../components/BaseButton.vue'
import ToggleSwitch from '../components/ToggleSwitch.vue'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const ordersStore = useOrdersStore()

const loading = ref(true)
const error = ref('')
const statusSaving = ref(false)

const canManageOrder = computed(() => {
  const order = ordersStore.currentOrder
  if (!order || !auth.partner) return false
  return auth.isAdmin || order.created_by === auth.partner.id
})

const isCancelled = computed(
  () => ordersStore.currentOrder?.status === 'cancelled'
)

const isPaid = computed(() => ordersStore.currentOrder?.status === 'paid')

async function load() {
  loading.value = true
  error.value = ''
  try {
    await ordersStore.fetchOrder(route.params.id)
    if (auth.isAdmin) {
      await ordersStore.fetchSplits(route.params.id)
    }
  } catch (e) {
    error.value = e.message || 'Failed to load order'
  } finally {
    loading.value = false
  }
}

onMounted(load)

async function setStatus(status) {
  if (!canManageOrder.value) return
  statusSaving.value = true
  error.value = ''
  try {
    await ordersStore.updateStatus(route.params.id, status)
    await ordersStore.fetchOrder(route.params.id)
  } catch (err) {
    error.value = err.message || 'Failed to update status'
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

async function togglePaid(split) {
  try {
    await ordersStore.setSplitPaid(split.id, !split.paid_out)
  } catch (e) {
    error.value = e.message || 'Failed to update payout'
  }
}

async function onDelete() {
  if (!confirm('Delete this order? This cannot be undone.')) return
  try {
    await ordersStore.deleteOrder(route.params.id)
    router.push({ name: 'orders' })
  } catch (e) {
    error.value = e.message || 'Failed to delete order'
  }
}

function sellTotal(o) {
  return Number(o.unit_sell_price) * Number(o.quantity)
}
</script>

<template>
  <div class="mx-auto max-w-2xl space-y-5">
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div>
        <h1 class="page-title">Order</h1>
        <p class="page-subtitle">
          <template v-if="auth.isAdmin">Totals and partner splits</template>
          <template v-else>Order details</template>
        </p>
      </div>
      <div v-if="auth.isAdmin" class="flex w-full gap-2 sm:w-auto">
        <BaseButton
          variant="secondary"
          class="flex-1 sm:flex-none"
          @click="
            router.push({ name: 'edit-order', params: { id: route.params.id } })
          "
        >
          Edit
        </BaseButton>
        <BaseButton
          variant="destructive"
          class="flex-1 sm:flex-none"
          @click="onDelete"
        >
          Delete
        </BaseButton>
      </div>
    </div>

    <p v-if="loading" class="text-sm text-muted">Loading…</p>
    <p
      v-else-if="error && !ordersStore.currentOrder"
      class="text-sm text-red-700 dark:text-red-400"
    >
      {{ error }}
    </p>

    <template v-else-if="ordersStore.currentOrder">
      <p v-if="error" class="text-sm text-red-700 dark:text-red-400">{{ error }}</p>

      <div class="surface-card space-y-4 p-4">
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div class="min-w-0">
            <p class="text-lg font-extrabold">
              {{ ordersStore.currentOrder.customer_name }}
            </p>
            <p
              v-if="ordersStore.currentOrder.company"
              class="text-sm text-muted"
            >
              {{ ordersStore.currentOrder.company }}
            </p>
          </div>
          <StatusBadge :status="ordersStore.currentOrder.status" />
        </div>

        <div class="grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
          <div>
            <p class="section-label">Product</p>
            <p class="mt-0.5 font-semibold">{{ ordersStore.currentOrder.product_name }}</p>
          </div>
          <div>
            <p class="section-label">Quantity</p>
            <p class="mt-0.5 font-semibold tabular-nums">{{ ordersStore.currentOrder.quantity }}</p>
          </div>
          <div v-if="auth.isAdmin">
            <p class="section-label">Unit cost</p>
            <p class="mt-0.5 font-semibold">
              <Money :value="ordersStore.currentOrder.unit_cost" />
              <span
                v-if="ordersStore.currentOrder.is_bulk"
                class="ml-1 text-xs font-bold text-accent"
                >Bulk</span
              >
            </p>
          </div>
          <div>
            <p class="section-label">Price each</p>
            <p class="mt-0.5 font-semibold">
              <Money :value="ordersStore.currentOrder.unit_sell_price" />
            </p>
          </div>
          <div>
            <p class="section-label">Sell total</p>
            <p class="mt-0.5 font-semibold">
              <Money :value="sellTotal(ordersStore.currentOrder)" />
            </p>
          </div>
          <div>
            <p class="section-label">Order date</p>
            <p class="mt-0.5 font-semibold">{{ ordersStore.currentOrder.order_date }}</p>
          </div>
          <div>
            <p class="section-label">Date paid</p>
            <p class="mt-0.5 font-semibold">{{ ordersStore.currentOrder.date_paid || '—' }}</p>
          </div>
          <div>
            <p class="section-label">Notes</p>
            <p class="mt-0.5">{{ ordersStore.currentOrder.notes || '—' }}</p>
          </div>
        </div>

        <div
          v-if="auth.isAdmin"
          class="rounded-xl bg-page px-3.5 py-3 text-sm"
        >
          <span class="text-muted">Profit </span>
          <Money :value="ordersStore.currentOrder.profit_total" tone="profit" />
          <span class="text-muted"> · Split </span>
          <Money :value="ordersStore.currentOrder.profit_per_partner" tone="owed" />
          <span class="text-muted"> each</span>
        </div>

        <div v-if="canManageOrder && !isCancelled" class="flex flex-col gap-2.5 sm:flex-row">
          <BaseButton
            v-if="auth.isAdmin && !isPaid"
            variant="primary"
            block
            :disabled="statusSaving"
            @click="onMarkPaid"
          >
            {{ statusSaving ? 'Saving…' : 'Mark paid' }}
          </BaseButton>
          <BaseButton
            variant="destructive"
            block
            :disabled="statusSaving"
            @click="onCancelOrder"
          >
            {{ statusSaving ? 'Saving…' : 'Cancel order' }}
          </BaseButton>
        </div>
        <p v-else-if="isCancelled" class="text-sm text-muted">
          This order has been cancelled.
        </p>
      </div>

      <div v-if="auth.isAdmin" class="surface-card space-y-1 p-4">
        <h2 class="section-label mb-2">Partner splits</h2>
        <div
          v-for="split in ordersStore.currentSplits"
          :key="split.id"
          class="border-b border-border py-3 last:border-0 last:pb-0"
        >
          <div class="mb-2.5 flex items-center justify-between gap-3">
            <p class="font-bold">{{ split.users?.name }}</p>
            <Money :value="split.amount" tone="owed" />
          </div>
          <ToggleSwitch
            :model-value="split.paid_out"
            label="Mark paid"
            :description="split.paid_out ? 'Paid out to partner' : 'Still owed'"
            @update:model-value="togglePaid(split)"
          />
        </div>
        <p v-if="!ordersStore.currentSplits.length" class="text-sm text-muted">
          No splits found
        </p>
      </div>
    </template>
  </div>
</template>
