<script setup>
import { ref, watch, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useOrdersStore } from '../stores/orders'
import Money from '../components/Money.vue'
import StatusBadge from '../components/StatusBadge.vue'
import BaseButton from '../components/BaseButton.vue'

const auth = useAuthStore()
const ordersStore = useOrdersStore()
const router = useRouter()

const status = ref('all')
const search = ref('')
const loading = ref(false)
const error = ref('')

const filters = [
  { value: 'all', label: 'All' },
  { value: 'pending', label: 'Pending' },
  { value: 'paid', label: 'Paid' },
  { value: 'cancelled', label: 'Cancelled' },
]

async function load() {
  loading.value = true
  error.value = ''
  try {
    await ordersStore.fetchOrders({
      status: status.value,
      search: search.value,
      createdBy: auth.isAdmin ? null : auth.partner?.id,
    })
  } catch (e) {
    error.value = e.message || 'Failed to load orders'
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

function sellTotal(o) {
  return Number(o.unit_sell_price) * Number(o.quantity)
}
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-start justify-between gap-3">
      <div>
        <h1 class="page-title">Orders</h1>
        <p class="page-subtitle">
          <template v-if="auth.isAdmin">Filter and search customer orders</template>
          <template v-else>Orders you have logged</template>
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

    <div class="-mx-1 flex gap-2 overflow-x-auto px-1 pb-1">
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

    <div class="form-field">
      <label for="search">Search customer</label>
      <input
        id="search"
        v-model="search"
        type="search"
        placeholder="Customer name…"
      />
    </div>

    <p v-if="loading" class="text-sm text-muted">Loading…</p>
    <p v-else-if="error" class="text-sm text-red-700">{{ error }}</p>

    <template v-else>
      <!-- Mobile cards -->
      <div class="space-y-2.5 md:hidden">
        <button
          v-for="o in ordersStore.orders"
          :key="o.id"
          type="button"
          class="list-card w-full text-left"
          @click="openOrder(o.id)"
        >
          <div class="flex items-start justify-between gap-3">
            <div class="min-w-0">
              <p class="truncate font-bold">{{ o.customer_name }}</p>
              <p v-if="o.company" class="truncate text-sm text-muted">
                {{ o.company }}
              </p>
            </div>
            <StatusBadge :status="o.status" />
          </div>
          <p class="text-sm text-muted">{{ o.product_name }} · Qty {{ o.quantity }}</p>
          <div class="flex items-center justify-between text-sm">
            <span class="text-muted">{{ o.order_date }}</span>
            <span class="font-bold">
              <Money :value="sellTotal(o)" tone="owed" />
            </span>
          </div>
          <div v-if="auth.isAdmin" class="flex items-center justify-between text-sm">
            <span class="text-muted">Profit</span>
            <Money :value="o.profit_total" tone="profit" />
          </div>
        </button>
        <p v-if="!ordersStore.orders.length" class="text-sm text-muted">
          No orders found
        </p>
      </div>

      <!-- Desktop table -->
      <div class="table-wrap hidden md:block">
        <table>
          <thead>
            <tr>
              <th>Date</th>
              <th>Customer</th>
              <th>Product</th>
              <th>Qty</th>
              <th>Sell total</th>
              <th v-if="auth.isAdmin">Profit</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="o in ordersStore.orders"
              :key="o.id"
              @click="openOrder(o.id)"
            >
              <td>{{ o.order_date }}</td>
              <td>
                <span class="font-semibold">{{ o.customer_name }}</span>
                <span v-if="o.company" class="block text-muted">{{ o.company }}</span>
              </td>
              <td>{{ o.product_name }}</td>
              <td>{{ o.quantity }}</td>
              <td><Money :value="sellTotal(o)" tone="owed" /></td>
              <td v-if="auth.isAdmin">
                <Money :value="o.profit_total" tone="profit" />
              </td>
              <td><StatusBadge :status="o.status" /></td>
            </tr>
            <tr v-if="!ordersStore.orders.length">
              <td :colspan="auth.isAdmin ? 7 : 6" class="text-muted">No orders found</td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>
  </div>
</template>
