import { ref, computed } from 'vue'

const theme = ref('light')
let initialized = false

function apply(next) {
  theme.value = next === 'dark' ? 'dark' : 'light'
  document.documentElement.classList.toggle('dark', theme.value === 'dark')
  document.documentElement.style.colorScheme = theme.value
  try {
    localStorage.setItem('theme', theme.value)
  } catch {
    /* ignore */
  }
}

export function useTheme() {
  if (!initialized && typeof document !== 'undefined') {
    initialized = true
    let saved = null
    try {
      saved = localStorage.getItem('theme')
    } catch {
      saved = null
    }
    apply(saved === 'dark' ? 'dark' : 'light')
  }

  const isDark = computed(() => theme.value === 'dark')

  function toggleTheme() {
    apply(theme.value === 'dark' ? 'light' : 'dark')
  }

  return {
    theme,
    isDark,
    toggleTheme,
    setTheme: apply,
  }
}
