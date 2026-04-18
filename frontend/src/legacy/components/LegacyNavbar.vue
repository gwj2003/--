<template>
  <nav class="navbar navbar-expand-md navbar-dark navbar-custom fixed-top">
    <a class="navbar-brand logo-image" href="index.html"><img src="/images/logo.svg" alt="alternative" /></a>

    <button
      class="navbar-toggler"
      type="button"
      data-toggle="collapse"
      data-target="#navbarsExampleDefault"
      aria-controls="navbarsExampleDefault"
      aria-expanded="false"
      aria-label="切换导航"
    >
      <span class="navbar-toggler-awesome fas fa-bars"></span>
      <span class="navbar-toggler-awesome fas fa-times"></span>
    </button>

    <div class="collapse navbar-collapse" id="navbarsExampleDefault">
      <ul class="navbar-nav ml-auto">
        <li class="nav-item">
          <a class="nav-link page-scroll" href="index.html#header">首页 <span class="sr-only">(当前)</span></a>
        </li>
        <li class="nav-item">
          <a class="nav-link page-scroll" href="index.html#intro">平台简介</a>
        </li>
        <li class="nav-item">
          <a class="nav-link page-scroll" href="index.html#services">核心功能</a>
        </li>
        <li class="nav-item">
          <a class="nav-link page-scroll" href="index.html#callMe">预约咨询</a>
        </li>
        <li class="nav-item">
          <a class="nav-link page-scroll" href="index.html#projects">应用案例</a>
        </li>

        <li class="nav-item dropdown">
          <a class="nav-link dropdown-toggle page-scroll" href="index.html#about" id="navbarDropdown" role="button" aria-haspopup="true" aria-expanded="false">关于平台</a>
          <div class="dropdown-menu" aria-labelledby="navbarDropdown">
            <a class="dropdown-item" href="terms-conditions.html"><span class="item-text">服务条款</span></a>
            <div class="dropdown-items-divide-hr"></div>
            <a class="dropdown-item" href="privacy-policy.html"><span class="item-text">隐私说明</span></a>
          </div>
        </li>

        <li class="nav-item">
          <a class="nav-link page-scroll" href="index.html#contact">联系我们</a>
        </li>
      </ul>

      <span class="nav-item social-icons">
        <span class="fa-stack">
          <a href="#your-link">
            <span class="hexagon"></span>
            <i class="fab fa-facebook-f fa-stack-1x"></i>
          </a>
        </span>
        <span class="fa-stack">
          <a href="#your-link">
            <span class="hexagon"></span>
            <i class="fab fa-twitter fa-stack-1x"></i>
          </a>
        </span>
      </span>
    </div>
  </nav>
</template>
