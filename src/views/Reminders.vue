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
    <div class="counters">
      <div class="counter-card" :class="{ active: activeFilter === 'pending' }" @click="setFilter('pending')">
        <div class="cc-icon" style="background:#FEF3C7;color:#D97706"><Clock :size="22" /></div>
        <div class="cc-info">
          <span class="cc-num">{{ pendingCount }}</span>
          <span class="cc-label">{{ $t('reminders.pending') }}</span>
        </div>
      </div>
      <div class="counter-card" :class="{ active: activeFilter === 'overdue' }" @click="setFilter('overdue')">
        <div class="cc-icon" style="background:#FEE2E2;color:#DC2626"><AlertTriangle :size="22" /></div>
        <div class="cc-info">
          <span class="cc-num" style="color:#DC2626">{{ overdueCount }}</span>
          <span class="cc-label">{{ $t('reminders.overdue') }}</span>
        </div>
      </div>
      <div class="counter-card" :class="{ active: activeFilter === 'all' }" @click="setFilter('all')">
        <div class="cc-icon" style="background:#EEF2FF;color:#4F46E5"><ListChecks :size="22" /></div>
        <div class="cc-info">
          <span class="cc-num">{{ reminders.length }}</span>
          <span class="cc-label">{{ $t('reminders.total') }}</span>
        </div>
      </div>
    </div>

    <!-- Table Card -->
    <div class="table-card card">
      <div class="table-toolbar">
        <div class="search-box">
          <Search :size="17" />
          <input v-model="searchQuery" :placeholder="$t('reminders.searchPlaceholder')" @input="currentPage = 1" />
        </div>
        <span class="results-count">{{ filteredReminders.length }} {{ $t('reminders.results') }}</span>
      </div>

      <div class="table-scroll">
        <table>
          <thead>
            <tr>
              <th>{{ $t('reminders.student') }}</th>
              <th>{{ $t('reminders.group') }}</th>
              <th>{{ $t('students.month') }}</th>
              <th>{{ $t('reminders.amount') }}</th>
              <th>{{ $t('reminders.promisedDate') }}</th>
              <th>{{ $t('reminders.status') }}</th>
              <th>{{ $t('reminders.notes') }}</th>
              <th style="text-align:right">{{ $t('common.actions') }}</th>
            </tr>
          </thead>
          <tbody>
            <!-- Skeleton -->
            <template v-if="isLoading">
              <tr v-for="i in 6" :key="i">
                <td :data-label="$t('reminders.student')"><div class="skeleton" style="width:160px;height:16px"></div></td>
                <td :data-label="$t('reminders.group')"><div class="skeleton" style="width:100px;height:16px"></div></td>
                <td :data-label="$t('students.month')"><div class="skeleton" style="width:80px;height:16px"></div></td>
                <td :data-label="$t('reminders.amount')"><div class="skeleton" style="width:90px;height:16px"></div></td>
                <td :data-label="$t('reminders.promisedDate')"><div class="skeleton" style="width:100px;height:16px"></div></td>
                <td :data-label="$t('reminders.status')"><div class="skeleton" style="width:80px;height:24px;border-radius:8px"></div></td>
                <td :data-label="$t('reminders.notes')"><div class="skeleton" style="width:130px;height:16px"></div></td>
                <td :data-label="$t('common.actions') || 'Actions'"></td>
              </tr>
            </template>

            <!-- Empty -->
            <tr v-else-if="paginatedReminders.length === 0">
              <td colspan="7" class="empty-state">
                <BellRing :size="44" style="opacity:.3" />
                <p>{{ $t('reminders.noRecords') }}</p>
              </td>
            </tr>

            <!-- Rows -->
            <template v-else>
              <tr
                v-for="item in paginatedReminders"
                :key="item.id"
                :class="{ 'row-overdue': computedStatus(item) === 'overdue' }"
              >
                <!-- Student -->
                <td :data-label="$t('reminders.student')">
                  <div class="student-cell">
                    <img :src="avatarUrl(item.students?.name)" class="mini-avatar" :alt="item.students?.name" />
                    <div>
                      <div class="student-name">{{ item.students?.name || '—' }}</div>
                      <div v-if="item.students?.phone" class="student-phone">{{ item.students.phone }}</div>
                    </div>
                  </div>
                </td>
                <!-- Group -->
                <td :data-label="$t('reminders.group')">
                  <div class="group-cell">
                    <Users :size="13" style="color:#94A3B8;flex-shrink:0" />
                    {{ item.students?.groups?.name || $t('reminders.noGroup') }}
                  </div>
                </td>
                <!-- Month -->
                <td :data-label="$t('students.month')">
                   <span class="month-text">{{ getDisplayMonth(item) }}</span>
                </td>
                <!-- Amount -->
                <td :data-label="$t('reminders.amount')">
                  <span class="amount-text">{{ formatCurrency(item.amount) }}</span>
                </td>
                <!-- Date -->
                <td :data-label="$t('reminders.promisedDate')">
                  <div class="date-cell" :class="{ 'date-danger': computedStatus(item) === 'overdue' }">
                    <CalendarClock :size="14" style="flex-shrink:0" />
                    {{ formatDate(item.promised_date) }}
                  </div>
                </td>
                <!-- Status badge — computed from date -->
                <td :data-label="$t('reminders.status')">
                  <span :class="['status-badge', statusClass(item)]">
                    {{ statusLabel(item) }}
                  </span>
                </td>
                <!-- Notes -->
                <td :data-label="$t('reminders.notes')">
                  <span class="notes-text">
                    {{ (item.notes || '').replace(/\[M:[^\]]+\]/g, '').replace(/\[DAYS:[^\]]+\]/g, '').trim() || '' }}
                  </span>
                </td>
                <!-- Actions -->
                <td :data-label="$t('common.actions') || 'Actions'">
                  <div class="actions-cell">
                    <button
                      v-if="computedStatus(item) !== 'paid'"
                      class="btn-mark-paid"
                      :disabled="isMarkingPaid === item.id"
                      @click="markPaid(item)"
                      :title="$t('reminders.markPaid')"
                    >
                      <Loader2 v-if="isMarkingPaid === item.id" :size="15" class="spin" />
                      <CheckCircle v-else :size="15" />
                    </button>

                    <button
                       v-if="userRole === 'admin'"
                       class="btn-delete-quick"
                       @click="confirmDelete(item.id)"
                       :title="$t('common.delete')"
                     >
                       <Trash2 :size="15" />
                     </button>
                  </div>
                </td>
              </tr>
            </template>
          </tbody>
        </table>
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

/* Counter cards */
.counters {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1.25rem;
  margin-bottom: 1.75rem;
}
@media (max-width: 900px) { .counters { grid-template-columns: repeat(2, 1fr); } }

.counter-card {
  background: white;
  border: 1.5px solid var(--border);
  border-radius: 18px;
  padding: 1.25rem 1.5rem;
  display: flex;
  align-items: center;
  gap: 1rem;
  cursor: pointer;
  transition: all 0.2s;
  box-shadow: 0 2px 8px rgba(0,0,0,0.04);
}
.counter-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 8px 24px rgba(0,0,0,0.08);
}
.counter-card.active {
  border-color: var(--primary);
  box-shadow: 0 0 0 3px rgba(127,119,221,0.12), 0 8px 24px rgba(0,0,0,0.06);
}

.cc-icon {
  width: 48px;
  height: 48px;
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.cc-info { display: flex; flex-direction: column; }
.cc-num {
  font-size: 1.75rem;
  font-weight: 800;
  color: var(--dark);
  line-height: 1;
}
.cc-label {
  font-size: 0.78rem;
  font-weight: 700;
  color: var(--gray);
  margin-top: 4px;
  text-transform: uppercase;
  letter-spacing: 0.4px;
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
  min-width: 280px;
  color: var(--gray);
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

.table-scroll { overflow-x: auto; }

table { width: 100%; border-collapse: collapse; }
th {
  text-align: left;
  padding: 0.9rem 1.25rem;
  background: #FAFAFA;
  font-size: 0.78rem;
  font-weight: 800;
  color: var(--gray);
  text-transform: uppercase;
  letter-spacing: 0.5px;
  border-bottom: 1px solid var(--border);
  white-space: nowrap;
}
td {
  padding: 1.1rem 1.25rem;
  border-bottom: 1px solid #F8FAFC;
  vertical-align: middle;
}
tr:last-child td { border-bottom: none; }

.row-overdue { background: #FFFBFB; }

/* Student cell */
.student-cell {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}
.mini-avatar {
  width: 38px;
  height: 38px;
  border-radius: 50%;
  object-fit: cover;
  flex-shrink: 0;
  border: 2px solid white;
  box-shadow: 0 2px 8px rgba(0,0,0,0.05);
}
.student-name {
  font-size: 0.9rem;
  font-weight: 700;
  color: var(--dark);
}
.student-phone {
  font-size: 0.78rem;
  color: var(--gray);
  margin-top: 2px;
}

.month-text {
  background: #EEF2FF;
  color: #4F46E5;
  padding: 0.4rem 0.8rem;
  border-radius: 10px;
  font-size: 0.78rem;
  font-weight: 800;
  border: 1.5px solid #E0E7FF;
  display: inline-flex;
  align-items: center;
  white-space: nowrap;
}

/* Group */
.group-cell {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 0.85rem;
  font-weight: 600;
  color: #475569;
}

/* Amount */
.amount-text {
  font-weight: 800;
  font-size: 0.9rem;
  color: var(--dark);
}

/* Date */
.date-cell {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 0.85rem;
  font-weight: 600;
  color: #475569;
  white-space: nowrap;
}
.date-danger { color: #DC2626 !important; }

/* Status badges — 3 colors only */
.status-badge {
  padding: 5px 12px;
  border-radius: 8px;
  font-size: 0.72rem;
  font-weight: 800;
  white-space: nowrap;
  display: inline-block;
}
.badge-green  { background: #DCFCE7; color: #166534; }
.badge-yellow { background: #FEF9C3; color: #854D0E; }
.badge-red    { background: #FEE2E2; color: #991B1B; }

/* Notes */
.notes-cell {
  font-size: 0.83rem;
  color: var(--gray);
  max-width: 200px;
  display: inline-block;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  vertical-align: middle;
}

/* Actions */
.actions-cell {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 6px;
}
.btn-mark-paid {
  width: 34px; height: 34px;
  border-radius: 10px;
  background: #DCFCE7;
  color: #16A34A;
  border: none;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer;
  transition: all 0.2s;
  flex-shrink: 0;
}
.btn-mark-paid:hover { background: #ECFDF5; color: #10B981; }

.btn-delete-quick {
  width: 32px; height: 32px; border-radius: 8px;
  display: flex; align-items: center; justify-content: center;
  color: #EF4444; background: transparent; transition: all 0.2s;
}
.btn-delete-quick:hover { background: #FEF2F2; color: #DC2626; }

.btn-mark-paid:disabled { opacity: 0.5; cursor: not-allowed; }

.dropdown-wrap { position: relative; }
.btn-more {
  width: 34px; height: 34px;
  display: flex; align-items: center; justify-content: center;
  border-radius: 8px; border: none;
  background: transparent; color: var(--gray);
  cursor: pointer; transition: all 0.2s;
}
.btn-more:hover { background: var(--light); color: var(--dark); }

.dropdown-menu {
  position: absolute;
  top: calc(100% + 6px);
  right: 0;
  background: white;
  border: 1.5px solid var(--border);
  border-radius: 14px;
  padding: 0.4rem;
  min-width: 210px;
  z-index: 200;
  box-shadow: 0 10px 40px rgba(0,0,0,0.1);
}
.dd-item {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 0.7rem;
  padding: 0.65rem 0.9rem;
  font-size: 0.85rem;
  font-weight: 600;
  border-radius: 10px;
  border: none;
  background: transparent;
  cursor: pointer;
  color: var(--dark);
  text-align: left;
  transition: all 0.15s;
}
.dd-item:hover { background: var(--light); color: var(--primary); }
.dd-item.danger { color: #EF4444; }
.dd-item.danger:hover { background: #FEE2E2; }
.dd-divider { height: 1px; background: var(--border); margin: 4px; }

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
