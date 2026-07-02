<script setup lang="ts">
const props = defineProps<{ to: string }>();
const base = import.meta.env.BASE_URL;
const href = base + props.to.replace(/^\//, "");
</script>
<template>
  <a :href="href"><slot /></a>
</template>
