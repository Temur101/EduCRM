<template>
  <div class="container">
    <h1>{{ $route.name }}</h1>
    <p class="text-muted">{{ $t('placeholder.underDevelopment') }}</p>
    <div class="card" style="margin-top: 2rem; height: 300px; display: flex; align-items: center; justify-content: center; border: 2px dashed var(--border);">
      <p>{{ $t('placeholder.contentWillAppear', { name: $route.name }) }}</p>
    </div>
  </div>
</template>
