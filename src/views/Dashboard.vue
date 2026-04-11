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
  DollarSign,
  GraduationCap,
  LayoutGrid,
  BookOpen,
  DoorOpen
} from 'lucide-vue-next';
import { ref, onMounted } from 'vue';
import { supabase } from '../supabase.js';
import StatCard from '../components/StatCard.vue';

const leadsCount = ref(0);
const tasksCount = ref(0);
const paymentsTotal = ref(0);
const todayTasksCount = ref(0);
const studentsCount = ref(0);
const groupsCount = ref(0);
const teachersCount = ref(0);
const coursesCount = ref(0);
const roomsCount = ref(0);
const isLoading = ref(true);
const userRole = ref(localStorage.getItem('userRole') || 'regular');

const recentLeads = ref([]);
const recentPayments = ref([]);

const loadDashboardData = async () => {
  isLoading.value = true;
  try {
    const userRole = localStorage.getItem('userRole');
    const teacherId = localStorage.getItem('userTeacherId');

    // 1. Fetch total leads (Admins only, teachers see 0)
    if (userRole === 'admin') {
      const { count: leadCountData, error: leadErr } = await supabase
        .from('leads')
        .select('*', { count: 'exact', head: true });
      if (!leadErr) leadsCount.value = leadCountData || 0;
    }

    // 2. Fetch total tasks (Teachers see 0 for now)
    if (userRole === 'admin') {
      const { count: taskCountData, error: taskErr } = await supabase
        .from('tasks')
        .select('*', { count: 'exact', head: true });
      if (!taskErr) tasksCount.value = taskCountData || 0;
    }

    // 3. Fetch total payments (Admins only)
    if (userRole === 'admin') {
      const { data: paymentsData, error: payErr } = await supabase
        .from('payments')
        .select('amount');
      if (!payErr && paymentsData) {
        paymentsTotal.value = paymentsData.reduce((sum, p) => sum + (parseFloat(p.amount) || 0), 0);
      }
    }

    // 4. Fetch Today's Tasks
    if (userRole === 'admin') {
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
    }

    // 5. Fetch Recent Leads for the list
    if (userRole === 'admin') {
      const { data: recentL, error: rlErr } = await supabase
        .from('leads')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(5);
      if (!rlErr) recentLeads.value = recentL || [];
    }

    // 6. Fetch Recent Payments
    if (userRole === 'admin') {
      const { data: recentP, error: rpErr } = await supabase
        .from('payments')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(5);
      if (!rpErr) recentPayments.value = recentP || [];
    }
    
    // 7. Additional school data
    let studentsQuery = supabase.from('students').select('*', { count: 'exact', head: true });
    let groupsQuery = supabase.from('groups').select('*', { count: 'exact', head: true });
    
    if (userRole === 'teacher' && teacherId) {
        // Teacher sees only their own counts
        groupsQuery = groupsQuery.eq('teacher_id', teacherId);
        
        // Count students in teacher's groups
        const { data: tGroups } = await supabase.from('groups').select('id').eq('teacher_id', teacherId);
        const tGroupIds = tGroups?.map(g => g.id) || [];
        if (tGroupIds.length > 0) {
            studentsQuery = studentsQuery.in('group_id', tGroupIds);
        } else {
            studentsCount.value = 0;
            studentsQuery = null;
        }
    }

    if (studentsQuery) {
        const { count: sCount } = await studentsQuery;
        studentsCount.value = sCount || 0;
    }
    
    const { count: gCount } = await groupsQuery;
    groupsCount.value = gCount || 0;

    if (userRole === 'admin') {
        const { count: tchCount } = await supabase.from('teachers').select('*', { count: 'exact', head: true });
        teachersCount.value = tchCount || 0;

        const { count: crsCount } = await supabase.from('courses').select('*', { count: 'exact', head: true });
        coursesCount.value = crsCount || 0;

        const { count: rmCount } = await supabase.from('rooms').select('*', { count: 'exact', head: true });
        roomsCount.value = rmCount || 0;
    }

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
        <h1 class="page-title">{{ $t('dashboard.title') }}</h1>
        <p class="breadcrumb">{{ $t('dashboard.subtitle') }}</p>
      </div>
      <div class="header-right">
        <div class="date-badge">
          <Calendar :size="16" />
          {{ new Date().toLocaleDateString($i18n.locale === 'en' ? 'en-US' : ($i18n.locale === 'ru' ? 'ru-RU' : 'uz-UZ'), { month: 'long', day: 'numeric', year: 'numeric' }) }}
        </div>
      </div>
    </div>

    <!-- Stats Summary Row (Only for admins) -->
    <div class="stats-grid" v-if="userRole === 'admin'">
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
          :title="$t('dashboard.activeLeads')" 
          :value="leadsCount" 
          :icon="Users" 
          color="#7366FF"
          :trend="12.5"
        />
        <StatCard 
          :title="$t('dashboard.tasks')" 
          :value="tasksCount" 
          :icon="CheckSquare" 
          color="#FF9F43"
          :trend="8.1"
        />
        <StatCard 
          :title="$t('dashboard.revenue')" 
          :value="formatCurrency(paymentsTotal)" 
          :icon="CreditCard" 
          color="#28C76F"
          :trend="15.2"
        />
        <StatCard 
          :title="$t('dashboard.todayTasks')" 
          :value="todayTasksCount" 
          :icon="Zap" 
          color="#EA5455"
          :trend="todayTasksCount > 0 ? 100 : 0"
        />
      </template>
    </div>

    <!-- School General Overview -->
    <div class="row-header">
      <h2 class="section-title">{{ userRole === 'teacher' ? ($t('dashboard.myStats') || 'Mening statistikam') : $t('dashboard.schoolOverview') }}</h2>
    </div>
    
    <div class="stats-grid overview-stats">
      <template v-if="isLoading">
        <div v-for="i in 5" :key="i" class="card stat-card skeleton-card small">
          <div class="skeleton" style="width: 32px; height: 32px; border-radius: 8px; margin-bottom: 0.75rem;"></div>
          <div class="skeleton" style="width: 50%; height: 12px; margin-bottom: 0.5rem;"></div>
          <div class="skeleton" style="width: 30%; height: 18px;"></div>
        </div>
      </template>
      <template v-else>
        <StatCard 
          :title="$t('dashboard.totalStudents')" 
          :value="studentsCount" 
          :icon="GraduationCap" 
          color="#00CFE8"
        />
        <StatCard 
          :title="$t('dashboard.totalGroups')" 
          :value="groupsCount" 
          :icon="LayoutGrid" 
          color="#7366FF"
        />
        <StatCard 
          v-if="userRole === 'admin'"
          :title="$t('dashboard.totalTeachers')" 
          :value="teachersCount" 
          :icon="Users" 
          color="#FF9F43"
        />
        <StatCard 
          v-if="userRole === 'admin'"
          :title="$t('dashboard.totalCourses')" 
          :value="coursesCount" 
          :icon="BookOpen" 
          color="#28C76F"
        />
        <StatCard 
          v-if="userRole === 'admin'"
          :title="$t('dashboard.totalRooms')" 
          :value="roomsCount" 
          :icon="DoorOpen" 
          color="#EA5455"
        />
      </template>
    </div>

    <div class="dashboard-content-grid" v-if="userRole === 'admin'">
      <!-- Left Column: Recent Activity -->
      <div class="content-left">
        <div class="card recent-leads-card">
          <div class="card-header">
            <div class="header-title">
                <Target :size="20" class="icon-primary" />
                <h3>{{ $t('dashboard.recentLeads') }}</h3>
            </div>
            <router-link to="/leads" class="view-all">{{ $t('dashboard.viewAll') }} <ChevronRight :size="14" /></router-link>
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
                  <span class="lead-status" :class="lead.priority.toLowerCase()">{{ $t('leads.' + lead.priority.toLowerCase()) }}</span>
                </div>
                <div v-if="recentLeads.length === 0" class="no-data">{{ $t('leads.noItems') || 'No leads found.' }}</div>
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
                    <h3>{{ $t('dashboard.recentTransactions') }}</h3>
                </div>
                <router-link to="/payments" class="view-all">{{ $t('dashboard.viewAll') }} <ChevronRight :size="14" /></router-link>
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
                    <div v-if="recentPayments.length === 0" class="no-data">{{ $t('common.noData') }}</div>
                </template>
            </div>
        </div>

        <!-- Productivity Summary Card -->
        <div class="card productivity-card">
            <div class="card-header">
                <div class="header-title">
                    <Clock :size="20" class="icon-warning" />
                    <h3>{{ $t('dashboard.productivity') }}</h3>
                </div>
            </div>
            <div class="productivity-content">
                <div class="prod-stat">
                    <span>{{ $t('dashboard.taskCompletion') }}</span>
                    <div class="progress-bar">
                        <div class="progress" style="width: 75%;"></div>
                    </div>
                </div>
                <div class="prod-stat">
                    <span>{{ $t('dashboard.leadConversion') }}</span>
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
  margin-bottom: 2rem;
}

.overview-stats {
  grid-template-columns: repeat(5, 1fr);
  margin-bottom: 2.5rem;
}

.row-header {
  margin-bottom: 1.25rem;
}

.section-title {
  font-size: 1.25rem;
  font-weight: 800;
  color: var(--dark);
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
    .stats-grid { grid-template-columns: repeat(3, 1fr); }
    .overview-stats { grid-template-columns: repeat(3, 1fr); }
}

@media (max-width: 1000px) {
    .dashboard-header { flex-direction: column; align-items: flex-start; gap: 1rem; }
    .dashboard-content-grid { grid-template-columns: 1fr; }
    .overview-stats { grid-template-columns: repeat(2, 1fr); }
}

@media (max-width: 600px) {
    .stats-grid { grid-template-columns: 1fr; }
    .overview-stats { grid-template-columns: 1fr; }
}
</style>
