<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useOrdersStore } from '../stores/orders'
import Money from '../components/Money.vue'
import StatusBadge from '../components/StatusBadge.vue'
import AppLoader from '../components/AppLoader.vue'
import { useToast } from '../composables/useToast'

const auth = useAuthStore()
const ordersStore = useOrdersStore()
const router = useRouter()
const toast = useToast()

const loading = ref(true)
const stats = ref(null)
const partnerStats = ref(null)

onMounted(async () => {
  try {
    if (!auth.partner) {
      return
    }
    if (auth.isAdmin) {
      stats.value = await ordersStore.fetchDashboardData()
    } else {
      partnerStats.value = await ordersStore.fetchPartnerDashboard(
        auth.partner.id
      )
    }
  } catch (e) {
    toast.error(e.message || 'Failed to load dashboard')
  } finally {
    loading.value = false
  }
})

function openOrder(id) {
  router.push({ name: 'order-detail', params: { id } })
}
</script>

<template>
  <div class="bakery-shell bakery-stack">
    <div>
      <h1 class="page-title">Dashboard</h1>
      <p class="page-subtitle">
        <template v-if="auth.isAdmin">This month and partner commissions</template>
        <template v-else>Your commissions across orders</template>
      </p>
    </div>

    <div
      v-if="!auth.isLinked && !auth.loading"
      class="surface-card p-4 text-sm"
    >
      <p class="font-bold">Account not linked</p>
      <p class="mt-2 text-muted">
        Your login is not linked to a partner (Marcel, Delton, or Richard).
        Ask Marcel to set your email on the partner row in Supabase, then sign
        in again.
      </p>
    </div>

    <template v-else>
      <AppLoader v-if="loading" label="Loading home" />

      <template v-else-if="auth.isAdmin && stats">
        <div class="grid grid-cols-2 gap-3">
          <div class="surface-card p-3.5">
            <p class="section-label">Orders</p>
            <p class="mt-1 text-2xl font-extrabold tabular-nums">
              {{ stats.totalOrdersMonth }}
            </p>
            <p class="mt-0.5 text-xs text-muted">This month</p>
          </div>
          <div class="surface-card p-3.5">
            <p class="section-label">Revenue</p>
            <p class="mt-1 text-xl font-extrabold">
              <Money :value="stats.totalRevenueMonth" />
            </p>
            <p class="mt-0.5 text-xs text-muted">Paid orders this month</p>
          </div>
          <div class="surface-card p-3.5">
            <p class="section-label">Profit</p>
            <p class="mt-1 text-xl font-extrabold">
              <Money :value="stats.totalProfitMonth" tone="profit" />
            </p>
            <p class="mt-0.5 text-xs text-muted">Paid orders this month</p>
          </div>
          <div class="surface-card p-3.5">
            <p class="section-label">Payable</p>
            <p class="mt-1 text-xl font-extrabold">
              <Money :value="stats.unpaidSplitsTotal" tone="owed" />
            </p>
            <p class="mt-0.5 text-xs text-muted">Ready to pay partners</p>
          </div>
        </div>

        <div>
          <h2 class="section-label mb-3">Partners</h2>
          <div class="grid gap-3 sm:grid-cols-3">
            <div
              v-for="p in stats.partnerStats"
              :key="p.id"
              class="surface-card space-y-2.5 p-3.5"
            >
              <p class="text-base font-bold">
                {{ p.name }}
                <span v-if="p.is_admin" class="text-xs font-semibold text-muted">
                  Admin
                </span>
              </p>
              <div class="flex justify-between text-sm">
                <span class="text-muted">Payable now</span>
                <Money :value="p.unpaid" tone="owed" />
              </div>
              <div class="flex justify-between text-sm">
                <span class="text-muted">Already paid</span>
                <span class="font-semibold tabular-nums">
                  <Money :value="p.paid" />
                </span>
              </div>
              <div class="flex justify-between text-sm">
                <span class="text-muted">Lifetime</span>
                <Money :value="p.earned" tone="profit" />
              </div>
            </div>
          </div>
        </div>

        <div>
          <h2 class="section-label mb-3">Recent orders</h2>
          <div class="space-y-2.5 md:hidden">
            <button
              v-for="o in stats.recentOrders"
              :key="o.id"
              type="button"
              class="list-card w-full text-left"
              @click="openOrder(o.id)"
            >
              <div class="flex items-start justify-between gap-3">
                <div class="min-w-0">
                  <p class="truncate font-bold">{{ o.customer_name }}</p>
                  <p class="truncate text-sm text-muted">{{ o.product_name }}</p>
                </div>
                <StatusBadge :status="o.status" />
              </div>
              <div class="flex items-center justify-between text-sm">
                <span class="text-muted">{{ o.order_date }}</span>
                <Money :value="o.profit_total" tone="profit" />
              </div>
            </button>
            <p v-if="!stats.recentOrders.length" class="text-sm text-muted">
              No orders yet
            </p>
          </div>
          <div class="table-wrap hidden md:block">
            <table>
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Customer</th>
                  <th>Product</th>
                  <th>Profit</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="o in stats.recentOrders"
                  :key="o.id"
                  @click="openOrder(o.id)"
                >
                  <td>{{ o.order_date }}</td>
                  <td>{{ o.customer_name }}</td>
                  <td>{{ o.product_name }}</td>
                  <td><Money :value="o.profit_total" tone="profit" /></td>
                  <td><StatusBadge :status="o.status" /></td>
                </tr>
                <tr v-if="!stats.recentOrders.length">
                  <td colspan="5" class="text-muted">No orders yet</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </template>

      <template v-else-if="partnerStats">
        <div class="grid gap-3">
          <div class="surface-card p-4">
            <p class="section-label">Owed to you</p>
            <p class="mt-1 text-3xl font-extrabold">
              <Money :value="partnerStats.unpaid" tone="owed" />
            </p>
            <p class="mt-1 text-xs text-muted">
              Ready once the customer order is marked paid
            </p>
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div class="surface-card p-3.5">
              <p class="section-label">Awaiting payment</p>
              <p class="mt-1 text-xl font-extrabold">
                <Money :value="partnerStats.awaiting" />
              </p>
              <p class="mt-0.5 text-xs text-muted">On open orders</p>
            </div>
            <div class="surface-card p-3.5">
              <p class="section-label">Paid out</p>
              <p class="mt-1 text-xl font-extrabold">
                <Money :value="partnerStats.paid" />
              </p>
            </div>
          </div>
          <div class="surface-card p-3.5">
            <p class="section-label">Lifetime (paid orders)</p>
            <p class="mt-1 text-xl font-extrabold">
              <Money :value="partnerStats.earned" tone="profit" />
            </p>
          </div>
        </div>

        <div v-if="partnerStats.recentSplits?.length">
          <h2 class="section-label mb-3">Your commissions</h2>
          <div class="space-y-2.5">
            <button
              v-for="s in partnerStats.recentSplits"
              :key="s.id"
              type="button"
              class="list-card w-full text-left"
              @click="openOrder(s.order_id)"
            >
              <div class="flex items-start justify-between gap-3">
                <div class="min-w-0">
                  <p class="truncate font-bold">{{ s.customer_name }}</p>
                  <p class="truncate text-sm text-muted">
                    {{ s.product_name }}
                  </p>
                </div>
                <StatusBadge :status="s.order_status" />
              </div>
              <div class="flex items-center justify-between text-sm">
                <span class="text-muted">{{ s.order_date }}</span>
                <Money :value="s.amount" tone="owed" />
              </div>
            </button>
          </div>
        </div>
        <p v-else class="text-sm text-muted">
          No commissions yet. Linked orders (Delton or All) will show here.
        </p>
      </template>
    </template>
  </div>
</template>
