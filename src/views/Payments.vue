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
  FileDown,
  RotateCcw
} from 'lucide-vue-next';
import { ref, reactive, computed, onMounted } from 'vue';
import { jsPDF } from 'jspdf';
import { supabase } from '../supabase.js';
import PaymentModal from '../components/PaymentModal.vue';

const userRole = ref(localStorage.getItem('userRole') || 'regular');
const showModal = ref(false);
const showDetailsModal = ref(false);
const showRefundModal = ref(false);
const selectedPayment = ref(null);
const refundDays = ref(1);
const isSavingRefund = ref(false);

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
      .eq('is_deleted', false)
      .order('date', { ascending: false })
      .order('created_at', { ascending: false });
      
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
        month: p.month,
        type: p.type || 'payment',
        days: p.days,
        note: p.note
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
    result = result.filter(p => p.date.substring(0, 10) >= startDate.value);
  }
  if (endDate.value) {
    result = result.filter(p => p.date.substring(0, 10) <= endDate.value);
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
const currentMonthRevenue = computed(() => {
  const now = new Date();
  const currentYear = now.getFullYear();
  const currentMonth = now.getMonth();
  
  return payments.value
    .filter(p => {
      if (!p.date || p.status !== 'Success') return false;
      const d = new Date(p.date);
      return d.getFullYear() === currentYear && d.getMonth() === currentMonth;
    })
    .reduce((acc, p) => acc + Number(p.amount), 0);
});
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

const selectedGroupData = ref(null);
const totalRefundedAlready = ref(0);

const openRefundModal = async (payment) => {
  selectedPayment.value = payment;
  refundDays.value = 1;
  showRefundModal.value = true;
  totalRefundedAlready.value = 0;
  
  // 1. Fetch group data to calculate lesson days
  try {
    const { data: stData } = await supabase
      .from('students')
      .select('group_id, groups(days, courses(price))')
      .eq('id', payment.student_id)
      .single();
    
    if (stData) selectedGroupData.value = stData.groups;

    // 2. Fetch already processed refunds for THIS payment
    const { data: existingRefunds } = await supabase
      .from('payments')
      .select('amount')
      .eq('parent_id', payment.id)
      .eq('type', 'refund');
    
    if (existingRefunds) {
      // Sum is negative in DB, so we take absolute
      totalRefundedAlready.value = existingRefunds.reduce((acc, r) => acc + Math.abs(r.amount), 0);
    }
  } catch (e) {
    console.error('Error loading refund context:', e);
  }
};

const closeRefundModal = () => {
  showRefundModal.value = false;
  selectedPayment.value = null;
};

const UZ_DAY_MAP = { 'du': 1, 'se': 2, 'ch': 3, 'pa': 4, 'ju': 5, 'sh': 6, 'ya': 0 };

const calculateDaysInMonth = (monthStr, daysPattern) => {
  if (!monthStr || !daysPattern) return 12;
  
  // Parse monthStr "May 2024"
  const parts = monthStr.split(' ');
  const monthName = parts[0];
  const year = parseInt(parts[1]);
  const monthIdx = [
    'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
    'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr'
  ].indexOf(monthName);
  
  if (monthIdx === -1 || isNaN(year)) return 12;

  // Parse pattern "Du-Chor-Ju"
  const targetDays = daysPattern.toLowerCase().split(/[\s,\-\/]+/).map(d => UZ_DAY_MAP[d.substring(0, 2)]).filter(d => d !== undefined);
  if (targetDays.length === 0) return 12;

  const daysInMonth = new Date(year, monthIdx + 1, 0).getDate();
  let count = 0;
  for (let d = 1; d <= daysInMonth; d++) {
    const date = new Date(year, monthIdx, d);
    if (targetDays.includes(date.getDay())) count++;
  }
  return count > 0 ? count : 12;
};

const totalDaysInPayment = computed(() => {
  if (!selectedPayment.value) return 12;
  
  // 1. Try to get from tag [DAYS:...]
  if (selectedPayment.value.comment) {
    const match = selectedPayment.value.comment.match(/\[DAYS:([^\]]+)\]/);
    if (match && match[1]) return match[1].split(',').length;
  }
  
  // 2. Fallback: Calculate based on group schedule
  if (selectedGroupData.value && selectedGroupData.value.days) {
    return calculateDaysInMonth(selectedPayment.value.month, selectedGroupData.value.days);
  }
  
  return 12;
});

const perLessonPrice = computed(() => {
  if (!selectedPayment.value || !selectedGroupData.value) return 0;
  const fullMonthLessons = calculateDaysInMonth(selectedPayment.value.month, selectedGroupData.value.days);
  const coursePrice = selectedGroupData.value.courses?.price || 0;
  return fullMonthLessons > 0 ? Math.round(coursePrice / fullMonthLessons) : 0;
});

const maxRefundDaysAllowed = computed(() => {
  if (!selectedPayment.value || perLessonPrice.value <= 0) return 0;
  
  // Remaining money on this receipt
  const remainingMoney = selectedPayment.value.amount - totalRefundedAlready.value;
  if (remainingMoney <= 0) return 0;

  // Max days by remaining amount
  const byAmount = Math.floor(remainingMoney / perLessonPrice.value);
  
  // If we have a tag with specific days, we account for those too (optional but safer)
  let byTag = 99;
  if (selectedPayment.value.comment) {
    const match = selectedPayment.value.comment.match(/\[DAYS:([^\]]+)\]/);
    if (match && match[1]) byTag = match[1].split(',').length;
  }
  
  return Math.min(byAmount, byTag);
});

const calculatedRefundAmount = computed(() => {
  return perLessonPrice.value * refundDays.value;
});

const confirmRefund = async () => {
  if (isSavingRefund.value || !selectedPayment.value) return;
  isSavingRefund.value = true;
  try {
    const refundData = {
      student_id: selectedPayment.value.student_id || null,
      student: selectedPayment.value.student || 'Unknown',
      course: selectedPayment.value.course || '',
      amount: -calculatedRefundAmount.value,
      type: 'refund',
      days: refundDays.value,
      note: `Refund for ${refundDays.value} days`,
      date: new Date().toISOString(),
      method: selectedPayment.value.method || 'Cash',
      status: 'Success',
      receipt_id: 'REF-' + Math.floor(Math.random() * 90000 + 10000),
      month: selectedPayment.value.month || '',
      id: crypto.randomUUID(),
      parent_id: selectedPayment.value.id
    };

    const { error, data } = await supabase.from('payments').insert([refundData]).select();
    if (error) {
       console.error('Supabase Refund Error Detailed:', error);
       throw error;
    }
    
    await loadData();
    closeRefundModal();
  } catch (e) {
    console.error('Full Refund Error Object:', e);
    alert('Failed to process refund: ' + (e.message || 'Unknown error'));
  } finally {
    isSavingRefund.value = false;
  }
};

const generatePDF = (payment) => {
  const doc = new jsPDF();
  const isRefund = payment.type === 'refund';
  
  // Helper to render Cyrillic text as an image using Canvas
  const renderCyrillic = (text, x, y, fontSize, isBold = false) => {
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    const scale = 5; // High resolution
    ctx.font = `${isBold ? 'bold' : ''} ${fontSize * scale}px Arial`;
    const metrics = ctx.measureText(text);
    
    canvas.width = metrics.width;
    canvas.height = fontSize * scale * 1.5;
    
    ctx.font = `${isBold ? 'bold' : ''} ${fontSize * scale}px Arial`;
    ctx.fillStyle = '#1e293b';
    ctx.textBaseline = 'top';
    ctx.fillText(text, 0, 0);
    
    const imgData = canvas.toDataURL('image/png');
    // Convert pixels to mm (1px ~ 0.2645mm at 96DPI, but we scaled by 5)
    // Formula: (canvas_width / scale) * (mm_per_point)
    const pxToMm = 0.30; 
    const w = (canvas.width / scale) * pxToMm;
    const h = (canvas.height / scale) * pxToMm;
    
    doc.addImage(imgData, 'PNG', x, y - 0.5, w, h);
  };

  const primaryColor = isRefund ? [234, 84, 85] : [115, 102, 255]; 
  const secondaryColor = [248, 250, 252];
  
  // Header
  doc.setFillColor(primaryColor[0], primaryColor[1], primaryColor[2]);
  doc.rect(0, 0, 210, 45, 'F');
  
  doc.setTextColor(255, 255, 255);
  doc.setFontSize(26);
  doc.setFont('helvetica', 'bold');
  const title = isRefund ? 'REFUND VOUCHER' : 'PAYMENT RECEIPT';
  doc.text(title, 105, 28, { align: 'center' });
  
  doc.setTextColor(30, 41, 59);
  doc.setFillColor(secondaryColor[0], secondaryColor[1], secondaryColor[2]);
  doc.rect(140, 55, 55, 35, 'F');
  
  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');
  doc.text(isRefund ? 'Return ID' : 'Receipt ID', 145, 63);
  doc.setFontSize(12);
  doc.setFont('helvetica', 'bold');
  doc.text(String(payment.receiptId || payment.receipt_id), 145, 70);
  
  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');
  doc.text('Date', 145, 80);
  doc.setFontSize(11);
  const numericDate = new Date(payment.date).toLocaleDateString('ru-RU');
  doc.text(numericDate, 145, 87);

  // Content Labels
  doc.setFontSize(14);
  doc.setFont('helvetica', 'bold');
  doc.text('CLIENT INFORMATION', 20, 65);
  doc.line(20, 68, 80, 68);
  
  doc.setFontSize(11);
  doc.setFont('helvetica', 'normal');
  doc.text(`Full Name:`, 20, 80);
  renderCyrillic(payment.student || 'Student', 50, 80, 11);
  
  doc.text(`Course:`, 20, 90);
  renderCyrillic(payment.course || 'Course', 50, 90, 11);

  doc.setFontSize(14);
  doc.setFont('helvetica', 'bold');
  doc.text('TRANSACTION DETAILS', 20, 115);
  doc.line(20, 118, 80, 118);

  doc.setFontSize(11);
  doc.setFont('helvetica', 'normal');
  doc.text(`Type:`, 20, 130);
  doc.text(isRefund ? 'REFUND' : 'PAYMENT', 60, 130);

  doc.text(`Billing Month:`, 20, 140);
  renderCyrillic(payment.month || '-', 60, 140, 11);
  
  doc.text(`Method:`, 20, 150);
  doc.text(payment.method || '', 60, 150);
  
  if (payment.note || isRefund) {
    doc.text(`Reason:`, 20, 160);
    const noteText = payment.note || (isRefund ? `Return for ${payment.days} days` : '');
    renderCyrillic(noteText, 60, 160, 11);
  }

  // Footer / Total
  doc.setFillColor(secondaryColor[0], secondaryColor[1], secondaryColor[2]);
  doc.rect(20, 185, 170, 35, 'F');
  
  doc.setFontSize(16);
  doc.setFont('helvetica', 'bold');
  const footerLabel = isRefund ? 'TOTAL REFUNDED:' : 'TOTAL PAID:';
  doc.text(footerLabel, 30, 207);
  
  doc.setFontSize(22);
  doc.setTextColor(isRefund ? 234 : 115, isRefund ? 84 : 102, isRefund ? 85 : 255);
  const amountStr = Number(payment.amount).toLocaleString('ru-RU') + " UZS";
  doc.text(amountStr, 180, 207, { align: 'right' });

  // Reset text color for footer
  doc.setTextColor(100, 116, 139);
  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');
  doc.text('EduCRM System - Official Document', 105, 235, { align: 'center' });
  
  doc.save(`${isRefund ? 'Refund' : 'Receipt'}_${payment.receiptId}.pdf`);
};


const deletePayment = async (id) => {
  if (deletingPaymentId.value) return;
  deletingPaymentId.value = id;
  try {
    const { error } = await supabase
      .from('payments')
      .update({ 
        is_deleted: true, 
        deleted_at: new Date().toISOString() 
      })
      .eq('id', id);

    if (error) throw error;
    payments.value = payments.value.filter(p => p.id !== id);
    activeDropdown.value = null;
  } catch (e) {
    console.error('Error soft deleting payment:', e);
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

      <!-- Current Month Revenue Stat -->
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
          <div class="stat-icon success">
            <Wallet :size="24" />
          </div>
          <div class="stat-info">
            <span class="stat-label">Выручка за месяц</span>
            <h2 class="stat-value">{{ formatCurrency(currentMonthRevenue) }}</h2>
            <span class="stat-subtext">В этом месяце</span>
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
                <span :class="['status-badge', item.type === 'refund' ? 'status-refund' : getStatusClass(item.status)]">
                  {{ item.type === 'refund' ? 'Возврат' : item.status }}
                </span>
              </td>
              <td :data-label="$t('common.actions') || 'Actions'">
                <div class="row-actions">
                  <button class="btn-icon export-btn" @click="openDetailsModal(item)" :title="$t('common.export')">
                    <Download :size="18" />
                  </button>
                  <button v-if="item.type !== 'refund'" class="btn-icon refund-btn" @click="openRefundModal(item)" title="Refund / Возврат">
                    <RotateCcw :size="18" />
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
              <div class="modal-icon" :class="{ 'refund-theme': selectedPayment.type === 'refund' }">
                <RotateCcw v-if="selectedPayment.type === 'refund'" :size="22" />
                <FileText v-else :size="22" />
              </div>
              <h2 :class="{ 'text-refund': selectedPayment.type === 'refund' }">
                {{ selectedPayment.type === 'refund' ? 'Детали возврата' : $t('payments.details') }}
              </h2>
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

              <div class="receipt-total" :class="{ 'refund-theme': selectedPayment.type === 'refund' }">
                <span>{{ selectedPayment.type === 'refund' ? 'Сумма возврата' : $t('payments.amountColumn') }}</span>
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
    <!-- Refund Modal -->
    <transition name="modal">
      <div v-if="showRefundModal && selectedPayment" class="modal-overlay" @click.self="closeRefundModal">
        <div class="modal-box confirm-modal">
          <div class="modal-header">
            <div class="header-title">
              <div class="modal-icon warning"><RotateCcw :size="22" /></div>
              <h2>Оформить возврат</h2>
            </div>
            <button class="btn-icon" @click="closeRefundModal"><X :size="20" /></button>
          </div>
          <div class="modal-body">
            <div class="refund-info-box">
              <div class="info-row">
                <span class="label">Студент:</span>
                <span class="value">{{ selectedPayment.student }}</span>
              </div>
              <div class="info-row">
                <span class="label">Уплачено за этот раз:</span>
                <span class="value">{{ formatCurrency(selectedPayment.amount) }}</span>
              </div>
              <div class="info-row" v-if="totalRefundedAlready > 0">
                <span class="label">Уже возвращено по этому чеку:</span>
                <span class="value text-danger">{{ formatCurrency(totalRefundedAlready) }}</span>
              </div>
              <div class="info-row price-note">
                <span class="label">Остаток к возврату:</span>
                <span class="value">{{ formatCurrency(selectedPayment.amount - totalRefundedAlready) }}</span>
              </div>
            </div>
            
            <div class="form-group mb-4">
              <label class="field-label">Количество дней для возврата</label>
              <div class="refund-selector">
                <button class="btn-step" @click="refundDays--" :disabled="refundDays <= 1">-</button>
                <input type="number" v-model.number="refundDays" min="1" :max="maxRefundDaysAllowed" class="refund-input" />
                <button class="btn-step" @click="refundDays++" :disabled="refundDays >= maxRefundDaysAllowed">+</button>
              </div>
              <p class="text-xs text-danger mt-1" v-if="maxRefundDaysAllowed > 0">
                Максимально доступно для возврата: {{ maxRefundDaysAllowed }} дн.
              </p>
            </div>

            <div class="refund-calculation">
                <div class="calc-label">Сумма к возврату:</div>
                <div class="calc-value">{{ formatCurrency(calculatedRefundAmount) }}</div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn-secondary" @click="closeRefundModal">Отмена</button>
            <button class="btn-danger-confirm" @click="confirmRefund" :disabled="isSavingRefund">
                <Loader2 v-if="isSavingRefund" :size="18" class="spin" />
                <span v-else>Подтвердить возврат</span>
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
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 1.25rem;
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
  font-size: clamp(1rem, 2vw, 1.25rem);
  font-weight: 800;
  color: var(--dark);
  margin: 0.25rem 0;
  white-space: nowrap;
  line-height: 1.2;
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
  padding: 1.25rem 1.5rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid var(--border);
  flex-wrap: wrap;
  gap: 1rem;
}

.search-bar {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  background: var(--light);
  padding: 0.6rem 1rem;
  border-radius: 12px;
  width: 100%;
  max-width: 320px;
  min-width: 0;
  flex: 1;
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
  flex-wrap: wrap;
  width: 100%;
}

.date-input {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  background: var(--light);
  padding: 0.35rem 0.65rem;
  border-radius: 8px;
  color: var(--gray);
  position: relative;
}

.date-input input {
  background: transparent;
  border: none;
  outline: none;
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--dark);
  font-family: inherit;
  width: 130px;
  min-width: 0;
  cursor: pointer;
  position: relative;
}

.date-input input::-webkit-calendar-picker-indicator {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  width: auto;
  height: auto;
  color: transparent;
  background: transparent;
  cursor: pointer;
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
  width: 100%;
  -webkit-overflow-scrolling: touch;
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
  word-wrap: break-word;
  white-space: normal;
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

.status-success { background: rgba(40, 199, 111, 0.1); color: var(--success); }
.status-pending { background: rgba(255, 159, 67, 0.1); color: var(--warning); }
.status-refund { background: rgba(234, 84, 85, 0.1); color: var(--danger); font-weight: 800; }

.refund-btn { color: var(--danger); }
.refund-btn:hover { background: rgba(234, 84, 85, 0.1); }

.refund-info-box {
  background: var(--light);
  padding: 1rem;
  border-radius: 12px;
  margin-bottom: 1.5rem;
}
.info-row { display: flex; justify-content: space-between; margin-bottom: 0.5rem; }
.info-row:last-child { margin-bottom: 0; }
.info-row .label { color: var(--gray); font-size: 0.85rem; font-weight: 600; }
.info-row .value { color: var(--dark); font-weight: 700; }
.price-note { margin-top: 0.5rem; padding-top: 0.5rem; border-top: 1px dashed var(--border); }
.price-note .value { color: var(--primary); }

.refund-selector {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}
.btn-step {
  width: 40px;
  height: 40px;
  border-radius: 10px;
  border: 1.5px solid var(--border);
  background: white;
  font-weight: 800;
  font-size: 1.2rem;
  cursor: pointer;
  transition: all 0.2s;
}
.btn-step:hover:not(:disabled) { border-color: var(--primary); color: var(--primary); }
.btn-step:disabled { opacity: 0.5; cursor: not-allowed; }
.refund-input {
  width: 80px;
  text-align: center;
  font-size: 1.1rem;
  font-weight: 800;
  border: 2px solid var(--primary-light);
  border-radius: 10px;
  padding: 0.5rem;
}

.refund-calculation {
  background: #FFF5F5;
  border: 1px dashed var(--danger);
  padding: 1.25rem;
  border-radius: 14px;
  text-align: center;
}
.calc-label { color: var(--danger); font-size: 0.9rem; font-weight: 700; margin-bottom: 0.25rem; }
.calc-value { color: var(--danger); font-size: 1.5rem; font-weight: 800; }

.btn-danger-confirm {
  background: var(--danger);
  color: white;
  padding: 0.75rem 1.5rem;
  border-radius: 12px;
  font-weight: 700;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  transition: all 0.2s;
}
.btn-danger-confirm:hover:not(:disabled) {
  background: #d9393d;
  box-shadow: 0 4px 12px rgba(234, 84, 85, 0.4);
}
.btn-danger-confirm:disabled { opacity: 0.6; cursor: not-allowed; }

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

.modal-icon.refund-theme {
  background: #FFF5F5;
  color: var(--danger);
}

.text-refund {
  color: var(--danger) !important;
}

.receipt-total.refund-theme {
  background: #FFF5F5;
  border-top: 1px dashed var(--danger);
}

.receipt-total.refund-theme h2 {
  color: var(--danger);
}

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

/* ── Payments Responsive ─────────────────────────────────────── */
@media (max-width: 767px) {
  .table-header {
    flex-direction: column;
    align-items: stretch;
    padding: 1rem;
  }
  .search-bar {
    max-width: 100%;
  }
  .table-actions {
    flex-direction: column;
    align-items: stretch;
  }
  .date-filter-group {
    flex-wrap: wrap;
    justify-content: center;
  }
  .date-input {
    flex: 1;
    min-width: 130px;
  }
  .date-input input {
    width: 100%;
  }
  .stats-grid {
    grid-template-columns: 1fr !important;
    gap: 0.75rem;
  }
  .payments-page {
    padding: 1rem;
  }
}

@media (min-width: 768px) and (max-width: 1024px) {
  .stats-grid {
    grid-template-columns: repeat(3, 1fr) !important;
    gap: 1rem;
  }
  .stat-card {
    padding: 1rem;
    gap: 0.75rem;
  }
  .table-scroll-wrapper table {
    min-width: 800px;
  }
}
</style>
