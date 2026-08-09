import { defineStore } from 'pinia'
import { ref } from 'vue'

let toastId = 0

export const useToastStore = defineStore('toast', () => {
  const toasts = ref([])

  function push(message, type = 'info', duration = 3200) {
    const id = ++toastId
    toasts.value.push({ id, message, type })
    if (duration > 0) {
      window.setTimeout(() => dismiss(id), duration)
    }
    return id
  }

  function success(message, duration) {
    return push(message, 'success', duration)
  }

  function error(message, duration = 4200) {
    return push(message, 'error', duration)
  }

  function info(message, duration) {
    return push(message, 'info', duration)
  }

  function dismiss(id) {
    toasts.value = toasts.value.filter((t) => t.id !== id)
  }

  return {
    toasts,
    push,
    success,
    error,
    info,
    dismiss,
  }
})
