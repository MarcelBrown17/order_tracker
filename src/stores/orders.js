import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase'

export const useOrdersStore = defineStore('orders', () => {
  const orders = ref([])
  const currentOrder = ref(null)
  const currentOrderGroup = ref([])
  const currentSplits = ref([])
  const loading = ref(false)
  const error = ref(null)

  async function fetchOrders({
    status = null,
    search = '',
    createdBy = null,
  } = {}) {
    loading.value = true
    error.value = null
    let query = supabase
      .from('order_summary')
      .select('*')
      .order('order_date', { ascending: false })
      .order('created_at', { ascending: false })

    if (status === 'all' || !status) {
      // Default list: open orders only (hide paid + cancelled)
      query = query.eq('status', 'pending')
    } else {
      query = query.eq('status', status)
    }
    if (search.trim()) {
      query = query.ilike('customer_name', `%${search.trim()}%`)
    }
    if (createdBy) {
      query = query.eq('created_by', createdBy)
    }

    const { data, error: err } = await query
    loading.value = false
    if (err) {
      error.value = err.message
      throw err
    }
    orders.value = data ?? []
    return orders.value
  }

  async function fetchOrder(id) {
    loading.value = true
    error.value = null
    const { data, error: err } = await supabase
      .from('order_summary')
      .select('*')
      .eq('id', id)
      .single()
    loading.value = false
    if (err) {
      error.value = err.message
      throw err
    }
    currentOrder.value = data
    return data
  }

  async function fetchOrderGroup(id) {
    const order = await fetchOrder(id)
    const { data, error: err } = await supabase
      .from('order_summary')
      .select('*')
      .eq('order_group_id', order.order_group_id)
      .order('created_at')
    if (err) throw err
    currentOrderGroup.value = data ?? [order]
    return currentOrderGroup.value
  }

  async function fetchSplitsForGroup(orderIds) {
    if (!orderIds.length) {
      currentSplits.value = []
      return []
    }
    const { data, error: err } = await supabase
      .from('order_splits')
      .select('*, users(id, name)')
      .in('order_id', orderIds)
      .order('created_at')
    if (err) throw err
    currentSplits.value = data ?? []
    return currentSplits.value
  }

  async function fetchSplits(orderId) {
    const { data, error: err } = await supabase
      .from('order_splits')
      .select('*, users(id, name)')
      .eq('order_id', orderId)
      .order('created_at')
    if (err) throw err
    currentSplits.value = data ?? []
    return currentSplits.value
  }

  async function createOrder(payload) {
    const { data, error: err } = await supabase
      .from('orders')
      .insert(payload)
      .select()
      .single()
    if (err) throw err
    return data
  }

  async function deleteOrderLine(id) {
    const { error: err } = await supabase.from('orders').delete().eq('id', id)
    if (err) throw err
    currentOrderGroup.value = currentOrderGroup.value.filter((line) => line.id !== id)
    currentSplits.value = currentSplits.value.filter((s) => s.order_id !== id)
  }

  async function createOrdersBatch({ shared, items, orderGroupId }) {
    const rows = items.map((item) => ({
      ...shared,
      product_id: item.product_id,
      quantity: Number(item.quantity),
      unit_sell_price: Number(item.unit_sell_price),
      unit_cost: Number(item.unit_cost),
      is_bulk: !!item.is_bulk,
      order_group_id: orderGroupId,
    }))
    const { data, error: err } = await supabase
      .from('orders')
      .insert(rows)
      .select()
    if (err) throw err
    return data ?? []
  }

  async function updateOrder(id, payload) {
    const { data, error: err } = await supabase
      .from('orders')
      .update(payload)
      .eq('id', id)
      .select()
      .single()
    if (err) throw err
    return data
  }

  async function updateStatus(id, status) {
    const { data, error: err } = await supabase.rpc('set_order_status', {
      p_order_id: id,
      p_status: status,
    })
    if (err) throw err
    if (currentOrder.value?.id === id && data) {
      currentOrder.value = {
        ...currentOrder.value,
        status: data.status,
      }
    }
    if (currentOrderGroup.value.length) {
      const groupId = currentOrderGroup.value[0]?.order_group_id
      currentOrderGroup.value = currentOrderGroup.value.map((line) =>
        line.order_group_id === groupId ? { ...line, status } : line
      )
    }
    const idx = orders.value.findIndex((o) => o.id === id)
    if (idx !== -1) {
      orders.value[idx] = { ...orders.value[idx], status }
    }
    return data
  }

  async function setSplitPaid(splitId, paidOut) {
    const { data, error: err } = await supabase
      .from('order_splits')
      .update({ paid_out: paidOut })
      .eq('id', splitId)
      .select('*, users(id, name)')
      .single()
    if (err) throw err
    const idx = currentSplits.value.findIndex((s) => s.id === splitId)
    if (idx !== -1) currentSplits.value[idx] = data
    return data
  }

  async function deleteOrder(id) {
    const order = currentOrder.value?.id === id
      ? currentOrder.value
      : orders.value.find((o) => o.id === id)
    const groupId = order?.order_group_id || id

    const { error: err } = await supabase
      .from('orders')
      .delete()
      .eq('order_group_id', groupId)
    if (err) throw err
    orders.value = orders.value.filter(
      (o) => (o.order_group_id || o.id) !== groupId
    )
    if (currentOrder.value && (currentOrder.value.order_group_id || currentOrder.value.id) === groupId) {
      currentOrder.value = null
      currentOrderGroup.value = []
      currentSplits.value = []
    }
  }

  async function fetchDashboardData() {
    const now = new Date()
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1)
      .toISOString()
      .slice(0, 10)
    const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0)
      .toISOString()
      .slice(0, 10)

    const [ordersRes, splitsRes, usersRes] = await Promise.all([
      supabase.from('order_summary').select('*').order('order_date', {
        ascending: false,
      }),
      supabase.from('order_splits').select('*, users(id, name), orders!inner(status)'),
      supabase.from('users').select('*').order('name'),
    ])

    if (ordersRes.error) throw ordersRes.error
    if (splitsRes.error) throw splitsRes.error
    if (usersRes.error) throw usersRes.error

    const allOrders = ordersRes.data ?? []
    const allSplits = splitsRes.data ?? []
    const partners = usersRes.data ?? []

    const thisMonth = allOrders.filter(
      (o) =>
        o.status !== 'cancelled' &&
        o.order_date >= monthStart &&
        o.order_date <= monthEnd
    )

    const thisMonthPaid = thisMonth.filter((o) => o.status === 'paid')

    const thisMonthGroupIds = new Set(
      thisMonth.map((o) => o.order_group_id || o.id)
    )

    // Commissions only count once the customer has paid
    const paidOrderSplits = allSplits.filter((s) => s.orders?.status === 'paid')

    const partnerStats = partners.map((u) => {
      const splits = paidOrderSplits.filter((s) => s.user_id === u.id)
      const unpaid = splits
        .filter((s) => !s.paid_out)
        .reduce((sum, s) => sum + Number(s.amount), 0)
      const paid = splits
        .filter((s) => s.paid_out)
        .reduce((sum, s) => sum + Number(s.amount), 0)
      const earned = splits.reduce((sum, s) => sum + Number(s.amount), 0)
      return { ...u, unpaid, paid, earned }
    })

    return {
      totalOrdersMonth: thisMonthGroupIds.size,
      totalRevenueMonth: thisMonthPaid.reduce(
        (sum, o) => sum + Number(o.unit_sell_price) * Number(o.quantity),
        0
      ),
      totalProfitMonth: thisMonthPaid.reduce(
        (sum, o) => sum + Number(o.profit_total),
        0
      ),
      unpaidSplitsTotal: paidOrderSplits
        .filter((s) => !s.paid_out)
        .reduce((sum, s) => sum + Number(s.amount), 0),
      partnerStats,
      recentOrders: allOrders
        .filter((o) => o.status !== 'cancelled')
        .slice(0, 5),
    }
  }

  async function fetchMySplits({ paidFilter = 'all' } = {}) {
    loading.value = true
    error.value = null
    let query = supabase
      .from('my_splits')
      .select('*')
      .order('order_date', { ascending: false })
      .order('created_at', { ascending: false })

    if (paidFilter === 'unpaid') query = query.eq('paid_out', false)
    if (paidFilter === 'paid') query = query.eq('paid_out', true)

    const { data, error: err } = await query
    loading.value = false
    if (err) {
      error.value = err.message
      throw err
    }
    return data ?? []
  }

  async function fetchPartnerDashboard(partnerId) {
    const splits = await fetchMySplits()
    const paidOrders = splits.filter((s) => s.order_status === 'paid')
    const pendingOrders = splits.filter((s) => s.order_status === 'pending')
    const unpaid = paidOrders
      .filter((s) => !s.paid_out)
      .reduce((sum, s) => sum + Number(s.amount), 0)
    const paid = paidOrders
      .filter((s) => s.paid_out)
      .reduce((sum, s) => sum + Number(s.amount), 0)
    const earned = paidOrders.reduce((sum, s) => sum + Number(s.amount), 0)
    const awaiting = pendingOrders.reduce((sum, s) => sum + Number(s.amount), 0)

    return {
      partnerId,
      unpaid,
      paid,
      earned,
      awaiting,
      recentSplits: [...paidOrders, ...pendingOrders].slice(0, 8),
      splits: paidOrders,
      pendingSplits: pendingOrders,
    }
  }

  return {
    orders,
    currentOrder,
    currentOrderGroup,
    currentSplits,
    loading,
    error,
    fetchOrders,
    fetchOrder,
    fetchOrderGroup,
    fetchSplits,
    fetchSplitsForGroup,
    createOrder,
    createOrdersBatch,
    updateOrder,
    deleteOrderLine,
    updateStatus,
    setSplitPaid,
    deleteOrder,
    fetchDashboardData,
    fetchMySplits,
    fetchPartnerDashboard,
  }
})
