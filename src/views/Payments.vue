<script setup>
import { 
  Plus, 
  Search, 
  Download, 
  Filter, 
  MoreVertical, 
  CreditCard, 
  DollarSign, 
  Clock, 
  CheckCircle2,
  X,
  User,
  Calendar,
  Wallet,
  FileText,
  Trash2,
  Loader2
} from 'lucide-vue-next';
import { ref, reactive, computed, onMounted } from 'vue';
import { supabase } from '../supabase.js';

// --- Sample Data ---
const payments = ref([]);
const isLoading = ref(true);
const isSubmitting = ref(false);
const deletingPaymentId = ref(null);
const activeDropdown = ref(null);
const searchQuery = ref('');
const currentPage = ref(1);
const itemsPerPage = 15;

const startDate = ref('');
const endDate = ref('');

const toggleDropdown = (id, event) => {
  event.stopPropagation();
  activeDropdown.value = activeDropdown.value === id ? null : id;
};

const closeDropdowns = () => {
  activeDropdown.value = null;
};

const loadData = async () => {
  isLoading.value = true;
  try {
    const { data, error } = await supabase
      .from('payments')
      .select('*')
      .order('date', { ascending: false });
    if (error) throw error;
    payments.value = data.map(p => ({
      id: p.id,
      student: p.student,
      course: p.course,
      amount: p.amount,
      method: p.method,
      date: p.date,
      status: p.status,
      receiptId: p.receipt_id,
      comment: p.comment,
      month: p.month
    }));
  } catch (e) {
    console.error('Error loading payments:', e);
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  document.addEventListener('click', closeDropdowns);
  loadData();
});

// --- Filter & Pagination Logic ---
const filteredPayments = computed(() => {
  let result = payments.value;

  // Search Filter
  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase();
    result = result.filter(p => 
      p.student.toLowerCase().includes(q) || 
      p.receiptId.toLowerCase().includes(q)
    );
  }

  // Date Filter
  if (startDate.value) {
    result = result.filter(p => p.date >= startDate.value);
  }
  if (endDate.value) {
    result = result.filter(p => p.date <= endDate.value);
  }

  return result;
});

const totalPages = computed(() => Math.ceil(filteredPayments.value.length / itemsPerPage));

const paginatedPayments = computed(() => {
  const start = (currentPage.value - 1) * itemsPerPage;
  return filteredPayments.value.slice(start, start + itemsPerPage);
});

const pageNumbers = computed(() => {
  const nums = [];
  for (let i = 1; i <= totalPages.value; i++) nums.push(i);
  return nums;
});

const changePage = (page) => {
  if (page >= 1 && page <= totalPages.value) {
    currentPage.value = page;
  }
};

// --- Stats calculation ---
const totalRevenue = computed(() => payments.value.reduce((acc, p) => acc + p.amount, 0));
const successCount = computed(() => payments.value.filter(p => p.status === 'Success').length);
const pendingCount = computed(() => payments.value.filter(p => p.status === 'Pending').length);

// --- State for Add Payment Modal ---
const showModal = ref(false);
const newPayment = reactive({
  student: '',
  course: '',
  amount: '',
  method: 'Cash',
  date: new Date().toISOString().split('T')[0],
  status: 'Success'
});

const openModal = () => {
  newPayment.student = '';
  newPayment.course = '';
  newPayment.amount = '';
  newPayment.method = 'Cash';
  newPayment.date = new Date().toISOString().split('T')[0];
  newPayment.status = 'Success';
  showModal.value = true;
};

const closeModal = () => showModal.value = false;

const addPayment = async () => {
  if (!newPayment.student || !newPayment.amount || isSubmitting.value) return;
  
  isSubmitting.value = true;
  const dbPayment = {
    id: `pay-${Date.now()}`,
    student: newPayment.student,
    course: newPayment.course || 'Other',
    amount: Number(newPayment.amount),
    method: newPayment.method,
    date: newPayment.date,
    status: newPayment.status,
    receipt_id: 'PAY-' + Math.floor(1000 + Math.random() * 9000)
  };

  try {
    const { error } = await supabase.from('payments').insert([dbPayment]);
    if (error) throw error;
    
    payments.value.unshift({
      id: dbPayment.id,
      student: dbPayment.student,
      course: dbPayment.course,
      amount: dbPayment.amount,
      method: dbPayment.method,
      date: dbPayment.date,
      status: dbPayment.status,
      receiptId: dbPayment.receipt_id
    });
    
    closeModal();
  } catch (e) {
    console.error('Error adding payment:', e);
  } finally {
    isSubmitting.value = false;
  }
};

const deletePayment = async (id) => {
  if (deletingPaymentId.value) return;
  deletingPaymentId.value = id;
  try {
    const paymentToArchive = payments.value.find(p => p.id === id);
    if (paymentToArchive) {
      await supabase.from('archives').insert([{
         type: 'payment',
         original_id: id,
         data: paymentToArchive
      }]);
    }
    const { error } = await supabase.from('payments').delete().eq('id', id);
    if (error) throw error;
    payments.value = payments.value.filter(p => p.id !== id);
    activeDropdown.value = null;
  } catch (e) {
    console.error('Error archiving/deleting payment:', e);
  } finally {
    deletingPaymentId.value = null;
  }
};

const formatCurrency = (val) => {
  return new Intl.NumberFormat('uz-UZ', { style: 'currency', currency: 'UZS', maximumFractionDigits: 0 }).format(val);
};

const getStatusClass = (status) => {
  return status === 'Success' ? 'status-success' : 'status-pending';
};

const getMethodIcon = (method) => {
  switch(method.toLowerCase()) {
    case 'cash': return '💵';
    case 'card': return '💳';
    case 'click': return '🎨';
    case 'payme': return '💎';
    default: return '💰';
  }
}
</script>

<template>
  <div class="payments-page">
    <!-- Header Area -->
    <div class="page-header">
      <div class="header-content">
        <h1>{{ $t('payments.title') }}</h1>
        <p>{{ $t('payments.subtitle') }}</p>
      </div>
      <button class="btn-primary" @click="openModal">
        <Plus :size="20" /> 
        {{ $t('payments.addNew') }}
      </button>
    </div>

    <!-- Quick Stats Cards -->
    <div class="stats-grid">
      <!-- Total Revenue Stat -->
      <div class="stat-card">
        <template v-if="isLoading">
          <div class="stat-icon skeleton" style="width: 56px; height: 56px; border-radius: 14px;"></div>
          <div class="stat-info">
            <div class="skeleton" style="width: 80px; height: 14px; margin-bottom: 8px;"></div>
            <div class="skeleton" style="width: 120px; height: 24px; margin-bottom: 8px;"></div>
            <div class="skeleton" style="width: 100px; height: 12px;"></div>
          </div>
        </template>
        <template v-else>
          <div class="stat-icon revenue">
            <DollarSign :size="24" />
          </div>
          <div class="stat-info">
            <span class="stat-label">{{ $t('payments.revenue') }}</span>
            <h2 class="stat-value">{{ formatCurrency(totalRevenue) }}</h2>
            <span class="stat-trend positive">{{ $t('payments.trend') }}</span>
          </div>
        </template>
      </div>

      <!-- Successful Transactions Stat -->
      <div class="stat-card">
        <template v-if="isLoading">
          <div class="stat-icon skeleton" style="width: 56px; height: 56px; border-radius: 14px;"></div>
          <div class="stat-info">
            <div class="skeleton" style="width: 80px; height: 14px; margin-bottom: 8px;"></div>
            <div class="skeleton" style="width: 60px; height: 24px; margin-bottom: 8px;"></div>
            <div class="skeleton" style="width: 100px; height: 12px;"></div>
          </div>
        </template>
        <template v-else>
          <div class="stat-icon success">
            <CheckCircle2 :size="24" />
          </div>
          <div class="stat-info">
            <span class="stat-label">{{ $t('payments.success') }}</span>
            <h2 class="stat-value">{{ successCount }}</h2>
            <span class="stat-subtext">{{ $t('payments.processed') }}</span>
          </div>
        </template>
      </div>

      <!-- Pending Approval Stat -->
      <div class="stat-card">
        <template v-if="isLoading">
          <div class="stat-icon skeleton" style="width: 56px; height: 56px; border-radius: 14px;"></div>
          <div class="stat-info">
            <div class="skeleton" style="width: 80px; height: 14px; margin-bottom: 8px;"></div>
            <div class="skeleton" style="width: 60px; height: 24px; margin-bottom: 8px;"></div>
            <div class="skeleton" style="width: 100px; height: 12px;"></div>
          </div>
        </template>
        <template v-else>
          <div class="stat-icon pending">
            <Clock :size="24" />
          </div>
          <div class="stat-info">
            <span class="stat-label">{{ $t('payments.pending') }}</span>
            <h2 class="stat-value">{{ pendingCount }}</h2>
            <span class="stat-subtext">{{ $t('payments.attention') }}</span>
          </div>
        </template>
      </div>
    </div>

    <!-- Table Area -->
    <div class="table-container card">
      <div class="table-header">
        <div class="search-bar">
          <Search :size="18" />
          <input 
            type="text" 
            v-model="searchQuery" 
            :placeholder="$t('payments.searchPlaceholder')" 
            @input="currentPage = 1"
          />
        </div>
        <div class="table-actions">
          <div class="date-filter-group">
            <div class="date-input">
              <Calendar :size="14" />
              <input type="date" v-model="startDate" @change="currentPage = 1" :placeholder="$t('dashboard.startDate') || 'Start Date'" />
            </div>
            <span class="date-separator">to</span>
            <div class="date-input">
              <Calendar :size="14" />
              <input type="date" v-model="endDate" @change="currentPage = 1" :placeholder="$t('dashboard.endDate') || 'End Date'" />
            </div>
            <button v-if="startDate || endDate" class="btn-clear-date" @click="startDate = ''; endDate = ''; currentPage = 1">
              <X :size="14" />
            </button>
          </div>
          <button class="btn-outline"><Download :size="16" /> {{ $t('common.export') }}</button>
        </div>
      </div>

      <div class="table-scroll-wrapper">
        <table>
          <thead>
            <tr>
               <th>{{ $t('payments.studentColumn') }}</th>
              <th>{{ $t('payments.monthColumn') }}</th>
              <th>{{ $t('payments.commentColumn') }}</th>
              <th>{{ $t('payments.receiptColumn') }}</th>
              <th>{{ $t('payments.amountColumn') }}</th>
              <th>{{ $t('payments.methodColumn') }}</th>
              <th>{{ $t('payments.dateColumn') }}</th>
              <th>{{ $t('payments.statusColumn') }}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <!-- Skeleton Loading -->
            <template v-if="isLoading">
              <tr v-for="i in 5" :key="i">
                <td>
                  <div class="student-info">
                    <div class="skeleton" style="width: 36px; height: 36px; border-radius: 50%;"></div>
                    <div class="details">
                      <div class="skeleton" style="width: 120px; height: 16px; margin-bottom: 4px;"></div>
                      <div class="skeleton" style="width: 180px; height: 12px;"></div>
                    </div>
                  </div>
                </td>
                <td><div class="skeleton" style="width: 80px; height: 16px;"></div></td>
                <td><div class="skeleton" style="width: 100px; height: 16px;"></div></td>
                <td><div class="skeleton" style="width: 90px; height: 24px; border-radius: 6px;"></div></td>
                <td><div class="skeleton" style="width: 80px; height: 16px;"></div></td>
                <td><div class="skeleton" style="width: 70px; height: 26px; border-radius: 8px;"></div></td>
                <td><div class="skeleton" style="width: 24px; height: 24px; border-radius: 6px;"></div></td>
              </tr>
            </template>

            <!-- Real Data -->
            <template v-else>
              <tr v-for="item in paginatedPayments" :key="item.id">
               <td>
                <div class="student-info">
                  <div class="avatar">{{ item.student?.charAt(0) || '?' }}</div>
                  <div class="details">
                    <span class="name">{{ item.student }}</span>
                    <span class="course">{{ item.course }}</span>
                  </div>
                </div>
              </td>
              <td class="table-month-cell"><span class="month-label">{{ item.month || '-' }}</span></td>
              <td class="table-comment-cell">{{ item.comment || '-' }}</td>
              <td><code>{{ item.receiptId }}</code></td>
              <td><span class="amount">{{ formatCurrency(item.amount) }}</span></td>
              <td>
                <div class="method-tag">
                  <span class="icon">{{ getMethodIcon(item.method) }}</span>
                  {{ $t('payments.method' + item.method) }}
                </div>
              </td>
              <td>{{ item.date }}</td>
              <td>
                <span :class="['status-badge', getStatusClass(item.status)]">
                  {{ item.status }}
                </span>
              </td>
              <td>
                <div class="dropdown-wrapper">
                  <button class="btn-icon" @click="(e) => toggleDropdown('pay-' + item.id, e)">
                    <MoreVertical :size="18" />
                  </button>
                  <div v-if="activeDropdown === 'pay-' + item.id" class="dropdown-menu">
                    <button class="dropdown-item" @click="deletePayment(item.id)" :disabled="deletingPaymentId === item.id">
                      <Loader2 v-if="deletingPaymentId === item.id" :size="16" class="spin" />
                      <Trash2 v-else :size="16" /> 
                      {{ deletingPaymentId === item.id ? $t('common.loading') : $t('leads.delete') }}
                    </button>
                  </div>
                </div>
              </td>
            </tr>
          </template>
        </tbody>
        </table>
      </div>

      <div class="table-footer">
        <span>
          {{ $t('payments.showing') }} {{ paginatedPayments.length }} {{ $t('payments.of') }} {{ filteredPayments.length }} {{ $t('payments.entries') }}
        </span>
        <div class="pagination" v-if="totalPages > 1">
          <button 
            :disabled="currentPage === 1" 
            @click="changePage(currentPage - 1)"
          >
            {{ $t('payments.previous') }}
          </button>
          
          <button 
            v-for="page in pageNumbers" 
            :key="page"
            :class="{ active: currentPage === page }"
            @click="changePage(page)"
          >
            {{ page }}
          </button>

          <button 
            :disabled="currentPage === totalPages || totalPages === 0" 
            @click="changePage(currentPage + 1)"
          >
            {{ $t('payments.next') }}
          </button>
        </div>
      </div>
    </div>

    <!-- Add Payment Modal -->
    <transition name="modal">
      <div v-if="showModal" class="modal-overlay" @click.self="closeModal">
        <div class="modal-box">
          <div class="modal-header">
            <div class="modal-title-row">
              <div class="modal-icon"><CreditCard :size="22" /></div>
              <h2>{{ $t('payments.addModalTitle') }}</h2>
            </div>
            <button class="btn-icon" @click="closeModal"><X :size="20" /></button>
          </div>

          <div class="modal-body">
            <div class="form-group">
              <label><User :size="14" /> {{ $t('payments.studentName') }} <span class="required">*</span></label>
              <input v-model="newPayment.student" :placeholder="$t('payments.studentPlaceholder')" />
            </div>

            <div class="form-group">
              <label><FileText :size="14" /> {{ $t('payments.courseLabel') }}</label>
              <input v-model="newPayment.course" :placeholder="$t('payments.coursePlaceholder')" />
            </div>

            <div class="form-row">
              <div class="form-group">
                <label><DollarSign :size="14" /> {{ $t('payments.amountLabel') }} <span class="required">*</span></label>
                <input v-model="newPayment.amount" type="number" :placeholder="$t('payments.amountPlaceholder')" />
              </div>
              <div class="form-group">
                <label><Wallet :size="14" /> {{ $t('payments.methodLabel') }}</label>
                <select v-model="newPayment.method">
                  <option value="Cash">{{ $t('payments.methodCash') }}</option>
                  <option value="Card">{{ $t('payments.methodCard') }}</option>
                  <option value="Click">{{ $t('payments.methodClick') }}</option>
                  <option value="Payme">{{ $t('payments.methodPayme') }}</option>
                  <option value="Transfer">{{ $t('payments.methodTransfer') }}</option>
                </select>
              </div>
            </div>

            <div class="form-row">
              <div class="form-group">
                <label><Calendar :size="14" /> {{ $t('payments.dateLabel') }}</label>
                <input v-model="newPayment.date" type="date" />
              </div>
            </div>
          </div>

          <div class="modal-footer">
            <button class="btn-cancel-modal" @click="closeModal" :disabled="isSubmitting">{{ $t('common.cancel') }}</button>
            <button class="btn-confirm-payment" @click="addPayment" :disabled="!newPayment.student || !newPayment.amount || isSubmitting">
              <template v-if="isSubmitting">
                <Loader2 :size="16" class="spin" /> {{ $t('common.loading') }}
              </template>
              <template v-else>{{ $t('payments.confirmBtn') }}</template>
            </button>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<style scoped>
.payments-page {
  padding: 2rem;
  background: var(--light);
  display: flex;
  flex-direction: column;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
}

.header-content h1 {
  font-size: 1.75rem;
  font-weight: 800;
  color: var(--dark);
  margin-bottom: 0.25rem;
}

.header-content p {
  color: var(--gray);
  font-size: 0.95rem;
}

.btn-primary {
  background: var(--primary);
  color: white;
  padding: 0.75rem 1.5rem;
  border-radius: 12px;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  transition: all 0.2s;
}

.btn-primary:hover {
  background: #6259e6;
  box-shadow: 0 4px 12px rgba(115,102,255,0.4);
}

/* Stats Cards */
.stats-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1.5rem;
  margin-bottom: 2rem;
}

.stat-card {
  background: white;
  padding: 1.5rem;
  border-radius: 20px;
  box-shadow: var(--shadow);
  display: flex;
  align-items: center;
  gap: 1.25rem;
}

.stat-icon {
  width: 56px;
  height: 56px;
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.stat-icon.revenue { background: rgba(115,102,255,0.1); color: var(--primary); }
.stat-icon.success { background: rgba(40,199,111,0.1); color: var(--success); }
.stat-icon.pending { background: rgba(255,159,67,0.1); color: var(--warning); }

.stat-label {
  font-size: 0.85rem;
  color: var(--gray);
  font-weight: 600;
}

.stat-value {
  font-size: 1.5rem;
  font-weight: 800;
  color: var(--dark);
  margin: 0.25rem 0;
}

.stat-trend {
  font-size: 0.75rem;
  font-weight: 600;
}

.stat-trend.positive { color: var(--success); }

.stat-subtext {
  font-size: 0.75rem;
  color: var(--gray);
}

/* Table Card */
.table-container {
  background: white;
  border-radius: 20px;
  box-shadow: var(--shadow);
  overflow: hidden;
}

.table-header {
  padding: 1.5rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid var(--border);
}

.search-bar {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  background: var(--light);
  padding: 0.6rem 1rem;
  border-radius: 12px;
  width: 100%;
  max-width: 350px;
}

.search-bar input {
  background: transparent;
  border: none;
  outline: none;
  width: 100%;
  font-size: 0.9rem;
  color: var(--dark);
}

.table-actions {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.date-filter-group {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  background: white;
  padding: 0.35rem;
  border-radius: 12px;
  border: 1px solid var(--border);
}

.date-input {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  background: var(--light);
  padding: 0.35rem 0.65rem;
  border-radius: 8px;
  color: var(--gray);
}

.date-input input {
  background: transparent;
  border: none;
  outline: none;
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--dark);
  font-family: inherit;
  width: 105px;
}

.date-separator {
  font-size: 0.75rem;
  font-weight: 700;
  color: var(--gray);
  text-transform: lowercase;
}

.btn-clear-date {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--gray);
  background: var(--light);
  transition: all 0.2s;
}

.btn-clear-date:hover {
  background: #fff1f0;
  color: var(--danger);
}

.btn-outline {
  padding: 0.6rem 1rem;
  border: 1.5px solid var(--border);
  border-radius: 10px;
  background: white;
  color: var(--dark);
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.85rem;
  transition: all 0.2s;
}

.btn-outline:hover {
  border-color: var(--primary);
  color: var(--primary);
}

.table-scroll-wrapper {
  overflow-x: auto;
  overflow-y: visible;
}

.table-scroll-wrapper::-webkit-scrollbar {
  width: 6px;
}

.table-scroll-wrapper::-webkit-scrollbar-track {
  background: transparent;
}

.table-scroll-wrapper::-webkit-scrollbar-thumb {
  background: var(--border);
  border-radius: 10px;
}

.table-scroll-wrapper::-webkit-scrollbar-thumb:hover {
  background: var(--gray);
}

/* Table Styles */
table {
  width: 100%;
  border-collapse: collapse;
}

th {
  text-align: left;
  padding: 1.25rem 1.5rem;
  background: #F8F9FA;
  font-size: 0.8rem;
  font-weight: 700;
  color: var(--gray);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

td {
  padding: 1.25rem 1.5rem;
  border-bottom: 1px solid var(--border);
  vertical-align: middle;
}

.student-info {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.avatar {
  width: 36px;
  height: 36px;
  background: var(--primary-light);
  color: var(--primary);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 0.85rem;
}

.details {
  display: flex;
  flex-direction: column;
}

.details .name {
  font-weight: 700;
  color: var(--dark);
  font-size: 0.9rem;
}

.details .course {
  font-size: 0.75rem;
  color: var(--gray);
}

.amount {
  font-weight: 700;
  color: var(--dark);
}

.method-tag {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.85rem;
  color: var(--dark);
  font-weight: 500;
}

.status-badge {
  padding: 0.4rem 0.8rem;
  border-radius: 8px;
  font-size: 0.75rem;
  font-weight: 700;
}

.status-success { background: rgba(40,199,111,0.1); color: var(--success); }
.status-pending { background: rgba(255,159,67,0.1); color: var(--warning); }

.table-month-cell {
  min-width: 120px;
}

.month-label {
  background: #F0F4FF;
  color: #5A67D8;
  padding: 0.3rem 0.6rem;
  border-radius: 6px;
  font-size: 0.75rem;
  font-weight: 700;
  border: 1px solid #E0E7FF;
}

.table-comment-cell {
  max-width: 180px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 0.85rem;
  color: #718096;
  font-weight: 500;
}

.table-footer {
  padding: 1.5rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.85rem;
  color: var(--gray);
}

.pagination {
  display: flex;
  gap: 0.5rem;
}

.pagination button {
  padding: 0.5rem 0.8rem;
  border-radius: 8px;
  border: 1px solid var(--border);
  background: white;
  color: var(--dark);
  font-weight: 600;
}

.pagination button.active {
  background: var(--primary);
  color: white;
  border-color: var(--primary);
}

/* Modal Styling inherited from earlier pages but polished */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(43, 37, 63, 0.5);
  backdrop-filter: blur(8px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 2rem;
}

.modal-box {
  background: white;
  width: 100%;
  max-width: 550px;
  border-radius: 24px;
  box-shadow: 0 25px 60px rgba(0,0,0,0.2);
  overflow: hidden;
  animation: modalIn 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
}

@keyframes modalIn {
  from { opacity: 0; transform: scale(0.9) translateY(20px); }
  to { opacity: 1; transform: scale(1) translateY(0); }
}

.modal-header {
  padding: 1.5rem 2rem;
  border-bottom: 1px solid var(--border);
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.modal-title-row {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.modal-icon {
  width: 44px;
  height: 44px;
  background: var(--primary-light);
  color: var(--primary);
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.modal-header h2 {
  font-size: 1.25rem;
  font-weight: 800;
  color: var(--dark);
}

.modal-body {
  padding: 2rem;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.form-group label {
  font-size: 0.85rem;
  font-weight: 700;
  color: var(--gray);
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.form-group input, .form-group select {
  padding: 0.8rem 1rem;
  border: 1.5px solid var(--border);
  border-radius: 12px;
  font-family: inherit;
  font-size: 0.95rem;
  transition: all 0.2s;
  outline: none;
}

.form-group input:focus, .form-group select:focus {
  border-color: var(--primary);
  box-shadow: 0 0 0 4px rgba(115,102,255,0.1);
}

.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.5rem;
}

.modal-footer {
  padding: 1.5rem 2rem;
  background: #F8F9FA;
  display: flex;
  justify-content: flex-end;
  gap: 1rem;
}

.btn-cancel-modal {
  padding: 0.75rem 1.5rem;
  border-radius: 12px;
  font-weight: 700;
  color: var(--gray);
}

.btn-confirm-payment {
  background: var(--primary);
  color: white;
  padding: 0.75rem 1.5rem;
  border-radius: 12px;
  font-weight: 700;
  box-shadow: 0 4px 12px rgba(115,102,255,0.3);
}

.required { color: var(--danger); }

/* Dropdowns */
.dropdown-wrapper {
  position: relative;
}

.dropdown-menu {
  position: absolute;
  top: 100%;
  right: 0;
  background: white;
  border: 1px solid var(--border);
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
  padding: 0.5rem;
  z-index: 20;
  min-width: 150px;
}

.dropdown-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  width: 100%;
  padding: 0.5rem;
  border-radius: 6px;
  color: var(--danger);
  font-weight: 600;
  cursor: pointer;
  transition: background 0.2s;
  background: transparent;
  border: none;
  font-family: inherit;
  font-size: 0.85rem;
  text-align: left;
}

.dropdown-item:hover {
  background: #fdf3f3;
}

/* Fade animation for modal */
.modal-enter-active, .modal-leave-active { transition: opacity 0.3s; }
.modal-enter-from, .modal-leave-to { opacity: 0; }

.btn-icon {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 6px;
  color: var(--gray);
  cursor: pointer;
  background: transparent;
  border: none;
}
.btn-icon:hover { background: var(--light); }

.btn-confirm-payment:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.skeleton {
  background: linear-gradient(90deg, #f0f0f0 25%, #f8f8f8 50%, #f0f0f0 75%);
  background-size: 200% 100%;
  animation: skeleton-loading 1.5s infinite;
}

@keyframes skeleton-loading {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
</style>
