import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2'

type Line = {
  id: string
  order_group_id: string
  partner_name: string
  customer_name: string
  order_date: string
  date_paid: string | null
  product_name: string
  quantity: number
  unit_sell_price: number
  pay_eom: boolean
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

function fmtDate(iso: string | null) {
  if (!iso) return '-'
  const [y, m, d] = iso.slice(0, 10).split('-').map(Number)
  return `${d} ${MONTHS[m - 1]} ${y}`
}

function money(n: number) {
  return 'R' + n.toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ',')
}

function esc(s: string) {
  return s.replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!)
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })
}

function buildEmail(lines: Line[], appUrl: string | undefined) {
  const first = lines[0]
  const total = lines.reduce((s, l) => s + Number(l.quantity) * Number(l.unit_sell_price), 0)
  const payment = first.pay_eom ? `End of month (${fmtDate(first.date_paid)})` : 'Paying now'

  const cell = 'padding:6px 8px;border-bottom:1px solid #eee;'
  const rows = lines
    .map(
      l => `<tr>
        <td style="${cell}">${l.quantity} x ${esc(l.product_name)}</td>
        <td style="${cell}text-align:right;">${money(Number(l.quantity) * Number(l.unit_sell_price))}</td>
      </tr>`
    )
    .join('')

  const details = [
    ['Customer', esc(first.customer_name)],
    ['Order date', fmtDate(first.order_date)],
    ['Payment', payment],
  ]
    .map(([k, v]) => `<tr><td style="padding:2px 12px 2px 0;color:#777;">${k}</td><td style="padding:2px 0;">${v}</td></tr>`)
    .join('')

  const link = appUrl
    ? `<p><a href="${appUrl.replace(/\/$/, '')}/orders/${first.id}">Open the order</a></p>`
    : ''

  const html = `
    <div style="font-family:Arial,sans-serif;font-size:14px;color:#2a1a12;">
      <p>Hi Marcel,</p>
      <p><strong>${esc(first.partner_name)}</strong> just added an order.</p>
      <table style="margin:0 0 16px;border-collapse:collapse;">${details}</table>
      <table style="width:100%;max-width:420px;border-collapse:collapse;">
        ${rows}
        <tr>
          <td style="padding:8px;font-weight:bold;">Total</td>
          <td style="padding:8px;font-weight:bold;text-align:right;">${money(total)}</td>
        </tr>
      </table>
      ${link}
    </div>
  `

  const subject = `New order from ${first.partner_name}: ${first.customer_name} (${money(total)})`
  return { subject, html }
}

Deno.serve(async req => {
  const secret = req.headers.get('x-report-secret') ?? ''
  const body = await req.json().catch(() => ({}))
  const groupIds: string[] = Array.isArray(body?.group_ids) ? body.group_ids : []
  if (!groupIds.length) return json({ error: 'No orders given' }, 400)

  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false },
  })

  const { data, error } = await supabase.rpc('partner_order_alert', { p_secret: secret, p_group_ids: groupIds })
  if (error) return json({ error: 'Not allowed' }, 401)

  const lines = (data ?? []) as Line[]
  if (!lines.length) return json({ sent: 0 })

  const apiKey = Deno.env.get('RESEND_API_KEY')
  if (!apiKey) return json({ error: 'RESEND_API_KEY is not set' }, 500)

  const to = Deno.env.get('REPORT_EMAIL_TO') ?? 'marcelbrown413@gmail.com'
  const from = Deno.env.get('REPORT_EMAIL_FROM') ?? 'Marcel Orders <onboarding@resend.dev>'
  const appUrl = Deno.env.get('APP_URL')

  const groups = new Map<string, Line[]>()
  for (const l of lines) {
    if (!groups.has(l.order_group_id)) groups.set(l.order_group_id, [])
    groups.get(l.order_group_id)!.push(l)
  }

  let sent = 0
  const failures: string[] = []
  for (const group of groups.values()) {
    const { subject, html } = buildEmail(group, appUrl)
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ from, to: [to], subject, html }),
    })
    if (res.ok) sent++
    else failures.push(await res.text())
  }

  if (failures.length) return json({ error: 'Email failed', sent, detail: failures }, 502)
  return json({ sent, to })
})
