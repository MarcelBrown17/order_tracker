const PALETTE = [
  { bg: '#fbe3a1', tone: '#f0be6a', dot: '#b9772f' },
  { bg: '#f7c9d4', tone: '#6b3e28', dot: '#f2d3a4' },
  { bg: '#cfe6d6', tone: '#d9a25e', dot: '#8b5a2b' },
  { bg: '#d9d3f0', tone: '#f5dda8', dot: '#e8c27a' },
]

const BY_NAME = [
  { match: /pie/i, shape: 'pie', bg: '#fbe3a1', tone: '#e9b563', dot: '#8a5a22' },
  { match: /samoos/i, shape: 'samoosa', bg: '#cfe6d6', tone: '#e7b873', dot: '#b9772f' },
  { match: /hertzog/i, shape: 'sandwich', bg: '#f7c9d4', tone: '#f2d4a0', dot: '#c2255c' },
  { match: /romaney|cream/i, shape: 'sandwich', bg: '#d9d3f0', tone: '#6b3e28', dot: '#f2d3a4' },
  { match: /choc/i, shape: 'round', bg: '#f7c9d4', tone: '#6b3e28', dot: '#f2d3a4' },
  { match: /butter/i, shape: 'round', bg: '#fbe3a1', tone: '#f0be6a', dot: '#b9772f' },
  { match: /normal/i, shape: 'round', bg: '#cfe6d6', tone: '#d9a25e', dot: '#8b5a2b' },
]

export function productArt(product, index = 0) {
  const hit = BY_NAME.find((entry) => entry.match.test(product?.name || ''))
  if (hit) {
    const { match, ...art } = hit
    return art
  }
  return { shape: 'round', ...PALETTE[index % PALETTE.length] }
}
