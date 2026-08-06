import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '../lib/supabase'

export const useAuthStore = defineStore('auth', () => {
  const user = ref(null)
  const partner = ref(null)
  const loading = ref(true)

  const isAuthenticated = computed(() => !!user.value)
  const isAdmin = computed(() => !!partner.value?.is_admin)
  const isLinked = computed(() => !!partner.value)

  async function loadPartner(authUser = user.value) {
    if (!authUser) {
      partner.value = null
      return null
    }

    const { data: byAuth, error: byAuthErr } = await supabase
      .from('users')
      .select('*')
      .eq('auth_user_id', authUser.id)
      .maybeSingle()

    if (byAuthErr) throw byAuthErr

    if (byAuth) {
      partner.value = byAuth
      return byAuth
    }

    // First login: match by email and claim the partner row
    if (authUser.email) {
      const email = authUser.email.toLowerCase()
      const { data: byEmail, error: byEmailErr } = await supabase
        .from('users')
        .select('*')
        .ilike('email', email)
        .is('auth_user_id', null)
        .maybeSingle()

      if (byEmailErr) throw byEmailErr

      if (byEmail) {
        const { data: linked, error: linkErr } = await supabase
          .from('users')
          .update({ auth_user_id: authUser.id })
          .eq('id', byEmail.id)
          .select()
          .single()

        if (linkErr) throw linkErr
        partner.value = linked
        return linked
      }
    }

    partner.value = null
    return null
  }

  async function init() {
    loading.value = true
    const {
      data: { session },
    } = await supabase.auth.getSession()
    user.value = session?.user ?? null
    if (user.value) {
      try {
        await loadPartner(user.value)
      } catch (e) {
        console.error(e)
        partner.value = null
      }
    } else {
      partner.value = null
    }

    supabase.auth.onAuthStateChange(async (_event, session) => {
      user.value = session?.user ?? null
      if (user.value) {
        try {
          await loadPartner(user.value)
        } catch (e) {
          console.error(e)
          partner.value = null
        }
      } else {
        partner.value = null
      }
    })
    loading.value = false
  }

  async function login(email, password) {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    })
    if (error) throw error
    user.value = data.user
    await loadPartner(data.user)
    return data
  }

  async function logout() {
    const { error } = await supabase.auth.signOut()
    if (error) throw error
    user.value = null
    partner.value = null
  }

  return {
    user,
    partner,
    loading,
    isAuthenticated,
    isAdmin,
    isLinked,
    init,
    login,
    logout,
    loadPartner,
  }
})
