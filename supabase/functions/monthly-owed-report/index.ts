import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2'
import { PDFDocument, PDFFont, PDFPage, StandardFonts, rgb } from 'npm:pdf-lib@1.17.1'
import { encodeBase64 } from 'jsr:@std/encoding@1/base64'

type Line = {
  order_group_id: string
  customer_name: string
  order_date: string
  date_paid: string | null
  order_type: string
  product_name: string
  quantity: number
  unit_sell_price: number
  pay_eom: boolean
}

type Order = {
  id: string
  customer: string
  orderDate: string
  datePaid: string | null
  items: string
  total: number
}

type CustomerGroup = { customer: string; orders: Order[]; total: number }

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

function fmtDate(iso: string | null) {
  if (!iso) return '-'
  const [y, m, d] = iso.slice(0, 10).split('-').map(Number)
  return `${d} ${MONTHS[m - 1]} ${y}`
}

function money(n: number) {
  return 'R' + n.toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ',')
}

// Standard PDF fonts only cover Latin-1.
function clean(s: string) {
  return s.replace(/[^\x20-\x7E\xA0-\xFF]/g, '')
}

function toOrders(lines: Line[]): Order[] {
  const map = new Map<string, Order>()
  for (const l of lines) {
    let o = map.get(l.order_group_id)
    if (!o) {
      o = {
        id: l.order_group_id,
        customer: l.customer_name,
        orderDate: l.order_date,
        datePaid: l.date_paid,
        items: '',
        total: 0,
      }
      map.set(l.order_group_id, o)
    }
    o.items += (o.items ? ', ' : '') + `${l.quantity}\u00A0x\u00A0${l.product_name}`
    o.total += Number(l.quantity) * Number(l.unit_sell_price)
  }
  return [...map.values()]
}

function byCustomer(orders: Order[]): CustomerGroup[] {
  const map = new Map<string, CustomerGroup>()
  for (const o of orders) {
    const key = o.customer.toLowerCase()
    let g = map.get(key)
    if (!g) {
      g = { customer: o.customer, orders: [], total: 0 }
      map.set(key, g)
    }
    g.orders.push(o)
    g.total += o.total
  }
  return [...map.values()]
    .map(g => ({ ...g, orders: g.orders.sort((a, b) => a.orderDate.localeCompare(b.orderDate)) }))
    .sort((a, b) => a.customer.localeCompare(b.customer))
}

function wrap(text: string, font: PDFFont, size: number, width: number) {
  const words = clean(text).split(' ')
  const out: string[] = []
  let line = ''
  for (const w of words) {
    const next = line ? `${line} ${w}` : w
    if (font.widthOfTextAtSize(next, size) > width && line) {
      out.push(line)
      line = w
    } else {
      line = next
    }
  }
  if (line) out.push(line)
  return out.length ? out : ['']
}

async function buildPdf(eom: CustomerGroup[], pending: CustomerGroup[], today: string) {
  const doc = await PDFDocument.create()
  const font = await doc.embedFont(StandardFonts.Helvetica)
  const bold = await doc.embedFont(StandardFonts.HelveticaBold)

  const ink = rgb(0.165, 0.102, 0.071)
  const accent = rgb(0.761, 0.145, 0.361)
  const muted = rgb(0.45, 0.4, 0.37)
  const rule = rgb(0.88, 0.84, 0.8)

  const W = 595.28
  const H = 841.89
  const M = 40
  const col = { customer: M, date: 210, items: 290, total: W - M }
  const itemsWidth = col.total - 70 - col.items

  let page: PDFPage = doc.addPage([W, H])
  let y = H - M

  const newPage = () => {
    page = doc.addPage([W, H])
    y = H - M
  }
  const ensure = (h: number) => {
    if (y - h < M) newPage()
  }
  const text = (s: string, x: number, size = 10, f = font, color = ink) => {
    page.drawText(clean(s), { x, y, size, font: f, color })
  }
  const right = (s: string, x: number, size = 10, f = font, color = ink) => {
    const t = clean(s)
    page.drawText(t, { x: x - f.widthOfTextAtSize(t, size), y, size, font: f, color })
  }
  const hr = () => page.drawLine({ start: { x: M, y: y + 4 }, end: { x: W - M, y: y + 4 }, thickness: 0.6, color: rule })

  text('Marcel', M, 22, bold, accent)
  y -= 22
  text('Money owed report', M, 14, bold)
  y -= 16
  text(`Generated ${fmtDate(today)}`, M, 10, font, muted)
  y -= 28

  const eomTotal = eom.reduce((s, g) => s + g.total, 0)
  const pendingTotal = pending.reduce((s, g) => s + g.total, 0)

  text('End of month (unpaid)', M, 11, bold)
  right(money(eomTotal), col.total, 11, bold)
  y -= 15
  text('Other pending orders', M, 11, bold)
  right(money(pendingTotal), col.total, 11, bold)
  y -= 15
  hr()
  y -= 12
  text('Total outstanding', M, 12, bold, accent)
  right(money(eomTotal + pendingTotal), col.total, 12, bold, accent)
  y -= 34

  const section = (title: string, subtitle: string, groups: CustomerGroup[], total: number) => {
    ensure(70)
    text(title, M, 15, bold, accent)
    y -= 15
    text(subtitle, M, 9, font, muted)
    y -= 20

    if (!groups.length) {
      text('Nothing outstanding.', M, 10, font, muted)
      y -= 30
      return
    }

    const header = () => {
      text('Customer', col.customer, 9, bold, muted)
      text('Ordered', col.date, 9, bold, muted)
      text('Items', col.items, 9, bold, muted)
      right('Amount', col.total, 9, bold, muted)
      y -= 6
      hr()
      y -= 10
    }
    header()

    for (const g of groups) {
      for (let i = 0; i < g.orders.length; i++) {
        const o = g.orders[i]
        const lines = wrap(o.items, font, 9, itemsWidth)
        const h = lines.length * 12 + 4
        if (y - h < M + 20) {
          newPage()
          header()
        }
        if (i === 0) text(g.customer, col.customer, 10, bold)
        text(fmtDate(o.orderDate), col.date, 9)
        right(money(o.total), col.total, 10)
        for (const l of lines) {
          text(l, col.items, 9)
          y -= 12
        }
        y -= 4
      }
      if (g.orders.length > 1) {
        ensure(16)
        right(`${g.customer} total  ${money(g.total)}`, col.total, 9, bold, muted)
        y -= 14
      }
      hr()
      y -= 10
    }

    ensure(20)
    text(`${title} total`, M, 11, bold)
    right(money(total), col.total, 11, bold)
    y -= 34
  }

  section(
    'End of month orders',
    'Customers who chose to pay at the end of the month and have not paid yet.',
    eom,
    eomTotal
  )
  section(
    'Other pending orders',
    'Orders still marked pending that were meant to be paid straight away.',
    pending,
    pendingTotal
  )

  const pages = doc.getPages()
  pages.forEach((p, i) => {
    const label = `Page ${i + 1} of ${pages.length}`
    p.drawText(label, { x: W - M - font.widthOfTextAtSize(label, 8), y: 20, size: 8, font, color: muted })
  })

  return { bytes: await doc.save(), eomTotal, pendingTotal }
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })
}

Deno.serve(async req => {
  const secret = req.headers.get('x-report-secret') ?? ''
  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false },
  })

  const { data, error } = await supabase.rpc('owed_report', { p_secret: secret })
  if (error) return json({ error: 'Not allowed' }, 401)

  const lines = (data ?? []) as Line[]
  const eom = byCustomer(toOrders(lines.filter(l => l.pay_eom)))
  const pending = byCustomer(toOrders(lines.filter(l => !l.pay_eom)))

  const today = new Date().toLocaleDateString('en-CA', { timeZone: 'Africa/Johannesburg' })
  const { bytes, eomTotal, pendingTotal } = await buildPdf(eom, pending, today)
  const filename = `money-owed-${today}.pdf`

  if (new URL(req.url).searchParams.get('preview') === '1') {
    return new Response(bytes, {
      headers: { 'Content-Type': 'application/pdf', 'Content-Disposition': `inline; filename="${filename}"` },
    })
  }

  const apiKey = Deno.env.get('RESEND_API_KEY')
  if (!apiKey) return json({ error: 'RESEND_API_KEY is not set' }, 500)

  const to = Deno.env.get('REPORT_EMAIL_TO') ?? 'marcelbrown413@gmail.com'
  const from = Deno.env.get('REPORT_EMAIL_FROM') ?? 'Marcel Orders <onboarding@resend.dev>'

  const html = `
    <p>Hi Marcel,</p>
    <p>Here is who owes you money as of ${fmtDate(today)}.</p>
    <ul>
      <li>End of month orders (unpaid): <strong>${money(eomTotal)}</strong> from ${eom.length} customer(s)</li>
      <li>Other pending orders: <strong>${money(pendingTotal)}</strong> from ${pending.length} customer(s)</li>
    </ul>
    <p>The full list is in the attached PDF.</p>
  `

  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from,
      to: [to],
      subject: `Money owed: ${money(eomTotal + pendingTotal)} (${fmtDate(today)})`,
      html,
      attachments: [{ filename, content: encodeBase64(bytes) }],
    }),
  })

  if (!res.ok) return json({ error: 'Email failed', detail: await res.text() }, 502)
  return json({ sent: true, to, eomTotal, pendingTotal })
})
