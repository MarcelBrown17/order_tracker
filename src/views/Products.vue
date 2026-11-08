<script setup>
import { ref, computed, onMounted } from 'vue'
import { useProductsStore } from '../stores/products'
import Money from '../components/Money.vue'
import BaseButton from '../components/BaseButton.vue'
import ToggleSwitch from '../components/ToggleSwitch.vue'
import BaseSelect from '../components/BaseSelect.vue'
import AppLoader from '../components/AppLoader.vue'
import { useToast } from '../composables/useToast'
import { PRODUCT_CATEGORIES, groupProducts } from '../lib/productGroups'

const productsStore = useProductsStore()
const toast = useToast()

const loading = ref(true)
const showForm = ref(false)
const editingId = ref(null)
const saving = ref(false)

const blank = () => ({
  name: '',
  category: 'biscuits',
  cost_price: 80,
  sell_price: 140,
  active: true,
})

const form = ref(blank())

const productGroups = computed(() => groupProducts(productsStore.products))

async function load() {
  loading.value = true
  try {
    await productsStore.fetchProducts({ admin: true })
  } catch (e) {
    toast.error(e.message || 'Failed to load products')
  } finally {
    loading.value = false
  }
}

onMounted(load)

function profitMargin(p) {
  return Number(p.sell_price) - Number(p.cost_price)
}

function openCreate() {
  editingId.value = null
  form.value = blank()
  showForm.value = true
}

function openEdit(p) {
  editingId.value = p.id
  form.value = {
    name: p.name,
    category: p.category || 'biscuits',
    cost_price: Number(p.cost_price),
    sell_price: Number(p.sell_price),
    active: p.active,
  }
  showForm.value = true
}

function closeForm() {
  showForm.value = false
  editingId.value = null
  form.value = blank()
}

async function onSubmit() {
  saving.value = true
  try {
    const payload = {
      name: form.value.name.trim(),
      category: form.value.category,
      cost_price: Number(form.value.cost_price),
      sell_price: Number(form.value.sell_price),
      active: form.value.active,
    }
    if (editingId.value) {
      await productsStore.updateProduct(editingId.value, payload)
      toast.success('Product updated')
    } else {
      await productsStore.createProduct(payload)
      toast.success('Product created')
    }
    closeForm()
  } catch (e) {
    toast.error(e.message || 'Failed to save product')
  } finally {
    saving.value = false
  }
}

async function toggleActive(p) {
  try {
    await productsStore.updateProduct(p.id, { active: !p.active })
    toast.success(p.active ? 'Product deactivated' : 'Product activated')
  } catch (e) {
    toast.error(e.message || 'Failed to update product')
  }
}
</script>

<template>
  <div class="bakery-shell bakery-stack">
    <div class="flex items-start justify-between gap-3">
      <div>
        <h1 class="page-title">Products</h1>
        <p class="page-subtitle">Default cost and sell prices</p>
      </div>
      <BaseButton variant="primary" @click="openCreate">Add</BaseButton>
    </div>

    <AppLoader v-if="loading" label="Loading products" />

    <div
      v-if="showForm && !loading"
      class="surface-card space-y-4 p-4"
    >
      <div>
        <button type="button" class="page-back" @click="closeForm">
          <svg
            width="18"
            height="18"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2.25"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <path d="m15 18-6-6 6-6" />
          </svg>
          <span>Products</span>
        </button>
        <h2 class="mt-1 text-base font-bold">
          {{ editingId ? 'Edit product' : 'New product' }}
        </h2>
      </div>
      <form class="space-y-0" @submit.prevent="onSubmit">
        <div class="form-section">
          <div class="form-field">
            <label for="name">Name <span class="req" aria-hidden="true">*</span></label>
            <input id="name" v-model="form.name" required />
          </div>
          <div class="form-field">
            <label for="category">Group <span class="req" aria-hidden="true">*</span></label>
            <BaseSelect
              id="category"
              v-model="form.category"
              :options="PRODUCT_CATEGORIES"
              required
            />
          </div>
        </div>
        <div class="form-section">
          <p class="section-label">Pricing</p>
          <div class="grid grid-cols-2 gap-3">
            <div class="form-field">
              <label for="cost_price">Cost price <span class="req" aria-hidden="true">*</span></label>
              <input
                id="cost_price"
                v-model.number="form.cost_price"
                type="number"
                min="0"
                step="0.01"
                inputmode="decimal"
                required
              />
            </div>
            <div class="form-field">
              <label for="sell_price">Sell price <span class="req" aria-hidden="true">*</span></label>
              <input
                id="sell_price"
                v-model.number="form.sell_price"
                type="number"
                min="0"
                step="0.01"
                inputmode="decimal"
                required
              />
            </div>
          </div>
        </div>
        <div class="form-section">
          <ToggleSwitch
            v-model="form.active"
            label="Active"
            description="Inactive products are hidden on new orders"
          />
        </div>
        <div class="mt-4 flex flex-col gap-2.5 sm:flex-row">
          <BaseButton type="submit" variant="primary" block :disabled="saving">
            {{ saving ? 'Saving…' : 'Save' }}
          </BaseButton>
          <BaseButton type="button" variant="secondary" block @click="closeForm">
            Cancel
          </BaseButton>
        </div>
      </form>
    </div>

    <template v-if="!loading">
      <section
        v-for="group in productGroups"
        :key="group.key"
        class="product-group"
      >
        <p class="product-group__title">{{ group.label }}</p>
        <div class="space-y-2.5 md:hidden">
          <div
            v-for="p in group.items"
            :key="p.id"
            class="list-card list-card--static"
          >
            <div class="flex items-start justify-between gap-2">
              <p class="min-w-0 flex-1 truncate text-base font-bold">{{ p.name }}</p>
              <div class="flex shrink-0 items-center gap-1">
                <ToggleSwitch
                  :model-value="p.active"
                  label="Active"
                  compact
                  @update:model-value="toggleActive(p)"
                />
                <button
                  type="button"
                  class="icon-btn"
                  aria-label="Edit product"
                  @click="openEdit(p)"
                >
                  <svg
                    width="18"
                    height="18"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    aria-hidden="true"
                  >
                    <path d="M12 20h9" />
                    <path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z" />
                  </svg>
                </button>
              </div>
            </div>
            <div class="stat-row">
              <div class="stat-row__item">
                <p class="stat-row__label">Cost</p>
                <p class="stat-row__value"><Money :value="p.cost_price" /></p>
              </div>
              <div class="stat-row__item">
                <p class="stat-row__label">Sell</p>
                <p class="stat-row__value">
                  <Money :value="p.sell_price" tone="owed" />
                </p>
              </div>
              <div class="stat-row__item">
                <p class="stat-row__label">Margin</p>
                <p class="stat-row__value">
                  <Money :value="profitMargin(p)" tone="profit" />
                </p>
              </div>
            </div>
          </div>
        </div>

        <div class="table-wrap hidden md:block">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Cost</th>
                <th>Sell</th>
                <th>Margin</th>
                <th>Active</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="p in group.items"
                :key="p.id"
                class="cursor-default"
                @click.stop
              >
                <td class="font-semibold">{{ p.name }}</td>
                <td><Money :value="p.cost_price" /></td>
                <td><Money :value="p.sell_price" tone="owed" /></td>
                <td><Money :value="profitMargin(p)" tone="profit" /></td>
                <td>
                  <ToggleSwitch
                    :model-value="p.active"
                    label="Active"
                    compact
                    @update:model-value="toggleActive(p)"
                  />
                </td>
                <td>
                  <BaseButton variant="secondary" @click="openEdit(p)">
                    Edit
                  </BaseButton>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
      <p v-if="!productsStore.products.length" class="text-sm text-muted">
        No products yet
      </p>
    </template>
  </div>
</template>
