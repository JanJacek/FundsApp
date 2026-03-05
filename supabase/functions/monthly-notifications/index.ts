import { createClient } from 'npm:@supabase/supabase-js@2'

type RunMode = 'scheduled' | 'manual'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY')
}

const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

const warawParts = (date: Date) => {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Warsaw',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  })

  const parts = formatter.formatToParts(date)
  const get = (type: Intl.DateTimeFormatPartTypes) => parts.find((p) => p.type === type)?.value ?? ''

  return {
    year: Number(get('year')),
    month: Number(get('month')),
    day: Number(get('day')),
    hour: Number(get('hour')),
    minute: Number(get('minute')),
  }
}

const lastDayOfMonth = (year: number, month: number) => new Date(Date.UTC(year, month, 0)).getUTCDate()

const toCycleMonth = (year: number, month: number) => {
  const lastDay = String(lastDayOfMonth(year, month)).padStart(2, '0')
  return `${year}-${String(month).padStart(2, '0')}-${lastDay}`
}

Deno.serve(async (req) => {
  try {
    const now = new Date()
    const w = warawParts(now)
    const runMode: RunMode = req.headers.get('x-run-mode') === 'manual' ? 'manual' : 'scheduled'

    const isMonthEnd = w.day === lastDayOfMonth(w.year, w.month)
    const isTargetHour = w.hour === 18

    if (runMode === 'scheduled' && (!isMonthEnd || !isTargetHour)) {
      return new Response(
        JSON.stringify({
          ok: true,
          skipped: true,
          reason: 'Not month-end 18:00 Europe/Warsaw',
          warsaw_time: `${w.year}-${String(w.month).padStart(2, '0')}-${String(w.day).padStart(2, '0')} ${String(w.hour).padStart(2, '0')}:${String(w.minute).padStart(2, '0')}`,
        }),
        { headers: { 'content-type': 'application/json' }, status: 200 },
      )
    }

    const cycleMonth = toCycleMonth(w.year, w.month)
    const title = 'Miesięczne przypomnienie'
    const body = 'Uzupełnij dane portfela za bieżący miesiąc.'

    const { count: usersCount, error: usersErr } = await admin
      .from('user_profiles')
      .select('owner_id', { count: 'exact', head: true })

    if (usersErr) {
      console.error('user count error', usersErr)
    }

    const { data: createdCount, error: rpcError } = await admin.rpc('create_monthly_notifications', {
      p_cycle_month: cycleMonth,
      p_title: title,
      p_body: body,
      p_source: 'monthly_job',
    })

    if (rpcError) {
      console.error('RPC error', rpcError)
      return new Response(JSON.stringify({ ok: false, error: rpcError.message }), {
        headers: { 'content-type': 'application/json' },
        status: 500,
      })
    }

    console.log(
      JSON.stringify({
        event: 'monthly_notifications_run',
        cycle_month: cycleMonth,
        users_count: usersCount ?? null,
        inserted_count: createdCount ?? 0,
      }),
    )

    return new Response(
      JSON.stringify({
        ok: true,
        cycle_month: cycleMonth,
        users_count: usersCount ?? null,
        inserted_count: createdCount ?? 0,
      }),
      { headers: { 'content-type': 'application/json' }, status: 200 },
    )
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error'
    console.error('monthly-notifications fatal error', message)
    return new Response(JSON.stringify({ ok: false, error: message }), {
      headers: { 'content-type': 'application/json' },
      status: 500,
    })
  }
})
