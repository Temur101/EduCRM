<script setup>
import { 
  Users, 
  CheckSquare, 
  CreditCard, 
  Calendar,
  Plus,
  ArrowUpRight,
  TrendingUp,
  Target,
  Clock,
  Zap,
  ChevronRight,
  DollarSign
} from 'lucide-vue-next';
import { ref, onMounted } from 'vue';
import { supabase } from '../supabase.js';
import StatCard from '../components/StatCard.vue';

const leadsCount = ref(0);
const tasksCount = ref(0);
const paymentsTotal = ref(0);
const todayTasksCount = ref(0);
const isLoading = ref(true);

const recentLeads = ref([]);
const recentPayments = ref([]);

const loadDashboardData = async () => {
  isLoading.value = true;
  try {
    // 1. Fetch total leads
    const { count: leadCountData, error: leadErr } = await supabase
      .from('leads')
      .select('*', { count: 'exact', head: true });
    if (!leadErr) leadsCount.value = leadCountData || 0;

    // 2. Fetch total tasks
    const { count: taskCountData, error: taskErr } = await supabase
      .from('tasks')
      .select('*', { count: 'exact', head: true });
    if (!taskErr) tasksCount.value = taskCountData || 0;

    // 3. Fetch total payments
    const { data: paymentsData, error: payErr } = await supabase
      .from('payments')
      .select('amount');
    if (!payErr && paymentsData) {
      paymentsTotal.value = paymentsData.reduce((sum, p) => sum + (parseFloat(p.amount) || 0), 0);
    }

    // 4. Fetch Today's Tasks
    const { data: todayBoard, error: boardErr } = await supabase
      .from('boards')
      .select('id')
      .eq('title', 'Today task list')
      .maybeSingle();
    
    if (todayBoard) {
      const { count: todayTaskData, error: todayErr } = await supabase
        .from('tasks')
        .select('*', { count: 'exact', head: true })
        .eq('board_id', todayBoard.id);
      if (!todayErr) todayTasksCount.value = todayTaskData || 0;
    }

    // 5. Fetch Recent Leads for the list
    const { data: recentL, error: rlErr } = await supabase
      .from('leads')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(5);
    if (!rlErr) recentLeads.value = recentL || [];

    // 6. Fetch Recent Payments
    const { data: recentP, error: rpErr } = await supabase
      .from('payments')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(5);
    if (!rpErr) recentPayments.value = recentP || [];

  } catch (e) {
    console.error('Error loading dashboard:', e);
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  loadDashboardData();
});

const formatCurrency = (val) => {
  return new Intl.NumberFormat('uz-UZ', { 
    style: 'currency', 
    currency: 'UZS',
    maximumFractionDigits: 0 
  }).format(val);
};

const getInits = (name) => {
  return name ? name.split(' ').map(n => n[0]).join('').toUpperCase() : 'L';
};
</script>

<template>
  <div class="dashboard-view">
    <div class="dashboard-header">
      <div class="header-left">
        <h1 class="page-title">Management Dashboard</h1>
        <p class="breadcrumb">Overview / Performance Insights</p>
      </div>
      <div class="header-right">
        <div class="date-badge">
          <Calendar :size="16" />
          {{ new Date().toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' }) }}
        </div>
      </div>
    </div>

    <!-- Stats Summary Row -->
    <div class="stats-grid">
      <template v-if="isLoading">
        <div v-for="i in 4" :key="i" class="card stat-card skeleton-card">
          <div class="stat-header" style="margin-bottom: 1rem; display: flex; justify-content: space-between;">
            <div class="skeleton" style="width: 40px; height: 40px; border-radius: 10px;"></div>
            <div class="skeleton" style="width: 50px; height: 20px; border-radius: 6px;"></div>
          </div>
          <div class="stat-body">
            <div class="skeleton" style="width: 60%; height: 14px; margin-bottom: 0.5rem;"></div>
            <div class="skeleton" style="width: 40%; height: 24px; margin-bottom: 0.5rem;"></div>
            <div class="skeleton" style="width: 30%; height: 12px;"></div>
          </div>
        </div>
      </template>
      <template v-else>
        <StatCard 
          title="Total Active Leads" 
          :value="leadsCount" 
          :icon="Users" 
          color="#7366FF"
          :trend="12.5"
        />
        <StatCard 
          title="Management Tasks" 
          :value="tasksCount" 
          :icon="CheckSquare" 
          color="#FF9F43"
          :trend="8.1"
        />
        <StatCard 
          title="Total Revenue" 
          :value="formatCurrency(paymentsTotal)" 
          :icon="CreditCard" 
          color="#28C76F"
          :trend="15.2"
        />
        <StatCard 
          title="Items in Today List" 
          :value="todayTasksCount" 
          :icon="Zap" 
          color="#EA5455"
          :trend="todayTasksCount > 0 ? 100 : 0"
        />
      </template>
    </div>

    <div class="dashboard-content-grid">
      <!-- Left Column: Recent Activity -->
      <div class="content-left">
        <div class="card recent-leads-card">
          <div class="card-header">
            <div class="header-title">
                <Target :size="20" class="icon-primary" />
                <h3>Recent Leads</h3>
            </div>
            <router-link to="/leads" class="view-all">View All <ChevronRight :size="14" /></router-link>
          </div>
          <div class="leads-list">
            <div v-if="isLoading" class="skeleton-list">
                <div v-for="i in 5" :key="i" class="skeleton-item-row" style="display: flex; align-items: center; gap: 1rem; padding: 1rem;">
                  <div class="skeleton" style="width: 44px; height: 44px; border-radius: 12px;"></div>
                  <div style="flex: 1;">
                    <div class="skeleton" style="width: 40%; height: 16px; margin-bottom: 0.5rem;"></div>
                    <div class="skeleton" style="width: 25%; height: 12px;"></div>
                  </div>
                  <div class="skeleton" style="width: 60px; height: 24px; border-radius: 8px;"></div>
                </div>
            </div>
            <template v-else>
                <div v-for="lead in recentLeads" :key="lead.id" class="lead-item">
                  <div class="lead-avatar">{{ getInits(lead.name) }}</div>
                  <div class="lead-info">
                    <p class="lead-name">{{ lead.name }}</p>
                    <p class="lead-source">{{ lead.source }}</p>
                  </div>
                  <span class="lead-status" :class="lead.priority.toLowerCase()">{{ lead.priority }}</span>
                </div>
                <div v-if="recentLeads.length === 0" class="no-data">No leads found.</div>
            </template>
          </div>
        </div>
      </div>

      <!-- Right Column: Revenue Stats & Recent Payments -->
      <div class="content-right">
        <div class="card recent-payments-card">
            <div class="card-header">
                <div class="header-title">
                    <TrendingUp :size="20" class="icon-success" />
                    <h3>Recent Transactions</h3>
                </div>
                <router-link to="/payments" class="view-all">View All <ChevronRight :size="14" /></router-link>
            </div>
            <div class="payments-list">
                <div v-if="isLoading" class="skeleton-list">
                    <div v-for="i in 5" :key="i" class="skeleton-item-row" style="display: flex; align-items: center; gap: 0.75rem; padding: 0.9rem;">
                      <div class="skeleton" style="width: 32px; height: 32px; border-radius: 8px;"></div>
                      <div style="flex: 1;">
                        <div class="skeleton" style="width: 50%; height: 14px; margin-bottom: 0.35rem;"></div>
                        <div class="skeleton" style="width: 30%; height: 10px;"></div>
                      </div>
                      <div class="skeleton" style="width: 70px; height: 16px;"></div>
                    </div>
                </div>
                <template v-else>
                    <div v-for="pay in recentPayments" :key="pay.id" class="payment-item">
                        <div class="pay-icon"><DollarSign :size="16" /></div>
                        <div class="pay-info">
                            <p class="pay-student">{{ pay.student_name }}</p>
                            <p class="pay-date">{{ pay.date }}</p>
                        </div>
                        <span class="pay-amount">{{ formatCurrency(pay.amount) }}</span>
                    </div>
                    <div v-if="recentPayments.length === 0" class="no-data">No transactions yet.</div>
                </template>
            </div>
        </div>

        <!-- Productivity Summary Card -->
        <div class="card productivity-card">
            <div class="card-header">
                <div class="header-title">
                    <Clock :size="20" class="icon-warning" />
                    <h3>Daily Productivity</h3>
                </div>
            </div>
            <div class="productivity-content">
                <div class="prod-stat">
                    <span>Task Completion</span>
                    <div class="progress-bar">
                        <div class="progress" style="width: 75%;"></div>
                    </div>
                </div>
                <div class="prod-stat">
                    <span>Lead Conversion</span>
                    <div class="progress-bar">
                        <div class="progress" style="width: 45%; background: var(--info);"></div>
                    </div>
                </div>
            </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.dashboard-view {
  padding: 2.5rem;
  background: #F8F9FA;
  flex: 1;
  overflow-y: auto;
}

.dashboard-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2.5rem;
}

.page-title {
  font-size: 1.75rem;
  font-weight: 800;
  color: var(--dark);
  margin-bottom: 0.5rem;
}

.breadcrumb {
  font-size: 0.9rem;
  color: var(--gray);
  font-weight: 500;
}

.date-badge {
  background: white;
  padding: 0.6rem 1.2rem;
  border-radius: 12px;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  font-weight: 700;
  font-size: 0.9rem;
  color: var(--dark);
  box-shadow: 0 4px 12px rgba(0,0,0,0.03);
  border: 1px solid var(--border);
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 1.5rem;
  margin-bottom: 2.5rem;
}

.dashboard-content-grid {
  display: grid;
  grid-template-columns: 1.2fr 0.8fr;
  gap: 2rem;
}

.card {
  background: white;
  border-radius: 20px;
  padding: 1.5rem;
  box-shadow: 0 10px 30px rgba(0,0,0,0.02);
  border: 1px solid rgba(235, 237, 242, 0.5);
  margin-bottom: 1.5rem;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.5rem;
}

.header-title {
    display: flex;
    align-items: center;
    gap: 0.75rem;
}

.header-title h3 {
    font-size: 1.15rem;
    font-weight: 700;
    color: var(--dark);
}

.view-all {
    font-size: 0.85rem;
    font-weight: 700;
    color: var(--primary);
    display: flex;
    align-items: center;
    gap: 0.25rem;
}

/* Leads List */
.leads-list {
    display: flex;
    flex-direction: column;
    gap: 1rem;
}

.lead-item {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 1rem;
    border-radius: 12px;
    background: #FDFDFD;
    transition: transform 0.2s;
    border: 1px solid transparent;
}

.lead-item:hover {
    transform: translateX(8px);
    border-color: var(--primary-light);
    background: white;
    box-shadow: 0 4px 12px rgba(0,0,0,0.02);
}

.lead-avatar {
    width: 44px;
    height: 44px;
    border-radius: 12px;
    background: var(--primary-light);
    color: var(--primary);
    font-weight: 800;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.9rem;
}

.lead-info {
    flex: 1;
}

.lead-name {
    font-weight: 700;
    font-size: 0.95rem;
    color: var(--dark);
    margin-bottom: 0.25rem;
}

.lead-source {
    font-size: 0.8rem;
    color: var(--gray);
    font-weight: 500;
}

.lead-status {
    font-size: 0.75rem;
    font-weight: 700;
    padding: 0.35rem 0.75rem;
    border-radius: 8px;
    text-transform: capitalize;
}

.hot { background: #FFF1F0; color: var(--danger); }
.warm { background: #FFF8EB; color: var(--warning); }
.cold { background: #E8F9FF; color: var(--info); }

/* Payments List */
.payments-list {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
}

.payment-item {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.9rem;
    background: var(--light);
    border-radius: 12px;
}

.pay-icon {
    width: 32px;
    height: 32px;
    border-radius: 8px;
    background: rgba(40, 199, 111, 0.1);
    color: var(--success);
    display: flex;
    align-items: center;
    justify-content: center;
}

.pay-info {
    flex: 1;
}

.pay-student {
    font-weight: 700;
    font-size: 0.9rem;
    color: var(--dark);
    margin-bottom: 0.15rem;
}

.pay-date {
    font-size: 0.75rem;
    color: var(--gray);
}

.pay-amount {
    font-weight: 800;
    color: var(--success);
    font-size: 0.95rem;
}

/* Productivity Section */
.productivity-content {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
}

.prod-stat {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
}

.prod-stat span {
    font-size: 0.85rem;
    font-weight: 700;
    color: var(--gray);
}

.progress-bar {
    height: 10px;
    background: var(--light);
    border-radius: 5px;
    overflow: hidden;
}

.progress {
    height: 100%;
    background: var(--primary);
    border-radius: 5px;
}

/* Misc */
.icon-primary { color: var(--primary); }
.icon-success { color: var(--success); }
.icon-warning { color: var(--warning); }

.no-data {
    text-align: center;
    padding: 2rem;
    color: var(--gray);
    font-size: 0.9rem;
    font-weight: 500;
}

.skeleton-item {
    height: 60px;
    background: var(--light);
    border-radius: 12px;
    animation: pulse 1.5s infinite;
}

@keyframes pulse {
    0% { opacity: 0.6; }
    50% { opacity: 1; }
    100% { opacity: 0.6; }
}

@media (max-width: 1400px) {
    .stats-grid { grid-template-columns: repeat(2, 1fr); }
}

@media (max-width: 1000px) {
    .dashboard-content-grid { grid-template-columns: 1fr; }
}

@media (max-width: 600px) {
    .stats-grid { grid-template-columns: 1fr; }
}
</style>
