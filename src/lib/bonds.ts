export type BondType = 'OTS' | 'TOS'

export type BondPosition = {
  id: string
  bondType: BondType
  purchaseDate: string
  maturityDate: string
  quantity: number
  nominalPerBond: number
  interestRate: number
}

export type BondStatus = 'OPEN' | 'CLOSED'

export type BondCalculation = {
  purchaseValue: number
  interest: number
  finalValue: number
  roi: number
  status: BondStatus
}

const MS_PER_DAY = 24 * 60 * 60 * 1000

const round2 = (value: number) => Number(value.toFixed(2))

const parseIsoDate = (value: string) => {
  const [yRaw, mRaw, dRaw] = value.split('-')
  const y = Number(yRaw ?? 1970)
  const m = Number(mRaw ?? 1)
  const d = Number(dRaw ?? 1)
  return new Date(Date.UTC(y, m - 1, d))
}

const toIsoDate = (date: Date) => {
  const y = date.getUTCFullYear()
  const m = String(date.getUTCMonth() + 1).padStart(2, '0')
  const d = String(date.getUTCDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

const daysBetween = (start: string, end: string) => {
  const diff = parseIsoDate(end).getTime() - parseIsoDate(start).getTime()
  return Math.max(0, Math.round(diff / MS_PER_DAY))
}

const fullYearsBetween = (start: string, end: string) => {
  const startDate = parseIsoDate(start)
  const endDate = parseIsoDate(end)

  let years = endDate.getUTCFullYear() - startDate.getUTCFullYear()
  const endMonth = endDate.getUTCMonth()
  const startMonth = startDate.getUTCMonth()
  const endDay = endDate.getUTCDate()
  const startDay = startDate.getUTCDate()

  if (endMonth < startMonth || (endMonth === startMonth && endDay < startDay)) {
    years -= 1
  }

  return Math.max(0, years)
}

export const getBondMaturityDate = (bondType: BondType, purchaseDate: string) => {
  const date = parseIsoDate(purchaseDate)
  if (bondType === 'OTS') {
    date.setUTCMonth(date.getUTCMonth() + 3)
  } else {
    date.setUTCFullYear(date.getUTCFullYear() + 3)
  }
  return toIsoDate(date)
}

export const calculateBondPosition = (
  position: BondPosition,
  todayIso: string = new Date().toISOString().slice(0, 10),
): BondCalculation => {
  const purchaseValue = position.quantity * position.nominalPerBond

  let interest = 0
  let finalValue = purchaseValue

  if (position.bondType === 'OTS') {
    const daysHeld = daysBetween(position.purchaseDate, position.maturityDate)
    interest = purchaseValue * position.interestRate * (daysHeld / 365)
    finalValue = purchaseValue + interest
  } else {
    const yearsHeld = fullYearsBetween(position.purchaseDate, position.maturityDate)
    finalValue = purchaseValue * (1 + position.interestRate) ** yearsHeld
    interest = finalValue - purchaseValue
  }

  const roi = purchaseValue > 0 ? (finalValue - purchaseValue) / purchaseValue : 0
  const status: BondStatus = todayIso < position.maturityDate ? 'OPEN' : 'CLOSED'

  return {
    purchaseValue: round2(purchaseValue),
    interest: round2(interest),
    finalValue: round2(finalValue),
    roi,
    status,
  }
}
