<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useOrdersStore } from '../stores/orders'
import { groupOrders } from '../lib/orderGroups'
import Money from '../components/Money.vue'
import StatusBadge from '../components/StatusBadge.vue'
import BaseButton from '../components/BaseButton.vue'
import AppLoader from '../components/AppLoader.vue'
import { useToast } from '../composables/useToast'

const auth = useAuthStore()
const ordersStore = useOrdersStore()
const router = useRouter()
const toast = useToast()

const status = ref('all')
const search = ref('')
const loading = ref(false)

const filters = [
  { value: 'all', label: 'Active' },
  { value: 'paid', label: 'Paid' },
  { value: 'cancelled', label: 'Cancelled' },
]

const groupedOrders = computed(() => groupOrders(ordersStore.orders))

async function load() {
  loading.value = true
  try {
    await ordersStore.fetchOrders({
      status: status.value,
      search: search.value,
    })
  } catch (e) {
    toast.error(e.message || 'Failed to load orders')
  } finally {
    loading.value = false
  }
}

let searchTimer
watch(search, () => {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(load, 250)
})

watch(status, load)

onMounted(load)

function openOrder(id) {
  router.push({ name: 'order-detail', params: { id } })
}

function productSummary(group) {
  if (group.items.length === 1) {
    const item = group.items[0]
    return `${item.product_name} · Qty ${item.quantity}`
  }
  return group.items
    .map((item) => `${item.product_name} × ${item.quantity}`)
    .join(', ')
}

function orderTypeLabel(type) {
  if (type === 'all' || type === 'both') return 'All'
  if (type === 'richard') return 'Richard'
  if (type === 'delton') return 'Delton'
  return 'Admin'
}
</script>

<template>
  <div class="bakery-shell bakery-stack">
    <div class="flex items-start justify-between gap-3">
      <div>
        <h1 class="page-title">Orders</h1>
        <p class="page-subtitle">
          <template v-if="auth.isAdmin">Filter and search customer orders</template>
          <template v-else>Orders linked to you</template>
        </p>
      </div>
      <BaseButton
        class="hidden sm:inline-flex"
        variant="primary"
        @click="router.push({ name: 'new-order' })"
      >
        New order
      </BaseButton>
    </div>

    <div class="orders-toolbar">
      <label class="search-field" for="search">
        <span class="sr-only">Search customer</span>
        <svg
          class="search-field__icon"
          width="18"
          height="18"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2.25"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <circle cx="11" cy="11" r="7" />
          <path d="m20 20-3.5-3.5" />
        </svg>
        <input
          id="search"
          v-model="search"
          type="search"
          class="search-field__input"
          placeholder="Search by customer name…"
          autocomplete="off"
        />
        <button
          v-if="search"
          type="button"
          class="search-field__clear"
          aria-label="Clear search"
          @click="search = ''"
        >
          Clear
        </button>
      </label>

      <div class="orders-filters">
        <button
          v-for="f in filters"
          :key="f.value"
          type="button"
          class="filter-chip"
          :class="{ 'filter-chip--active': status === f.value }"
          @click="status = f.value"
        >
          {{ f.label }}
        </button>
      </div>
    </div>

    <AppLoader v-if="loading" label="Loading orders" />

    <template v-else>
      <div class="space-y-2.5 md:hidden">
        <button
          v-for="group in groupedOrders"
          :key="group.groupId"
          type="button"
          class="list-card w-full text-left"
          @click="openOrder(group.id)"
        >
          <div class="flex items-start justify-between gap-3">
            <div class="min-w-0">
              <p class="truncate font-bold">{{ group.customer_name }}</p>
              <p v-if="group.company" class="truncate text-sm text-muted">
                {{ group.company }}
              </p>
            </div>
            <StatusBadge :status="group.status" />
          </div>
          <p class="text-sm text-muted">{{ productSummary(group) }}</p>
          <p v-if="auth.isAdmin" class="text-xs font-semibold text-muted">
            {{ orderTypeLabel(group.order_type) }}
          </p>
          <div class="flex items-center justify-between text-sm">
            <span class="text-muted">{{ group.order_date }}</span>
            <span class="font-bold">
              <Money :value="group.sellTotal" />
            </span>
          </div>
          <div v-if="auth.isAdmin" class="flex items-center justify-between text-sm">
            <span class="text-muted">Profit</span>
            <Money :value="group.profitTotal" tone="profit" />
          </div>
        </button>
        <p v-if="!groupedOrders.length" class="text-sm text-muted">
          No orders found
        </p>
      </div>

      <div class="table-wrap hidden md:block">
        <table>
          <thead>
            <tr>
              <th>Date</th>
              <th>Customer</th>
              <th>Products</th>
              <th v-if="auth.isAdmin">Type</th>
              <th>Sell total</th>
              <th v-if="auth.isAdmin">Profit</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="group in groupedOrders"
              :key="group.groupId"
              @click="openOrder(group.id)"
            >
              <td>{{ group.order_date }}</td>
              <td>
                <span class="font-semibold">{{ group.customer_name }}</span>
                <span v-if="group.company" class="block text-muted">{{ group.company }}</span>
              </td>
              <td class="max-w-xs">{{ productSummary(group) }}</td>
              <td v-if="auth.isAdmin">{{ orderTypeLabel(group.order_type) }}</td>
              <td><Money :value="group.sellTotal" /></td>
              <td v-if="auth.isAdmin">
                <Money :value="group.profitTotal" tone="profit" />
              </td>
              <td><StatusBadge :status="group.status" /></td>
            </tr>
            <tr v-if="!groupedOrders.length">
              <td :colspan="auth.isAdmin ? 7 : 5" class="text-muted">No orders found</td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>
  </div>
</template>
