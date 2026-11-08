<script setup>
defineProps({
  art: {
    type: Object,
    required: true,
  },
  alt: {
    type: String,
    default: '',
  },
})
</script>

<template>
  <img
    v-if="art.image"
    class="product-art-photo"
    :src="art.image"
    :alt="alt"
    loading="lazy"
    decoding="async"
  />
  <svg v-else viewBox="0 0 200 200" aria-hidden="true">
    <template v-if="art.shape === 'sandwich'">
      <circle cx="92" cy="112" r="72" :fill="art.tone" />
      <circle cx="100" cy="104" r="68" :fill="art.dot" />
      <circle cx="108" cy="96" r="62" :fill="art.tone" />
      <circle cx="108" cy="96" r="22" :fill="art.dot" />
      <circle
        cx="108"
        cy="96"
        r="50"
        fill="none"
        :stroke="art.dot"
        stroke-opacity="0.35"
        stroke-width="3"
        stroke-dasharray="2 9"
        stroke-linecap="round"
      />
    </template>

    <template v-else-if="art.shape === 'pie'">
      <ellipse cx="100" cy="120" rx="84" ry="44" :fill="art.dot" />
      <path
        d="M22 112 Q100 20 178 112 Q100 150 22 112 Z"
        :fill="art.tone"
      />
      <path
        d="M22 112 Q100 150 178 112"
        fill="none"
        :stroke="art.dot"
        stroke-width="10"
        stroke-linecap="round"
        stroke-dasharray="1 16"
      />
      <path
        d="M70 86 L84 74 M100 80 L114 68 M130 86 L144 74"
        :stroke="art.dot"
        stroke-width="6"
        stroke-linecap="round"
      />
    </template>

    <template v-else-if="art.shape === 'samoosa'">
      <path
        d="M100 26 L178 162 Q180 170 172 170 L28 170 Q20 170 22 162 Z"
        :fill="art.tone"
        stroke-linejoin="round"
      />
      <path
        d="M100 26 L100 170 M60 98 L140 98"
        fill="none"
        :stroke="art.dot"
        stroke-opacity="0.45"
        stroke-width="4"
        stroke-dasharray="2 10"
        stroke-linecap="round"
      />
      <path
        d="M28 170 L172 170"
        :stroke="art.dot"
        stroke-width="8"
        stroke-linecap="round"
      />
    </template>

    <template v-else>
      <circle cx="100" cy="100" r="84" :fill="art.tone" />
      <circle
        cx="100"
        cy="100"
        r="70"
        fill="none"
        :stroke="art.dot"
        stroke-opacity="0.35"
        stroke-width="3"
        stroke-dasharray="2 9"
        stroke-linecap="round"
      />
      <circle cx="70" cy="76" r="9" :fill="art.dot" />
      <circle cx="118" cy="66" r="8" :fill="art.dot" />
      <circle cx="136" cy="108" r="9" :fill="art.dot" />
      <circle cx="94" cy="124" r="8" :fill="art.dot" />
      <circle cx="62" cy="116" r="7" :fill="art.dot" />
      <circle cx="108" cy="92" r="6" :fill="art.dot" />
      <circle cx="124" cy="140" r="6" :fill="art.dot" />
    </template>
  </svg>
</template>

<style scoped>
.product-art-photo {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: cover;
  object-position: center;
}
</style>
