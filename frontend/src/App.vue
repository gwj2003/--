<script setup>
import { RouterView } from 'vue-router'
</script>

<template>
  <RouterView />
</template>

<style>
/* 确保最外层容器占满全屏，没有多余边距 */
#app {
  width: 100%;
  min-height: 100vh;
  margin: 0;
  padding: 0;
}
</style>