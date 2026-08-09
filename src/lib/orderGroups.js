export function sellTotal(order) {
  return Number(order.unit_sell_price) * Number(order.quantity)
}

export function groupOrders(orders) {
  const map = new Map()

  for (const order of orders) {
    const groupId = order.order_group_id || order.id
    if (!map.has(groupId)) {
      map.set(groupId, {
        id: order.id,
        groupId,
        customer_name: order.customer_name,
        company: order.company,
        order_date: order.order_date,
        status: order.status,
        order_type: order.order_type || 'admin',
        items: [],
        sellTotal: 0,
        profitTotal: 0,
      })
    }
    const group = map.get(groupId)
    group.items.push(order)
    group.sellTotal += sellTotal(order)
    group.profitTotal += Number(order.profit_total) || 0
    group.id = order.id
    group.status = pickGroupStatus(group.items)
  }

  return [...map.values()]
}

function pickGroupStatus(items) {
  const statuses = [...new Set(items.map((i) => i.status))]
  if (statuses.length === 1) return statuses[0]
  if (statuses.includes('pending')) return 'pending'
  if (statuses.includes('paid')) return 'paid'
  return statuses[0]
}
