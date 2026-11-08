const PALETTE = [
  { bg: '#fbe3a1', tone: '#f0be6a', dot: '#b9772f' },
  { bg: '#f7c9d4', tone: '#6b3e28', dot: '#f2d3a4' },
  { bg: '#cfe6d6', tone: '#d9a25e', dot: '#8b5a2b' },
  { bg: '#d9d3f0', tone: '#f5dda8', dot: '#e8c27a' },
]

/** More specific name matches first. */
const BY_NAME = [
  {
    match: /special\s+chocolate\s+butter/i,
    shape: 'round',
    bg: '#f7c9d4',
    tone: '#6b3e28',
    dot: '#f2d3a4',
    image: '/images/products/special-chocolate-butter-mix.jpg',
  },
  {
    match: /^hertzog/i,
    shape: 'sandwich',
    bg: '#f7c9d4',
    tone: '#f2d4a0',
    dot: '#c2255c',
    image: '/images/products/hertzoggie.jpg',
  },
  {
    match: /normal\s+mix\s+with\s+hertzog/i,
    shape: 'sandwich',
    bg: '#f7c9d4',
    tone: '#f2d4a0',
    dot: '#c2255c',
    image: '/images/products/hertzoggie.jpg',
  },
  {
    match: /romaney\s+creams?|^romaney$/i,
    shape: 'sandwich',
    bg: '#d9d3f0',
    tone: '#6b3e28',
    dot: '#f2d3a4',
    image: '/images/products/romaney-creams.jpg',
  },
  {
    match: /^butter\s+mix$/i,
    shape: 'round',
    bg: '#fbe3a1',
    tone: '#f0be6a',
    dot: '#b9772f',
    image: '/images/products/butter-mix.jpg',
  },
  {
    match: /^normal\s+mix$/i,
    shape: 'round',
    bg: '#cfe6d6',
    tone: '#d9a25e',
    dot: '#8b5a2b',
    image: '/images/products/normal-mix.jpg',
  },
  { match: /pie/i, shape: 'pie', bg: '#fbe3a1', tone: '#e9b563', dot: '#8a5a22' },
  { match: /samoos/i, shape: 'samoosa', bg: '#cfe6d6', tone: '#e7b873', dot: '#b9772f' },
  { match: /spring\s*roll/i, shape: 'samoosa', bg: '#fbe3a1', tone: '#e7b873', dot: '#8a5a22' },
  { match: /^subs?$/i, shape: 'sandwich', bg: '#cfe6d6', tone: '#f0be6a', dot: '#8b5a2b' },
  { match: /pizza/i, shape: 'pie', bg: '#f7c9d4', tone: '#e9b563', dot: '#c2255c' },
  { match: /hertzog/i, shape: 'sandwich', bg: '#f7c9d4', tone: '#f2d4a0', dot: '#c2255c', image: '/images/products/hertzoggie.jpg' },
  { match: /romaney|cream/i, shape: 'sandwich', bg: '#d9d3f0', tone: '#6b3e28', dot: '#f2d3a4', image: '/images/products/romaney-creams.jpg' },
  { match: /choc/i, shape: 'round', bg: '#f7c9d4', tone: '#6b3e28', dot: '#f2d3a4' },
  { match: /butter/i, shape: 'round', bg: '#fbe3a1', tone: '#f0be6a', dot: '#b9772f', image: '/images/products/butter-mix.jpg' },
  { match: /normal/i, shape: 'round', bg: '#cfe6d6', tone: '#d9a25e', dot: '#8b5a2b', image: '/images/products/normal-mix.jpg' },
]

export function productArt(product, index = 0) {
  const hit = BY_NAME.find((entry) => entry.match.test(product?.name || ''))
  if (hit) {
    const { match, ...art } = hit
    return art
  }
  return { shape: 'round', ...PALETTE[index % PALETTE.length] }
}
