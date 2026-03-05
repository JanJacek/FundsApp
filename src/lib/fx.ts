import { supabase } from '@/lib/supabase'

export type FxRateRequest = {
  currency: string
  date: string
}

type FxDbRow = {
  currency: string
  rate_date: string
  rate_to_pln: number | string
}

type NbpResponse = {
  rates?: Array<{
    mid?: number
  }>
}

export const fxRequestKey = (currency: string, date: string) => `${currency.toUpperCase()}|${date}`

const formatDate = (date: Date) => {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

const fetchNbpRate = async (currency: string, cutoff: string) => {
  try {
    const cutoffDate = new Date(`${cutoff}T00:00:00`)
    const startDate = new Date(cutoffDate)
    startDate.setDate(startDate.getDate() - 7)

    const url =
      `https://api.nbp.pl/api/exchangerates/rates/A/${currency}/` +
      `${formatDate(startDate)}/${formatDate(cutoffDate)}/?format=json`

    const response = await fetch(url)
    if (!response.ok) return null

    const json = (await response.json()) as NbpResponse
    const lastRate = json.rates?.[json.rates.length - 1]?.mid
    if (typeof lastRate !== 'number') return null

    return Number(lastRate)
  } catch {
    return null
  }
}

export const resolveFxRatesToPln = async (requests: FxRateRequest[]) => {
  const rates: Record<string, number> = {}

  const normalized = Array.from(
    new Set(
      requests
        .map((request) => ({
          currency: request.currency.toUpperCase(),
          date: request.date,
        }))
        .filter((request) => !!request.currency && !!request.date)
        .map((request) => fxRequestKey(request.currency, request.date)),
    ),
  ).map((key) => {
    const [currency, date] = key.split('|')
    return { currency: currency || 'PLN', date: date || new Date().toISOString().slice(0, 10) }
  })

  const nonPln = normalized.filter((request) => request.currency !== 'PLN')

  for (const request of normalized) {
    if (request.currency === 'PLN') {
      rates[fxRequestKey(request.currency, request.date)] = 1
    }
  }

  if (nonPln.length === 0) return { rates, missing: [] as string[] }

  const currencies = Array.from(new Set(nonPln.map((request) => request.currency)))
  const maxDate = nonPln.reduce((acc, request) => (request.date > acc ? request.date : acc), '1900-01-01')

  const dbRowsByCurrency = new Map<string, FxDbRow[]>()

  const { data, error } = await supabase
    .from('fx_rates')
    .select('currency, rate_date, rate_to_pln')
    .in('currency', currencies)
    .lte('rate_date', maxDate)
    .order('currency', { ascending: true })
    .order('rate_date', { ascending: false })

  if (!error) {
    for (const row of (data ?? []) as FxDbRow[]) {
      const currency = row.currency.toUpperCase()
      const list = dbRowsByCurrency.get(currency) ?? []
      list.push(row)
      dbRowsByCurrency.set(currency, list)
    }
  }

  const missing: Array<{ currency: string; date: string }> = []

  for (const request of nonPln) {
    const list = dbRowsByCurrency.get(request.currency) ?? []
    const found = list.find((row) => row.rate_date <= request.date)
    if (found) {
      rates[fxRequestKey(request.currency, request.date)] = Number(found.rate_to_pln)
      continue
    }

    missing.push(request)
  }

  if (missing.length > 0) {
    const uniqueMissing = Array.from(
      new Set(missing.map((request) => fxRequestKey(request.currency, request.date))),
    ).map((key) => {
      const [currency, date] = key.split('|')
      return { currency: currency || 'PLN', date: date || new Date().toISOString().slice(0, 10) }
    })

    const fetched = await Promise.all(
      uniqueMissing.map(async (request) => {
        const rate = await fetchNbpRate(request.currency, request.date)
        return { ...request, rate }
      }),
    )

    for (const item of fetched) {
      if (!item.rate) continue
      rates[fxRequestKey(item.currency, item.date)] = item.rate
    }
  }

  const unresolved = nonPln
    .filter((request) => !rates[fxRequestKey(request.currency, request.date)])
    .map((request) => fxRequestKey(request.currency, request.date))

  return {
    rates,
    missing: Array.from(new Set(unresolved)),
  }
}
