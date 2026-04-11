<script setup>
defineProps({
  title: String,
  value: [String, Number],
  trend: Number,
  icon: [Object, Function, String],
  color: String,
  total: [String, Number]
})
</script>

<template>
  <div class="card stat-card">
    <div class="stat-header">
      <div class="icon-wrapper" :style="{ backgroundColor: color + '20', color: color }">
        <component :is="icon" :size="20" />
      </div>
      <div v-if="trend !== undefined" :class="['trend', trend >= 0 ? 'trend-up' : 'trend-down']">
        {{ trend >= 0 ? '+' : '' }}{{ trend }}%
      </div>
    </div>
    <div class="stat-body">
      <p class="stat-title">{{ title }}</p>
      <h2 class="stat-value">{{ value }}<span v-if="total" class="stat-total">/{{ total }}</span></h2>
      <a href="#" class="view-all">{{ $t('dashboard.viewAll') }}</a>
    </div>
  </div>
</template>

<style scoped>
.stat-card {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
}

.stat-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.icon-wrapper {
  width: 40px;
  height: 40px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.trend {
  font-size: 0.8rem;
  font-weight: 600;
}

.trend-up { color: var(--success); }
.trend-down { color: var(--danger); }

.stat-title {
  font-size: 0.85rem;
  color: var(--gray);
  margin-bottom: 0.25rem;
}

.stat-value {
  font-size: 1.5rem;
  margin-bottom: 0.5rem;
}

.stat-total {
  font-size: 1rem;
  color: var(--gray);
  font-weight: 400;
}

.view-all {
  font-size: 0.75rem;
  color: var(--primary);
  font-weight: 600;
}
</style>
