import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase'

export const useUsersStore = defineStore('users', () => {
  const users = ref([])
  const loading = ref(false)
  const error = ref(null)

  async function fetchUsers() {
    loading.value = true
    error.value = null
    const { data, error: err } = await supabase
      .from('users')
      .select('*')
      .order('name')
    loading.value = false
    if (err) {
      error.value = err.message
      throw err
    }
    users.value = data ?? []
    return users.value
  }

  return { users, loading, error, fetchUsers }
})
