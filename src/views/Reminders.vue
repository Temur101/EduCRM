<script setup>
import {
  Search,
  MoreVertical,
  BellRing,
  CheckCircle,
  XCircle,
  CalendarClock,
  Trash2,
  X,
  Loader2,
  Edit,
  ChevronLeft,
  ChevronRight,
  AlertTriangle,
  CreditCard,
  Users,
  Clock,
  Handshake,
  ListChecks
} from 'lucide-vue-next';
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { supabase } from '../supabase.js';

const { t } = useI18n();
const userRole = ref(localStorage.getItem('userRole') || 'regular');

const reminders = ref([]);
const isLoading = ref(true);
const isMarkingPaid = ref(null);
const deletingId = ref(null);
const searchQuery = ref('');
const currentPage = ref(1);
const itemsPerPage = 10;

// ── Date helpers ────────────────────────────────────────────────
const today = () => {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
};

const daysDiff = (dateStr) => {
  if (!dateStr) return null;
  const pd = new Date(dateStr);
  return Math.ceil((pd - today()) / (1000 * 60 * 60 * 24));
};

// Auto status derived from date (do not store)
const computedStatus = (item) => {
  if (item.status === 'Paid') return 'paid';
  if (item.status === 'Cancelled') return 'cancelled';
  const diff = daysDiff(item.promised_date);
  if (diff === null) return 'pending';
  if (diff < 0) return 'overdue';
  if (diff <= 7) return 'soon';
  return 'pending';
};

const statusLabel = (item) => {
  const s = computedStatus(item);
  const diff = daysDiff(item.promised_date);
  if (s === 'paid')      return t('reminders.statusPaid');
  if (s === 'cancelled') return t('common.cancel');
  if (diff === null)     return t('reminders.pending');
  if (diff < 0)          return t('reminders.overdueDays', { n: Math.abs(diff) });
  if (diff === 0)        return t('reminders.todayLabel');
  if (diff <= 7)         return t('reminders.remainingDays', { n: diff });
  return t('reminders.days', { n: diff });
};

const statusClass = (item) => {
  const s = computedStatus(item);
  return {
    paid:      'badge-green',
    cancelled: 'badge-yellow',
    overdue:   'badge-red',
    soon:      'badge-yellow',
    pending:   'badge-green',
  }[s] || 'badge-green';
};

// ── Load ─────────────────────────────────────────────────────────
const loadData = async () => {
  isLoading.value = true;
  try {
    const { data, error } = await supabase
      .from('payment_reminders')
      .select(`
        *,
        students (
          id,
          name,
          phone,
          groups (id, name)
        )
      `)
      .order('promised_date', { ascending: true });
    if (error) throw error;
    reminders.value = data || [];
  } catch (e) {
    console.error('Error loading reminders:', e.message);
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  document.addEventListener('click', () => { activeDropdown.value = null; });
  loadData();
});

// ── Counters ─────────────────────────────────────────────────────
const pendingCount = computed(() =>
  reminders.value.filter(r => computedStatus(r) === 'pending' || computedStatus(r) === 'soon').length
);
const overdueCount = computed(() =>
  reminders.value.filter(r => computedStatus(r) === 'overdue').length
);
const paidCount = computed(() =>
  reminders.value.filter(r => r.status === 'Paid').length
);

// ── Filters & Pagination ─────────────────────────────────────────
const activeFilter = ref('all'); // all | pending | overdue | paid

const filteredReminders = computed(() => {
  let list = reminders.value;
  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase();
    list = list.filter(r =>
      r.students?.name?.toLowerCase().includes(q) ||
      r.students?.groups?.name?.toLowerCase().includes(q) ||
      r.notes?.toLowerCase().includes(q)
    );
  }
  if (activeFilter.value === 'pending')
    list = list.filter(r => computedStatus(r) === 'pending' || computedStatus(r) === 'soon');
  if (activeFilter.value === 'overdue')
    list = list.filter(r => computedStatus(r) === 'overdue');
  if (activeFilter.value === 'paid')
    list = list.filter(r => r.status === 'Paid');
  return list;
});

const totalPages = computed(() => Math.ceil(filteredReminders.value.length / itemsPerPage));
const paginatedReminders = computed(() => {
  const start = (currentPage.value - 1) * itemsPerPage;
  return filteredReminders.value.slice(start, start + itemsPerPage);
});
const setPage = (p) => {
  if (p >= 1 && p <= totalPages.value) currentPage.value = p;
};

const setFilter = (f) => {
  activeFilter.value = f;
  currentPage.value = 1;
};

// ── Dropdown ─────────────────────────────────────────────────────
const activeDropdown = ref(null);
const toggleDropdown = (id, e) => {
  e.stopPropagation();
  activeDropdown.value = activeDropdown.value === id ? null : id;
};

// ── Actions ───────────────────────────────────────────────────────
const markPaid = async (item) => {
  isMarkingPaid.value = item.id;
  try {
    // 1. Create a payment record
    const { error: payError } = await supabase.from('payments').insert([{
      student: (item.students?.name || '—').trim(),
      student_id: item.student_id,
      course: item.students?.groups?.name || '—',
      amount: item.amount,
      method: 'Cash',
      date: new Date().toISOString().slice(0, 10),
      status: 'Success',
      receipt_id: 'PAY-' + Math.floor(Math.random() * 90000 + 10000),
      comment: (item.notes || '').trim(),
      month: getDisplayMonth(item),
      id: crypto.randomUUID()
    }]);
    if (payError) throw payError;

    // 2. Delete reminder
    const { error: remError } = await supabase
      .from('payment_reminders')
      .delete()
      .eq('id', item.id);
    if (remError) throw remError;

    // Remove from local list
    reminders.value = reminders.value.filter(r => r.id !== item.id);
  } catch (e) {
    console.error('Error marking as paid:', e);
  } finally {
    isMarkingPaid.value = null;
  }
};

const revertPending = async (item) => {
  const { error } = await supabase
    .from('payment_reminders')
    .update({ status: 'Pending' })
    .eq('id', item.id);
  if (!error) { item.status = 'Pending'; activeDropdown.value = null; }
};

const cancelItem = async (item) => {
  const { error } = await supabase
    .from('payment_reminders')
    .update({ status: 'Cancelled' })
    .eq('id', item.id);
  if (!error) { item.status = 'Cancelled'; activeDropdown.value = null; }
};

// Delete
const showDeleteConfirm = ref(false);
const itemToDelete = ref(null);
const confirmDelete = (id) => {
  itemToDelete.value = id;
  showDeleteConfirm.value = true;
  activeDropdown.value = null;
};
const deleteItem = async () => {
  if (!itemToDelete.value || deletingId.value) return;
  deletingId.value = itemToDelete.value;
  try {
    const { error } = await supabase.from('payment_reminders').delete().eq('id', deletingId.value);
    if (error) throw error;
    reminders.value = reminders.value.filter(r => r.id !== deletingId.value);
    showDeleteConfirm.value = false;
  } catch (e) {
    console.error(e);
  } finally {
    deletingId.value = null;
    itemToDelete.value = null;
  }
};

// ── Formatting ────────────────────────────────────────────────────
const formatDate = (dateStr) => {
  if (!dateStr) return '—';
  const d = new Date(dateStr);
  return d.toLocaleDateString('ru-RU', { day: 'numeric', month: 'long' });
};

// (MONTH_NAMES was here, removed)

const getDisplayMonth = (item) => {
  // 1. Try explicit column
  if (item.month) return item.month;
  
  // 2. Try tag in notes [M:...]
  if (item.notes && item.notes.includes('[M:')) {
    const match = item.notes.match(/\[M:([^\]]+)\]/);
    if (match && match[1]) return match[1];
  }
  
  // 3. Fallback to promised date
  if (!item.promised_date) return '—';
  const d = new Date(item.promised_date);
  const locale = localStorage.getItem('userLanguage') === 'uz' ? 'uz-UZ' : 'ru-RU';
  return d.toLocaleDateString(locale, { month: 'long', year: 'numeric' });
};
const formatCurrency = (val) => {
  if (!val && val !== 0) return '—';
  return Number(val).toLocaleString() + ' UZS';
};
const avatarUrl = (name) =>
  `https://ui-avatars.com/api/?name=${encodeURIComponent(name || '?')}&background=7366FF&color=fff&size=64&bold=true`;
</script>

<template>
  <div class="reminders-page">
    <!-- Header -->
    <div class="page-header">
      <div class="header-info">
        <h1><Handshake :size="26" style="vertical-align:-5px;margin-right:8px;color:#7C3AED" />{{ $t('reminders.title') }}</h1>
        <p>{{ $t('reminders.subtitle') }}</p>
      </div>
    </div>

    <!-- Counter Cards -->
    <div class="stats-grid">
      <div class="stat-card" :class="{ active: activeFilter === 'pending' }" @click="setFilter('pending')">
        <div class="stat-icon" style="background: rgba(255,159,67,0.1); color: var(--warning);">
          <Clock :size="24" />
        </div>
        <div class="stat-info">
          <span class="stat-label">{{ $t('reminders.pending') }}</span>
          <h2 class="stat-value">{{ pendingCount }}</h2>
          <span class="stat-subtext">Активные обещания</span>
        </div>
      </div>
      <div class="stat-card" :class="{ active: activeFilter === 'overdue' }" @click="setFilter('overdue')">
        <div class="stat-icon" style="background: rgba(234,84,85,0.1); color: var(--danger);">
          <AlertTriangle :size="24" />
        </div>
        <div class="stat-info">
          <span class="stat-label">{{ $t('reminders.overdue') }}</span>
          <h2 class="stat-value" style="color: var(--danger);">{{ overdueCount }}</h2>
          <span class="stat-subtext">Требует внимания</span>
        </div>
      </div>
      <div class="stat-card" :class="{ active: activeFilter === 'all' }" @click="setFilter('all')">
        <div class="stat-icon" style="background: rgba(115,102,255,0.1); color: var(--primary);">
          <ListChecks :size="24" />
        </div>
        <div class="stat-info">
          <span class="stat-label">{{ $t('reminders.total') }}</span>
          <h2 class="stat-value">{{ reminders.length }}</h2>
          <span class="stat-subtext">Всего записей</span>
        </div>
      </div>
    </div>

    <!-- Reminders Card -->  
    <div class="table-card card">
      <div class="table-toolbar">
        <div class="search-box">
          <Search :size="17" />
          <input v-model="searchQuery" :placeholder="$t('reminders.searchPlaceholder')" @input="currentPage = 1" />
        </div>
        <span class="results-count">{{ filteredReminders.length }} {{ $t('reminders.results') }}</span>
      </div>

      <!-- Skeleton -->
      <div v-if="isLoading" class="rem-card-grid">
        <div v-for="i in 6" :key="i" class="rem-card rem-skeleton-card">
          <div class="rem-card-top">
            <div class="skeleton" style="width:44px;height:44px;border-radius:50%;flex-shrink:0"></div>
            <div style="flex:1">
              <div class="skeleton" style="width:60%;height:15px;margin-bottom:6px"></div>
              <div class="skeleton" style="width:40%;height:12px"></div>
            </div>
          </div>
          <div class="rem-card-body">
            <div class="skeleton" style="width:80px;height:22px;border-radius:8px"></div>
            <div class="skeleton" style="width:110px;height:15px"></div>
            <div class="skeleton" style="width:90px;height:15px"></div>
          </div>
        </div>
      </div>

      <!-- Empty -->
      <div v-else-if="paginatedReminders.length === 0" class="empty-state">
        <BellRing :size="44" style="opacity:.3" />
        <p>{{ $t('reminders.noRecords') }}</p>
      </div>

      <!-- Cards Grid -->
      <div v-else class="rem-card-grid">
        <div
          v-for="item in paginatedReminders"
          :key="item.id"
          class="rem-card"
          :class="{ 'rem-card-overdue': computedStatus(item) === 'overdue' }"
        >
          <!-- Top: avatar + name + status -->
          <div class="rem-card-top">
            <img :src="avatarUrl(item.students?.name)" class="rem-avatar" :alt="item.students?.name" />
            <div class="rem-student-info">
              <div class="rem-student-name">{{ item.students?.name || '—' }}</div>
              <div v-if="item.students?.phone" class="rem-student-phone">{{ item.students.phone }}</div>
            </div>
            <span :class="['rem-status-badge', statusClass(item)]">{{ statusLabel(item) }}</span>
          </div>

          <!-- Body: details grid -->
          <div class="rem-card-body">
            <!-- Group -->
            <div class="rem-detail">
              <span class="rem-detail-label">{{ $t('reminders.group') }}</span>
              <span class="rem-detail-val">
                <Users :size="13" style="vertical-align:-2px;margin-right:3px;color:#94A3B8" />
                {{ item.students?.groups?.name || $t('reminders.noGroup') }}
              </span>
            </div>
            <!-- Month -->
            <div class="rem-detail">
              <span class="rem-detail-label">{{ $t('students.month') }}</span>
              <span class="month-text">{{ getDisplayMonth(item) }}</span>
            </div>
            <!-- Amount -->
            <div class="rem-detail">
              <span class="rem-detail-label">{{ $t('reminders.amount') }}</span>
              <span class="rem-amount">{{ formatCurrency(item.amount) }}</span>
            </div>
            <!-- Promised date -->
            <div class="rem-detail">
              <span class="rem-detail-label">{{ $t('reminders.promisedDate') }}</span>
              <span class="date-cell" :class="{ 'date-danger': computedStatus(item) === 'overdue' }">
                <CalendarClock :size="13" style="flex-shrink:0" />
                {{ formatDate(item.promised_date) }}
              </span>
            </div>
            <!-- Notes -->
            <div class="rem-detail rem-detail-full" v-if="(item.notes || '').replace(/\[M:[^\]]+\]/g, '').replace(/\[DAYS:[^\]]+\]/g, '').trim()">
              <span class="rem-detail-label">{{ $t('reminders.notes') }}</span>
              <span class="rem-notes">
                {{ (item.notes || '').replace(/\[M:[^\]]+\]/g, '').replace(/\[DAYS:[^\]]+\]/g, '').trim() }}
              </span>
            </div>
          </div>

          <!-- Footer: actions -->
          <div class="rem-card-footer">
            <button
              v-if="computedStatus(item) !== 'paid'"
              class="btn-mark-paid rem-btn-paid"
              :disabled="isMarkingPaid === item.id"
              @click="markPaid(item)"
            >
              <Loader2 v-if="isMarkingPaid === item.id" :size="15" class="spin" />
              <CheckCircle v-else :size="15" />
              {{ $t('reminders.markPaid') }}
            </button>
            <div v-if="computedStatus(item) === 'paid'" class="rem-paid-label">
              <CheckCircle :size="15" /> {{ $t('reminders.markPaid') }}
            </div>
            <button
              v-if="userRole === 'admin'"
              class="btn-delete-quick"
              @click="confirmDelete(item.id)"
              :title="$t('common.delete')"
            >
              <Trash2 :size="15" />
            </button>
          </div>
        </div>
      </div>

      <!-- Pagination -->
      <div v-if="totalPages > 1" class="pagination">
        <span class="page-info">
          {{ (currentPage - 1) * itemsPerPage + 1 }}–{{ Math.min(currentPage * itemsPerPage, filteredReminders.length) }}
          / {{ filteredReminders.length }}
        </span>
        <div class="page-controls">
          <button class="btn-pg" :disabled="currentPage === 1" @click="setPage(currentPage - 1)">
            <ChevronLeft :size="18" />
          </button>
          <button
            v-for="p in totalPages"
            :key="p"
            class="btn-pg"
            :class="{ 'pg-active': currentPage === p }"
            @click="setPage(p)"
          >{{ p }}</button>
          <button class="btn-pg" :disabled="currentPage === totalPages" @click="setPage(currentPage + 1)">
            <ChevronRight :size="18" />
          </button>
        </div>
      </div>
    </div>

    <!-- Delete Confirm Modal -->
    <transition name="modal">
      <div v-if="showDeleteConfirm" class="modal-overlay" @click.self="showDeleteConfirm = false">
        <div class="confirm-box">
          <div class="confirm-icon-wrap">
            <AlertTriangle :size="40" style="color:#EF4444" />
          </div>
          <h3>Ishonchingiz komilmi?</h3>
          <p>Bu va'da to'lov yozuvi butunlay o'chiriladi.</p>
          <div class="confirm-btns">
            <button class="btn-cancel" @click="showDeleteConfirm = false">Bekor qilish</button>
            <button class="btn-delete" @click="deleteItem" :disabled="!!deletingId">
              <Loader2 v-if="deletingId" :size="16" class="spin" />
              <span v-else>O'chirish</span>
            </button>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<style scoped>
.reminders-page {
  padding: 2rem;
  background: var(--light);
  min-height: 100vh;
  overflow-x: hidden;
}

@media (max-width: 767px) {
  .reminders-page { padding: 1rem; }
}

/* Header */
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 1.75rem;
}
.header-info h1 {
  font-size: 1.8rem;
  font-weight: 800;
  color: var(--dark);
  margin-bottom: 4px;
}
.header-info p {
  color: var(--gray);
  font-size: 0.95rem;
}

/* Stats Cards */
.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 1.25rem;
  margin-bottom: 2rem;
}

@media (max-width: 767px) {
  .stats-grid {
    grid-template-columns: 1fr;
  }
}

.stat-card {
  background: white;
  padding: 1.5rem;
  border-radius: 20px;
  box-shadow: var(--shadow);
  display: flex;
  align-items: center;
  gap: 1.25rem;
  cursor: pointer;
  border: 2px solid transparent;
  transition: all 0.2s;
}

.stat-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 8px 24px rgba(0,0,0,0.08);
}

.stat-card.active {
  border-color: var(--primary);
  background: var(--light);
}

.stat-icon {
  width: 56px;
  height: 56px;
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.stat-info {
  display: flex;
  flex-direction: column;
}

.stat-label {
  font-size: 0.85rem;
  color: var(--gray);
  font-weight: 600;
}

.stat-value {
  font-size: clamp(1.2rem, 2vw, 1.5rem);
  font-weight: 800;
  color: var(--dark);
  margin: 0.25rem 0;
  white-space: nowrap;
  line-height: 1.2;
}

.stat-subtext {
  font-size: 0.75rem;
  color: var(--gray);
}

/* Table Card */
.table-card {
  background: white;
  border-radius: 20px;
  border: 1px solid var(--border);
  box-shadow: 0 4px 16px rgba(0,0,0,0.04);
  overflow: hidden;
}

.table-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1.25rem 1.5rem;
  border-bottom: 1px solid var(--border);
}
.search-box {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  background: var(--light);
  padding: 0.55rem 1rem;
  border-radius: 12px;
  min-width: 0;
  flex: 1;
  max-width: 320px;
  color: var(--gray);
}
@media (max-width: 767px) {
  .search-box { max-width: 100%; }
  .table-toolbar { flex-direction: column; align-items: stretch; gap: 0.75rem; }
  .results-count { text-align: right; }
}
.search-box input {
  background: transparent;
  border: none;
  outline: none;
  font-size: 0.9rem;
  width: 100%;
  font-family: inherit;
}
.results-count {
  font-size: 0.85rem;
  font-weight: 600;
  color: var(--gray);
}

/* Reminders Grid */
.table-card {
  background: white;
  border-radius: 20px;
  border: 1px solid var(--border);
  box-shadow: 0 4px 16px rgba(0,0,0,0.04);
}
.table-toolbar {
  padding: 1.25rem;
  border-bottom: 1px solid var(--border);
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.rem-card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1.25rem;
  padding: 1.25rem;
  background: #F8FAFC;
}
@media (max-width: 767px) {
  .rem-card-grid {
    grid-template-columns: 1fr;
    padding: 1rem;
  }
}

.rem-card {
  background: white;
  border: 1px solid var(--border);
  border-radius: 16px;
  display: flex;
  flex-direction: column;
  transition: all 0.2s;
  overflow: hidden;
}
.rem-card:hover {
  box-shadow: 0 10px 25px rgba(0,0,0,0.05);
  border-color: var(--primary);
}
.rem-card-overdue {
  border-color: #FCA5A5;
  background: #FEF2F2 !important;
}

/* Card Top */
.rem-card-top {
  padding: 1.25rem;
  border-bottom: 1px solid var(--border);
  display: flex;
  align-items: center;
  gap: 0.85rem;
}
.rem-card-overdue .rem-card-top {
  border-bottom-color: #FECACA;
}
.rem-avatar {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  object-fit: cover;
}
.rem-student-info { flex: 1; min-width: 0; }
.rem-student-name {
  font-size: 1rem;
  font-weight: 800;
  color: var(--dark);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.rem-student-phone {
  font-size: 0.8rem;
  color: var(--gray);
  margin-top: 2px;
}
.rem-status-badge {
  padding: 4px 10px;
  border-radius: 8px;
  font-size: 0.75rem;
  font-weight: 800;
  white-space: nowrap;
}

/* Card Body */
.rem-card-body {
  padding: 1.25rem;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
}
.rem-detail {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
}
.rem-detail-full { grid-column: 1 / -1; }
.rem-detail-label {
  font-size: 0.72rem;
  font-weight: 700;
  color: var(--gray);
  text-transform: uppercase;
}
.rem-detail-val {
  font-size: 0.88rem;
  font-weight: 600;
  color: var(--dark);
  display: flex;
  align-items: center;
}
.month-text {
  font-size: 0.8rem;
  font-weight: 800;
  color: #4F46E5;
  background: #EEF2FF;
  padding: 3px 8px;
  border-radius: 6px;
  display: inline-block;
  width: fit-content;
}
.rem-amount {
  font-size: 1rem;
  font-weight: 800;
  color: var(--dark);
}
.date-cell {
  font-size: 0.85rem;
  font-weight: 600;
  color: var(--dark);
  display: flex;
  align-items: center;
  gap: 5px;
}
.date-danger { color: #DC2626; }

.rem-notes {
  font-size: 0.85rem;
  color: #475569;
  background: var(--light);
  padding: 0.75rem;
  border-radius: 8px;
  line-height: 1.4;
}

/* Card Footer */
.rem-card-footer {
  padding: 1rem 1.25rem;
  background: var(--light);
  border-top: 1px solid var(--border);
  display: flex;
  justify-content: flex-end;
  align-items: center;
  gap: 0.5rem;
}
.rem-card-overdue .rem-card-footer {
  background: #FEE2E2;
  border-top-color: #FECACA;
}
.btn-mark-paid {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 0.6rem 1rem;
  background: #10B981;
  color: white;
  border: none;
  border-radius: 10px;
  font-weight: 700;
  font-size: 0.85rem;
  cursor: pointer;
  transition: all 0.2s;
}
.btn-mark-paid:hover:not(:disabled) { background: #059669; }
.btn-mark-paid:disabled { opacity: 0.6; cursor: not-allowed; }

.rem-paid-label {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 0.85rem;
  font-weight: 700;
  color: #059669;
  padding: 0.6rem 1rem;
}

.btn-delete-quick {
  width: 36px;
  height: 36px;
  border-radius: 10px;
  background: white;
  border: 1px solid #E2E8F0;
  color: #EF4444;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.2s;
}
.btn-delete-quick:hover {
  background: #FEE2E2;
  border-color: #FECACA;
  color: #DC2626;
}

.rem-skeleton-card {
  padding: 0;
  background: white;
}

/* Status colors */
.badge-green  { background: #DCFCE7; color: #166534; border: 1px solid #BBF7D0; }
.badge-yellow { background: #FEF9C3; color: #854D0E; border: 1px solid #FEF08A; }
.badge-red    { background: #FEE2E2; color: #991B1B; border: 1px solid #FECACA; }

/* Pagination */
.pagination {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.25rem 1.5rem;
  border-top: 1px solid var(--border);
}
.page-info { font-size: 0.875rem; color: var(--gray); }
.page-controls { display: flex; gap: 6px; }
.btn-pg {
  width: 34px; height: 34px;
  border-radius: 9px;
  border: 1px solid var(--border);
  background: white;
  font-size: 0.85rem;
  font-weight: 600;
  color: var(--dark);
  cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  transition: all 0.2s;
}
.btn-pg:hover:not(:disabled):not(.pg-active) { border-color: var(--primary); color: var(--primary); }
.btn-pg.pg-active { background: var(--primary); color: white; border-color: var(--primary); }
.btn-pg:disabled { opacity: 0.4; cursor: not-allowed; }

/* Empty state */
.empty-state {
  text-align: center;
  padding: 4rem;
  color: var(--gray);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
}
.empty-state p { font-size: 1rem; font-weight: 600; }

/* Modal */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(15,23,42,0.5);
  backdrop-filter: blur(6px);
  z-index: 1000;
  display: flex; align-items: center; justify-content: center;
  padding: 1rem;
}
.confirm-box {
  background: white;
  border-radius: 24px;
  padding: 2.5rem;
  max-width: 380px;
  width: 100%;
  text-align: center;
  box-shadow: 0 25px 60px rgba(0,0,0,0.2);
  animation: scaleUp 0.25s ease;
}
@keyframes scaleUp {
  from { opacity: 0; transform: scale(0.9); }
  to { opacity: 1; transform: scale(1); }
}
.confirm-icon-wrap { margin-bottom: 1rem; }
.confirm-box h3 {
  font-size: 1.4rem;
  font-weight: 800;
  color: var(--dark);
  margin-bottom: 0.5rem;
}
.confirm-box p {
  color: var(--gray);
  font-size: 0.95rem;
  margin-bottom: 2rem;
}
.confirm-btns {
  display: flex;
  gap: 1rem;
}
.btn-cancel {
  flex: 1;
  padding: 0.8rem;
  border-radius: 12px;
  background: var(--light);
  color: var(--gray);
  font-weight: 700;
  border: none;
  cursor: pointer;
  font-family: inherit;
}
.btn-delete {
  flex: 1;
  padding: 0.8rem;
  border-radius: 12px;
  background: #EF4444;
  color: white;
  font-weight: 700;
  border: none;
  cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  gap: 6px;
  font-family: inherit;
  transition: all 0.2s;
}
.btn-delete:hover:not(:disabled) { background: #DC2626; }
.btn-delete:disabled { opacity: 0.5; cursor: not-allowed; }

/* Utils */
.spin { animation: spin 1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.skeleton {
  background: linear-gradient(90deg,#f0f0f0 25%,#e8e8e8 50%,#f0f0f0 75%);
  background-size: 200% 100%;
  animation: skel 1.5s infinite;
  border-radius: 4px;
}
@keyframes skel {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

.modal-enter-active, .modal-leave-active { transition: opacity 0.25s; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
</style>
