export const PRODUCT_CATEGORIES = [
  { value: 'biscuits', label: 'Biscuits' },
  { value: 'other', label: 'Pies & samoosas' },
]

export function groupProducts(products) {
  return PRODUCT_CATEGORIES.map((category) => ({
    key: category.value,
    label: category.label,
    items: products.filter(
      (p) => (p.category || 'biscuits') === category.value
    ),
  })).filter((group) => group.items.length)
}
