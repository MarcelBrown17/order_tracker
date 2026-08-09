<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter, useRoute, RouterLink } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useTheme } from '../composables/useTheme'
import { useToast } from '../composables/useToast'

const auth = useAuthStore()
const router = useRouter()
const route = useRoute()
const { theme, setTheme } = useTheme()
const toast = useToast()

const email = ref('')
const password = ref('')
const loading = ref(false)
let previousTheme = 'light'

onMounted(() => {
  previousTheme = theme.value
  setTheme('light', { persist: false })
})

onUnmounted(() => {
  setTheme(previousTheme, { persist: false })
})

async function onSubmit() {
  loading.value = true
  try {
    await auth.login(email.value.trim(), password.value)
    toast.success('Signed in')
    const redirect = route.query.redirect
    router.push(redirect ? String(redirect) : { name: 'new-order' })
  } catch (e) {
    toast.error(e.message || 'Login failed')
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="login-page">
    <div class="login-shell">
      <div class="login-topbar">
        <RouterLink to="/" class="login-brand">
          <span class="login-brand__dot" aria-hidden="true" />Biscuits
        </RouterLink>
        <RouterLink to="/" class="login-back">Order biscuits</RouterLink>
      </div>

      <div class="login-hero">
        <h1>Welcome<br />back</h1>
        <p>Sign in to manage orders, products, and partners.</p>
      </div>

      <form class="login-card" @submit.prevent="onSubmit">
        <p class="login-eyebrow">Sign in</p>

        <div class="login-field">
          <label for="email">
            Email <span class="login-req" aria-hidden="true">*</span>
          </label>
          <input
            id="email"
            v-model="email"
            type="email"
            required
            autocomplete="email"
            placeholder="you@example.com"
          />
        </div>

        <div class="login-field login-field--last">
          <label for="password">
            Password <span class="login-req" aria-hidden="true">*</span>
          </label>
          <input
            id="password"
            v-model="password"
            type="password"
            required
            autocomplete="current-password"
            placeholder="Your password"
          />
        </div>

        <button type="submit" class="login-send" :disabled="loading">
          {{ loading ? 'Signing in…' : 'Sign in' }}
          <span v-if="!loading" aria-hidden="true">→</span>
        </button>

        <p class="login-footnote">
          Want biscuits?
          <RouterLink :to="{ name: 'request-biscuits' }">Request an order</RouterLink>
        </p>
      </form>
    </div>
  </div>
</template>

<style scoped>
.login-page {
  --lq-blush: #f2c6b4;
  --lq-blush-soft: #f7d9c8;
  --lq-terracotta: #d97d54;
  --lq-terracotta-dark: #c2673f;
  --lq-cream: #fff8f0;
  --lq-sage: #8b9a7a;
  --lq-sage-dark: #71806a;
  --lq-espresso: #3b2a20;
  --lq-espresso-soft: #6b564a;
  --lq-card: #ffffff;
  --lq-line: #ecdfd5;
  --lq-field: #fefcf9;
  --lq-radius-lg: 1.5rem;
  --lq-radius-sm: 0.625rem;

  position: relative;
  overflow: hidden;
  min-height: 100dvh;
  background: linear-gradient(135deg, var(--lq-blush) 0%, var(--lq-blush-soft) 100%);
  color: var(--lq-espresso);
}

.login-page::after {
  content: '';
  position: absolute;
  top: -1.875rem;
  right: -1.875rem;
  width: 8.75rem;
  height: 8.75rem;
  border-radius: 50%;
  background: color-mix(in srgb, var(--lq-terracotta) 18%, transparent);
  pointer-events: none;
}

.login-shell {
  position: relative;
  z-index: 1;
  width: min(25rem, 100%);
  margin: 0 auto;
  padding: 1.25rem 1.25rem 2.5rem;
}

.login-topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
}

.login-brand {
  margin: 0;
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  font-family: 'Fraunces', var(--font-sans);
  font-size: 1.375rem;
  font-weight: 700;
  letter-spacing: -0.02em;
  color: var(--lq-terracotta-dark);
  text-decoration: none;
}

.login-brand__dot {
  width: 0.5rem;
  height: 0.5rem;
  border-radius: 50%;
  background: var(--lq-sage);
}

.login-back {
  display: inline-flex;
  height: 2.375rem;
  align-items: center;
  padding: 0 1rem;
  border: 1px solid color-mix(in srgb, #fff 80%, transparent);
  border-radius: 0.75rem;
  background: color-mix(in srgb, #fff 60%, transparent);
  color: var(--lq-espresso);
  font-size: 0.8125rem;
  font-weight: 700;
  text-decoration: none;
}

.login-hero {
  margin-top: 1.6rem;
  margin-bottom: 1.25rem;
}

.login-hero h1 {
  margin: 0 0 0.625rem;
  font-family: 'Fraunces', var(--font-sans);
  font-size: clamp(1.85rem, 7vw, 1.875rem);
  font-weight: 600;
  line-height: 1.08;
  letter-spacing: -0.02em;
  color: var(--lq-espresso);
}

.login-hero p {
  margin: 0;
  max-width: 18rem;
  color: var(--lq-espresso-soft);
  font-size: 0.875rem;
  line-height: 1.5;
  font-weight: 500;
}

.login-card {
  padding: 1.25rem 1.125rem 1.375rem;
  border: 1px solid color-mix(in srgb, #fff 70%, var(--lq-line));
  border-radius: var(--lq-radius-lg);
  background: var(--lq-card);
  box-shadow: 0 18px 40px -18px rgba(59, 42, 32, 0.28);
}

.login-eyebrow {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin: 0 0 1rem;
  color: var(--lq-sage-dark);
  font-size: 0.6875rem;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.login-eyebrow::before {
  content: '';
  width: 0.875rem;
  height: 2px;
  border-radius: 2px;
  background: var(--lq-terracotta);
}

.login-field {
  margin-bottom: 1rem;
}

.login-field--last {
  margin-bottom: 1.15rem;
}

.login-field label {
  display: block;
  margin-bottom: 0.45rem;
  color: var(--lq-espresso);
  font-size: 0.8125rem;
  font-weight: 700;
}

.login-req {
  color: var(--lq-terracotta);
}

.login-field input {
  width: 100%;
  border: 1.5px solid var(--lq-line);
  border-radius: var(--lq-radius-sm);
  background: var(--lq-field);
  color: var(--lq-espresso);
  font: inherit;
  font-size: 0.875rem;
  padding: 0.75rem 0.875rem;
  outline: none;
  transition:
    border-color 0.15s ease,
    box-shadow 0.15s ease;
}

.login-field input::placeholder {
  color: #c9baae;
}

.login-field input:focus {
  border-color: var(--lq-terracotta);
  box-shadow: 0 0 0 4px color-mix(in srgb, var(--lq-terracotta) 14%, transparent);
}

.login-send {
  display: inline-flex;
  width: 100%;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  border: none;
  border-radius: 0.875rem;
  padding: 0.875rem 1.5rem;
  background: var(--lq-terracotta);
  color: #fff;
  font: inherit;
  font-size: 0.90625rem;
  font-weight: 800;
  box-shadow: 0 10px 20px -8px color-mix(in srgb, var(--lq-terracotta) 55%, transparent);
  cursor: pointer;
}

.login-send:hover:not(:disabled) {
  background: var(--lq-terracotta-dark);
}

.login-send:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.login-footnote {
  margin: 1rem 0 0;
  text-align: center;
  color: var(--lq-espresso-soft);
  font-size: 0.875rem;
}

.login-footnote a {
  color: var(--lq-terracotta);
  font-weight: 800;
  text-decoration: none;
}
</style>
