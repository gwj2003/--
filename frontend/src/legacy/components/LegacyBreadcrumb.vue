<script setup>
const props = defineProps({
  page: {
    type: String,
    required: true,
    validator: (value) => ['privacy', 'terms'].includes(value),
  },
})

const pageConfig = {
  privacy: {
    title: '隐私说明',
  },
  terms: {
    title: '服务条款',
  },
}
</script>

<template>
  <header id="header" class="ex-header">
    <div class="container">
      <div class="row">
        <div class="col-md-12">
          <h1>{{ pageConfig[page].title }}</h1>
        </div>
      </div>
    </div>
  </header>

  <div class="ex-basic-1">
    <div class="container">
      <div class="row">
        <div class="col-lg-12">
          <div class="breadcrumbs">
            <a href="index.html">首页</a><i class="fa fa-angle-double-right"></i>
            <span>{{ pageConfig[page].title }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
