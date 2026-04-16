<script setup>
import { 
  Plus,
  CreditCard,
  Search, 
  Download, 
  Filter, 
  MoreVertical, 
  DollarSign, 
  Clock, 
  CheckCircle2,
  X,
  User,
  Calendar,
  Wallet,
  FileText,
  Trash2,
  Loader2,
  Printer,
  FileDown
} from 'lucide-vue-next';
import { ref, reactive, computed, onMounted } from 'vue';
import { jsPDF } from 'jspdf';
import { supabase } from '../supabase.js';
import PaymentModal from '../components/PaymentModal.vue';

const userRole = ref(localStorage.getItem('userRole') || 'regular');
const showModal = ref(false);
const showDetailsModal = ref(false);
const selectedPayment = ref(null);

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
    // 1. Fetch payments (newest first)
    const { data: pData, error: pError } = await supabase
      .from('payments')
      .select('*')
      .order('date', { ascending: false })
      .order('created_at', { ascending: false }); // Secondary sort to be sure
      
    if (pError) throw pError;
    
    payments.value = (pData || []).map(p => {
      // Clean comment from technical tags [DAYS:...] and [M:...]
      let cleanComment = p.comment || '';
      cleanComment = cleanComment.replace(/\[DAYS:[^\]]+\]/g, '').replace(/\[M:[^\]]+\]/g, '').trim();

      return {
        id: p.id,
        student: p.student,
        student_id: p.student_id,
        course: p.course,
        amount: p.amount,
        method: p.method,
        date: p.date,
        status: p.status,
        receiptId: p.receipt_id,
        comment: cleanComment,
        month: p.month
      };
    });

    // 2. Fetch pending reminders count
    const { count, error: cError } = await supabase
      .from('payment_reminders')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'Pending');
    
    if (!cError) remindersCount.value = count || 0;

  } catch (e) {
    console.error('Error loading payments:', e);
  } finally {
    isLoading.value = false;
  }
};

const remindersCount = ref(0);

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

const openModal = () => {
  showModal.value = true;
};

const closeModal = () => {
  showModal.value = false;
};

const onPaymentSuccess = () => {
  loadData();
};

const openDetailsModal = (payment) => {
  selectedPayment.value = payment;
  showDetailsModal.value = true;
};

const closeDetailsModal = () => {
  showDetailsModal.value = false;
  selectedPayment.value = null;
};

const generatePDF = (payment) => {
  const doc = new jsPDF();
  
  // Set font
  doc.setFont('helvetica');

  // Header
  doc.setFillColor(115, 102, 255); // Primary color
  doc.rect(0, 0, 210, 40, 'F');
  
  doc.setTextColor(255, 255, 255);
  doc.setFontSize(24);
  doc.text('PAYMENT RECEIPT', 105, 25, { align: 'center' });
  
  // Reset text color
  doc.setTextColor(30, 41, 59); // Dark color
  
  // Receipt Info Background
  doc.setFillColor(248, 250, 252);
  doc.rect(140, 50, 55, 30, 'F');
  
  doc.setFontSize(10);
  doc.text('Receipt ID', 145, 58);
  doc.setFontSize(12);
  doc.text(String(payment.receiptId), 145, 65);
  
  doc.setFontSize(10);
  doc.text('Date', 145, 73);
  doc.setFontSize(11);
  // Numeric date format to avoid Cyrillic Month encoding issues
  const numericDate = new Date(payment.date).toLocaleDateString('ru-RU');
  doc.text(numericDate, 145, 78);

  // Content
  doc.setFontSize(14);
  doc.text('STUDENT INFORMATION', 20, 60);
  doc.line(20, 63, 80, 63);
  
  doc.setFontSize(11);
  doc.text(`Full Name:`, 20, 75);
  doc.text(payment.student || '', 50, 75);
  
  doc.text(`Course:`, 20, 85);
  doc.text(payment.course || '', 50, 85);

  doc.setFontSize(14);
  doc.text('PAYMENT DETAILS', 20, 105);
  doc.line(20, 108, 70, 108);

  doc.text(`Billing Month:`, 20, 120);
  doc.text(payment.month || '-', 60, 120);
  
  doc.text(`Payment Method:`, 20, 130);
  doc.text(payment.method || '', 60, 130);
  
  doc.text(`Status:`, 20, 140);
  doc.text(payment.status || '', 60, 140);
  
  if (payment.comment) {
    doc.text(`Notes:`, 20, 150);
    const splitComment = doc.splitTextToSize(payment.comment, 130);
    doc.text(splitComment, 60, 150);
  }

  // Footer / Total
  doc.setFillColor(248, 250, 252);
  doc.rect(20, 180, 170, 30, 'F');
  
  doc.setFontSize(16);
  doc.text('TOTAL PAID:', 30, 200);
  doc.setFontSize(20);
  // Numeric amount formatting
  const amountStr = Number(payment.amount).toLocaleString('ru-RU') + " UZS";
  doc.text(amountStr, 180, 200, { align: 'right' });

  // Thank you note
  doc.setFontSize(10);
  doc.setTextColor(100, 116, 139);
  doc.text('Thank you for choosing EduCRM!', 105, 230, { align: 'center' });
  
  doc.save(`Receipt_${payment.receiptId}.pdf`);
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

const formatDate = (dateStr) => {
  if (!dateStr) return '-';
  const date = new Date(dateStr);
  const locale = localStorage.getItem('userLanguage') === 'uz' ? 'uz-UZ' : 'ru-RU';
  return date.toLocaleDateString(locale, { day: 'numeric', month: 'long' });
};

const handleExport = () => {
  if (payments.value.length === 0) return;
  
  const headers = [
    t('payments.studentColumn'),
    t('payments.monthColumn'),
    t('payments.commentColumn'),
    t('payments.receiptColumn'),
    t('payments.amountColumn'),
    t('payments.methodColumn'),
    t('payments.dateColumn'),
    t('payments.statusColumn')
  ];
  
  const rows = payments.value.map(p => [
    p.student_name || p.student,
    p.month || '-',
    p.notes || '',
    p.receipt_id,
    p.amount,
    p.method,
    p.date,
    p.status
  ]);
  
  const csvContent = [
    headers.join(','),
    ...rows.map(r => r.join(','))
  ].join('\n');
  
  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
  const link = document.createElement('a');
  const url = URL.createObjectURL(blob);
  link.setAttribute('href', url);
  link.setAttribute('download', `payments_export_${new Date().toISOString().split('T')[0]}.csv`);
  link.style.visibility = 'hidden';
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
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
        <CreditCard :size="20" /> 
        {{ $t('students.payNow') }}
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
            <span class="stat-label">{{ $t('payments.expected') }}</span>
            <h2 class="stat-value">{{ remindersCount }}</h2>
            <span class="stat-subtext">{{ $t('payments.activeReminders') }}</span>
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
                <td :data-label="$t('payments.studentColumn')">
                  <div class="student-info">
                    <div class="skeleton" style="width: 36px; height: 36px; border-radius: 50%;"></div>
                    <div class="details">
                      <div class="skeleton" style="width: 120px; height: 16px; margin-bottom: 4px;"></div>
                      <div class="skeleton" style="width: 180px; height: 12px;"></div>
                    </div>
                  </div>
                </td>
                <td :data-label="$t('payments.monthColumn')"><div class="skeleton" style="width: 80px; height: 16px;"></div></td>
                <td :data-label="$t('payments.commentColumn')"><div class="skeleton" style="width: 100px; height: 16px;"></div></td>
                <td :data-label="$t('payments.receiptColumn')"><div class="skeleton" style="width: 90px; height: 24px; border-radius: 6px;"></div></td>
                <td :data-label="$t('payments.amountColumn')"><div class="skeleton" style="width: 80px; height: 16px;"></div></td>
                <td :data-label="$t('payments.methodColumn')"><div class="skeleton" style="width: 70px; height: 26px; border-radius: 8px;"></div></td>
                <td :data-label="$t('payments.dateColumn')"><div class="skeleton" style="width: 24px; height: 24px; border-radius: 6px;"></div></td>
                <td :data-label="$t('payments.statusColumn')"><div class="skeleton" style="width: 70px; height: 26px; border-radius: 8px;"></div></td>
                <td :data-label="$t('common.actions') || 'Actions'"><div class="skeleton" style="width: 24px; height: 24px; border-radius: 6px;"></div></td>
              </tr>
            </template>

            <!-- Real Data -->
            <template v-else>
              <tr v-for="item in paginatedPayments" :key="item.id">
               <td :data-label="$t('payments.studentColumn')">
                <div class="student-info">
                  <div class="avatar">{{ item.student?.charAt(0) || '?' }}</div>
                  <div class="details">
                    <span class="name">{{ item.student }}</span>
                    <span class="course">{{ item.course }}</span>
                  </div>
                </div>
              </td>
              <td class="table-month-cell" :data-label="$t('payments.monthColumn')"><span class="month-label">{{ item.month || '-' }}</span></td>
              <td class="table-comment-cell" :data-label="$t('payments.commentColumn')">{{ (item.comment || '').replace(/\[M:[^\]]+\]/g, '').replace(/\[DAYS:[^\]]+\]/g, '').trim() || '' }}</td>
              <td :data-label="$t('payments.receiptColumn')"><code>{{ item.receiptId }}</code></td>
              <td :data-label="$t('payments.amountColumn')"><span class="amount">{{ formatCurrency(item.amount) }}</span></td>
              <td :data-label="$t('payments.methodColumn')">
                <div class="method-tag">
                  <span class="icon">{{ getMethodIcon(item.method) }}</span>
                  {{ $t('payments.method' + item.method) }}
                </div>
              </td>
              <td class="table-date-cell" :data-label="$t('payments.dateColumn')">{{ formatDate(item.date) }}</td>
              <td :data-label="$t('payments.statusColumn')">
                <span :class="['status-badge', getStatusClass(item.status)]">
                  {{ item.status }}
                </span>
              </td>
              <td :data-label="$t('common.actions') || 'Actions'">
                <div class="row-actions">
                  <button class="btn-icon export-btn" @click="openDetailsModal(item)" :title="$t('common.export')">
                    <Download :size="18" />
                  </button>
                  <div class="dropdown-wrapper" v-if="userRole === 'admin'">
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
    <PaymentModal 
      :show="showModal"
      @close="closeModal"
      @success="onPaymentSuccess"
    />

    <!-- Payment Details Modal -->
    <transition name="modal">
      <div v-if="showDetailsModal && selectedPayment" class="modal-overlay" @click.self="closeDetailsModal">
        <div class="modal-box details-modal">
          <div class="modal-header">
            <div class="header-title">
              <div class="modal-icon"><FileText :size="22" /></div>
              <h2>{{ $t('payments.details') || 'Payment Details' }}</h2>
            </div>
            <button class="btn-icon" @click="closeDetailsModal"><X :size="20" /></button>
          </div>

          <div class="modal-body p-0">
            <div class="receipt-preview">
              <div class="receipt-header">
                <div class="company-logo">EduCRM</div>
                <div class="receipt-id-tag">
                  <span>{{ $t('payments.receiptColumn') }}</span>
                  <strong>{{ selectedPayment.receiptId }}</strong>
                </div>
              </div>
              
              <div class="receipt-grid">
                <div class="grid-item">
                  <label>{{ $t('payments.studentColumn') }}</label>
                  <span>{{ selectedPayment.student }}</span>
                </div>
                <div class="grid-item">
                  <label>{{ $t('students.course') }}</label>
                  <span>{{ selectedPayment.course }}</span>
                </div>
                <div class="grid-item">
                  <label>{{ $t('payments.dateColumn') }}</label>
                  <span>{{ formatDate(selectedPayment.date) }}</span>
                </div>
                <div class="grid-item">
                  <label>{{ $t('payments.methodColumn') }}</label>
                  <span>{{ selectedPayment.method }}</span>
                </div>
                <div class="grid-item">
                  <label>{{ $t('payments.monthColumn') }}</label>
                  <span>{{ selectedPayment.month || '-' }}</span>
                </div>
                <div class="grid-item">
                  <label>{{ $t('payments.statusColumn') }}</label>
                  <span :class="getStatusClass(selectedPayment.status)">{{ selectedPayment.status }}</span>
                </div>
              </div>

              <div class="receipt-comment" v-if="selectedPayment.comment">
                <label>{{ $t('payments.commentColumn') }}</label>
                <p>{{ selectedPayment.comment }}</p>
              </div>

              <div class="receipt-total">
                <span>{{ $t('payments.amountColumn') }}</span>
                <h2>{{ formatCurrency(selectedPayment.amount) }}</h2>
              </div>
            </div>
          </div>

          <div class="modal-footer">
            <button class="btn-secondary" @click="closeDetailsModal">{{ $t('common.cancel') }}</button>
            <button class="btn-primary" @click="generatePDF(selectedPayment)">
              <FileDown :size="18" />
              {{ $t('common.downloadPDF') || 'Download PDF' }}
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
  overflow-x: hidden;
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
  padding: 1.1rem 1rem;
  background: #F8F9FA;
  font-size: 0.75rem;
  font-weight: 700;
  color: var(--gray);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

td {
  padding: 0.9rem 1rem;
  border-bottom: 1px solid #F1F5F9;
  vertical-align: middle;
}

.student-info {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.avatar {
  width: 38px;
  height: 38px;
  background: var(--primary-light);
  color: var(--primary);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 800;
  font-size: 0.9rem;
  flex-shrink: 0;
  border: 2px solid white;
  box-shadow: 0 2px 8px rgba(0,0,0,0.05);
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
  min-width: 100px;
}

.month-label {
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

.table-comment-cell {
  max-width: 150px;
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
.table-date-cell {
  white-space: nowrap;
  font-weight: 500;
  color: var(--gray);
  min-width: 80px;
}

.row-actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  justify-content: flex-end;
}

.export-btn {
  color: var(--primary) !important;
  background: var(--primary-light) !important;
  border-radius: 8px !important;
  width: 32px !important;
  height: 32px !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  transition: all 0.2s !important;
  border: none !important;
  cursor: pointer !important;
}

.export-btn:hover {
  background: var(--primary) !important;
  color: white !important;
}

/* Details Modal Styles */
.details-modal {
  max-width: 500px !important;
}

.p-0 { padding: 0 !important; }

.receipt-preview {
  padding: 2.5rem;
  background: white;
}

.receipt-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2.5rem;
}

.company-logo {
  font-size: 1.75rem;
  font-weight: 900;
  color: var(--primary);
  letter-spacing: -0.5px;
}

.receipt-id-tag {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
}

.receipt-id-tag span {
  font-size: 0.7rem;
  color: var(--gray);
  text-transform: uppercase;
  letter-spacing: 1px;
  font-weight: 700;
}

.receipt-id-tag strong {
  font-size: 1.25rem;
  color: var(--dark);
  font-family: 'Courier New', Courier, monospace;
}

.receipt-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 2rem;
  margin-bottom: 2.5rem;
}

.grid-item {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.grid-item label {
  font-size: 0.7rem;
  font-weight: 800;
  color: var(--gray);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.grid-item span {
  font-weight: 600;
  color: var(--dark);
  font-size: 1rem;
}

.status-success { color: var(--success) !important; }
.status-pending { color: var(--warning) !important; }

.receipt-comment {
  margin-bottom: 2.5rem;
  padding: 1.25rem;
  background: #F8FAFC;
  border-radius: 16px;
  border: 1px solid var(--border);
}

.receipt-comment label {
  font-size: 0.7rem;
  font-weight: 800;
  color: var(--gray);
  text-transform: uppercase;
  display: block;
  margin-bottom: 0.75rem;
}

.receipt-comment p {
  font-size: 0.95rem;
  color: #334155;
  line-height: 1.6;
}

.receipt-total {
  border-top: 2px dashed var(--border);
  padding-top: 2rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.receipt-total span {
  font-weight: 800;
  color: var(--gray);
  text-transform: uppercase;
  font-size: 0.85rem;
}

.receipt-total h2 {
  color: var(--primary);
  font-weight: 900;
  font-size: 1.75rem;
}

.btn-secondary {
  padding: 0.75rem 1.5rem;
  border-radius: 12px;
  font-weight: 700;
  color: var(--gray);
  background: var(--light);
  border: none;
  cursor: pointer;
}
</style>
