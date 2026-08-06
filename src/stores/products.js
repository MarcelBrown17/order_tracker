import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase'

export const useProductsStore = defineStore('products', () => {
  const products = ref([])
  const loading = ref(false)
  const error = ref(null)

  async function fetchProducts({ activeOnly = false, admin = false } = {}) {
    loading.value = true
    error.value = null
    // Partners never receive cost_price from the API select
    const columns = admin
      ? '*'
      : 'id, name, sell_price, active, created_at'
    let query = supabase.from('products').select(columns).order('name')
    if (activeOnly) query = query.eq('active', true)
    const { data, error: err } = await query
    loading.value = false
    if (err) {
      error.value = err.message
      throw err
    }
    products.value = data ?? []
    return products.value
  }

  async function createProduct(payload) {
    const { data, error: err } = await supabase
      .from('products')
      .insert(payload)
      .select()
      .single()
    if (err) throw err
    products.value.push(data)
    products.value.sort((a, b) => a.name.localeCompare(b.name))
    return data
  }

  async function updateProduct(id, payload) {
    const { data, error: err } = await supabase
      .from('products')
      .update(payload)
      .eq('id', id)
      .select()
      .single()
    if (err) throw err
    const idx = products.value.findIndex((p) => p.id === id)
    if (idx !== -1) products.value[idx] = data
    return data
  }

  return {
    products,
    loading,
    error,
    fetchProducts,
    createProduct,
    updateProduct,
  }
})
