import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase'

export const useOrdersStore = defineStore('orders', () => {
  const orders = ref([])
  const currentOrder = ref(null)
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

    if (status && status !== 'all') {
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
    const { error: err } = await supabase.from('orders').delete().eq('id', id)
    if (err) throw err
    orders.value = orders.value.filter((o) => o.id !== id)
    if (currentOrder.value?.id === id) {
      currentOrder.value = null
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

    const activeSplits = allSplits.filter((s) => s.orders?.status !== 'cancelled')

    const partnerStats = partners.map((u) => {
      const splits = activeSplits.filter((s) => s.user_id === u.id)
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
      totalOrdersMonth: thisMonth.length,
      totalRevenueMonth: thisMonth.reduce(
        (sum, o) => sum + Number(o.unit_sell_price) * Number(o.quantity),
        0
      ),
      totalProfitMonth: thisMonth.reduce(
        (sum, o) => sum + Number(o.profit_total),
        0
      ),
      unpaidSplitsTotal: activeSplits
        .filter((s) => !s.paid_out)
        .reduce((sum, s) => sum + Number(s.amount), 0),
      partnerStats,
      recentOrders: allOrders.slice(0, 5),
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
    const active = splits.filter((s) => s.order_status !== 'cancelled')
    const unpaid = active
      .filter((s) => !s.paid_out)
      .reduce((sum, s) => sum + Number(s.amount), 0)
    const paid = active
      .filter((s) => s.paid_out)
      .reduce((sum, s) => sum + Number(s.amount), 0)
    const earned = active.reduce((sum, s) => sum + Number(s.amount), 0)

    return {
      partnerId,
      unpaid,
      paid,
      earned,
      recentSplits: splits.slice(0, 8),
      splits,
    }
  }

  return {
    orders,
    currentOrder,
    currentSplits,
    loading,
    error,
    fetchOrders,
    fetchOrder,
    fetchSplits,
    createOrder,
    updateOrder,
    updateStatus,
    setSplitPaid,
    deleteOrder,
    fetchDashboardData,
    fetchMySplits,
    fetchPartnerDashboard,
  }
})
