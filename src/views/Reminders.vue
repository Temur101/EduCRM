<script setup>
import { 
  Plus, 
  Search, 
  MoreVertical, 
  BellRing,
  CheckCircle,
  XCircle,
  CalendarClock,
  Trash2,
  X,
  Check,
  Loader2,
  Edit,
  ChevronLeft,
  ChevronRight,
  AlertTriangle,
  CreditCard,
  User,
  Users
} from 'lucide-vue-next';
import { ref, reactive, computed, onMounted } from 'vue';
import { supabase } from '../supabase.js';

const reminders = ref([]);
const students = ref([]);
const isLoading = ref(true);
const isSubmitting = ref(false);
const deletingId = ref(null);
const activeDropdown = ref(null);
const searchQuery = ref('');
const currentPage = ref(1);
const itemsPerPage = 10;
const activeTab = ref('Guruhlar');

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
    // 1. Fetch Students with Groups
    const { data: studentsData } = await supabase
      .from('students')
      .select('id, name, groups(name)')
      .eq('status', 'Active');
    students.value = studentsData || [];

    // 2. Fetch Reminders with Student and Group details
    const { data: remindersData, error } = await supabase
      .from('payment_reminders')
      .select(`
        *,
        students (
          id,
          name,
          phone,
          groups (name)
        )
      `)
      .order('promised_date', { ascending: true });
      
    if (error) throw error;
    reminders.value = remindersData || [];
  } catch (e) {
    console.error('Error loading reminders:', e.message);
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  document.addEventListener('click', closeDropdowns);
  loadData();
});

const filteredReminders = computed(() => {
  let list = reminders.value;

  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase();
    list = list.filter(r => 
      r.students?.name?.toLowerCase().includes(q) || 
      r.notes?.toLowerCase().includes(q)
    );
  }
  return list;
});

const totalPages = computed(() => Math.ceil(filteredReminders.value.length / itemsPerPage));
const paginatedReminders = computed(() => {
  const start = (currentPage.value - 1) * itemsPerPage;
  return filteredReminders.value.slice(start, start + itemsPerPage);
});

const setPage = (page) => {
  if (page >= 1 && page <= totalPages.value) currentPage.value = page;
};

// Form State
const showModal = ref(false);
const isEditing = ref(false);
const editingId = ref(null);

const form = reactive({
  student_id: '',
  amount: '',
  promised_date: '',
  notes: '',
  status: 'Pending'
});

const openAddModal = () => {
  isEditing.value = false;
  editingId.value = null;
  form.student_id = '';
  form.amount = '';
  
  // Set default date to tomorrow
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  form.promised_date = tomorrow.toISOString().split('T')[0];
  
  form.notes = '';
  form.status = 'Pending';
  showModal.value = true;
};

const openEditModal = (item) => {
  isEditing.value = true;
  editingId.value = item.id;
  form.student_id = item.student_id;
  form.amount = item.amount;
  form.promised_date = item.promised_date;
  form.notes = item.notes;
  form.status = item.status;
  showModal.value = true;
};

const closeModal = () => {
  showModal.value = false;
};

const submitForm = async () => {
  if (!form.student_id || !form.promised_date || isSubmitting.value) return;
  isSubmitting.value = true;
  
  const payload = {
    student_id: form.student_id,
    amount: form.amount || 0,
    promised_date: form.promised_date,
    notes: form.notes,
    status: form.status,
  };

  try {
    if (isEditing.value) {
      const { error } = await supabase.from('payment_reminders').update(payload).eq('id', editingId.value);
      if (error) throw error;
    } else {
      const { error } = await supabase.from('payment_reminders').insert([payload]);
      if (error) throw error;
    }
    await loadData();
    closeModal();
  } catch (e) {
    console.error('Error saving reminder:', e);
    alert('Failed: Make sure payment_reminders table exists in Database!');
  } finally {
    isSubmitting.value = false;
  }
};

const changeStatus = async (item, newStatus) => {
  try {
    const { error } = await supabase.from('payment_reminders').update({ status: newStatus }).eq('id', item.id);
    if (error) throw error;
    item.status = newStatus;
  } catch (e) {
    console.error('Error changing status:', e);
  }
};

const showDeleteConfirm = ref(false);
const itemToDelete = ref(null);
const confirmDelete = (id) => {
  itemToDelete.value = id;
  showDeleteConfirm.value = true;
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
    console.error('Error deleting:', e);
  } finally {
    deletingId.value = null;
    itemToDelete.value = null;
  }
};

const isOverdue = (dateStr) => {
  if (!dateStr) return false;
  const today = new Date();
  today.setHours(0,0,0,0);
  const promiseDate = new Date(dateStr);
  return promiseDate < today;
};

const formatDate = (dateStr) => {
  if (!dateStr) return '-';
  const options = { day: '2-digit', month: 'short', year: 'numeric' };
  return new Date(dateStr).toLocaleDateString('en-GB', options);
};

const formatCurrency = (val) => {
  if (!val) return '0 UZS';
  return Number(val).toLocaleString() + ' UZS';
};

const getStatusClass = (status) => {
  if (status === 'Paid') return 'status-paid';
  if (status === 'Pending') return 'status-pending';
  return 'status-cancelled';
};
</script>

<template>
  <div class="reminders-page">
    <div class="page-header">
      <div class="header-info">
        <h1>{{ $t('sidebar.reminders') || 'Payment Reminders' }}</h1>
        <p>Track student promises and overdue payments</p>
      </div>
    </div>

    <!-- Stats summary -->
    <div class="reminders-stats">
      <div class="stat-mini card">
        <div class="stat-icon pending"><BellRing :size="20" /></div>
        <div class="stat-details">
          <span class="label">Kutilayotgan</span>
          <span class="value">{{ reminders.filter(r => r.status === 'Pending').length }}</span>
        </div>
      </div>
      <div class="stat-mini card">
        <div class="stat-icon overdue"><AlertTriangle :size="20" /></div>
        <div class="stat-details">
          <span class="label">Muddati o'tgan</span>
          <span class="value">{{ reminders.filter(r => r.status === 'Pending' && isOverdue(r.promised_date)).length }}</span>
        </div>
      </div>
      <div class="stat-mini card">
        <div class="stat-icon paid"><CheckCircle :size="20" /></div>
        <div class="stat-details">
          <span class="label">To'langan</span>
          <span class="value">{{ reminders.filter(r => r.status === 'Paid').length }}</span>
        </div>
      </div>
    </div>

    <div class="table-container card">
      <div class="table-header">
        <div class="search-box">
          <Search :size="18" />
          <input v-model="searchQuery" :placeholder="$t('common.searchPlaceholder') || 'Search...'" @input="currentPage = 1" />
        </div>
        <div class="filter-tabs">
          <button @click="activeTab = 'Guruhlar'" :class="['tab', { active: activeTab === 'Guruhlar' }]">Guruhlar</button>
          <button @click="activeTab = 'Talabalar'" :class="['tab', { active: activeTab === 'Talabalar' }]">Talabalar</button>
        </div>
      </div>

      <div class="table-scroll-wrapper">
        <table>
          <thead>
            <tr>
              <th>Talaba</th>
              <th>Guruh</th>
              <th>Miqdor</th>
              <th>Va'da qilingan sana</th>
              <th>Holat</th>
              <th>Izoh</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <template v-if="isLoading">
              <tr v-for="i in 5" :key="i">
                <td><div class="skeleton" style="width: 140px; height: 16px;"></div></td>
                <td><div class="skeleton" style="width: 100px; height: 16px;"></div></td>
                <td><div class="skeleton" style="width: 80px; height: 16px;"></div></td>
                <td><div class="skeleton" style="width: 120px; height: 16px;"></div></td>
                <td><div class="skeleton" style="width: 70px; height: 26px; border-radius: 8px;"></div></td>
                <td><div class="skeleton" style="width: 150px; height: 16px;"></div></td>
                <td></td>
              </tr>
            </template>
            <tr v-else-if="paginatedReminders.length === 0">
              <td colspan="7" class="no-data-card" style="padding: 4rem;">
                <BellRing :size="48" style="opacity: 0.5; margin-bottom: 1rem;" />
                <p>Eslatmalar topilmadi.</p>
              </td>
            </tr>
            <template v-else>
              <tr v-for="item in paginatedReminders" :key="item.id" :class="{ 'overdue-row': item.status === 'Pending' && isOverdue(item.promised_date) }">
                <td>
                  <div class="student-info">
                    <User :size="16" class="text-gray" />
                    <strong>{{ item.students?.name || 'Topilmadi' }}</strong>
                  </div>
                  <div v-if="item.students?.phone" class="sub-text">{{ item.students.phone }}</div>
                </td>
                <td>
                  <div class="group-info">
                    <Users :size="14" class="text-gray" />
                    {{ item.students?.groups?.name || 'Guruhsiz' }}
                  </div>
                </td>
                <td>
                  <div class="amount-val">{{ formatCurrency(item.amount) }}</div>
                </td>
                <td>
                  <div class="date-val" :class="{ 'text-danger': item.status === 'Pending' && isOverdue(item.promised_date) }">
                    <CalendarClock :size="14" />
                    {{ formatDate(item.promised_date) }}
                    <span v-if="item.status === 'Pending' && isOverdue(item.promised_date)" class="badge-danger">Muddati o'tgan</span>
                  </div>
                </td>
                <td>
                  <span class="status-badge" :class="getStatusClass(item.status)">{{ item.status === 'Pending' ? 'Kutilmoqda' : (item.status === 'Paid' ? 'To\'langan' : 'Bekor qilingan') }}</span>
                </td>
                <td>
                  <div class="notes-text" :title="item.notes">{{ item.notes || '-' }}</div>
                </td>
                <td>
                  <div class="actions-wrapper">
                    <button v-if="item.status === 'Pending'" class="btn-action-icon success" title="Mark as Paid" @click="changeStatus(item, 'Paid')">
                      <CheckCircle :size="18" />
                    </button>
                    <div class="dropdown-container">
                      <button class="btn-icon-more" @click="(e) => toggleDropdown('rem-' + item.id, e)">
                        <MoreVertical :size="20" />
                      </button>
                      <div v-if="activeDropdown === 'rem-' + item.id" class="dropdown-menu">
                        <button v-if="item.status !== 'Pending'" class="dropdown-item" @click="changeStatus(item, 'Pending')">
                          <AlertTriangle :size="16" /> Kutilmoqdaga qaytarish
                        </button>
                        <button v-if="item.status === 'Pending'" class="dropdown-item" @click="changeStatus(item, 'Cancelled')">
                          <XCircle :size="16" /> Bekor qilish
                        </button>
                        <div class="dropdown-divider"></div>
                        <button class="dropdown-item" @click="openEditModal(item)">
                          <Edit :size="16" /> Tahrirlash
                        </button>
                        <button class="dropdown-item danger" @click="confirmDelete(item.id)">
                          <Trash2 :size="16" /> O'chirish
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

      <div v-if="totalPages > 1" class="pagination-footer">
        <div class="pagination-info">
          {{ $t('common.showing') || 'Showing' }} 
          <b>{{ (currentPage - 1) * itemsPerPage + 1 }}-{{ Math.min(currentPage * itemsPerPage, filteredReminders.length) }}</b> 
          {{ $t('common.outOf') || 'out of' }} 
          <b>{{ filteredReminders.length }}</b>
        </div>
        <div class="pagination-controls">
          <button class="btn-page" :disabled="currentPage === 1" @click="setPage(currentPage - 1)">
            <ChevronLeft :size="18" />
          </button>
          <div class="page-numbers">
            <button 
              v-for="p in totalPages" 
              :key="p" 
              class="btn-number" 
              :class="{ active: currentPage === p }"
              @click="setPage(p)"
            >
              {{ p }}
            </button>
          </div>
          <button class="btn-page" :disabled="currentPage === totalPages" @click="setPage(currentPage + 1)">
            <ChevronRight :size="18" />
          </button>
        </div>
      </div>
    </div>

    <!-- Modal Form -->
    <transition name="modal">
      <div v-if="showModal" class="modal-overlay" @click.self="closeModal">
        <div class="modal-box">
          <div class="modal-header">
            <div class="title-with-icon">
              <div class="icon-bg primary"><BellRing :size="22" /></div>
              <h2>{{ isEditing ? 'Eslatmani tahrirlash' : 'Yangi eslatma yaratish' }}</h2>
            </div>
            <button class="btn-close" @click="closeModal"><X :size="20" /></button>
          </div>
          
          <div class="modal-body">
            <div class="form-group">
              <label>Talaba <span class="required">*</span></label>
              <select v-model="form.student_id">
                <option value="">Talabani tanlang...</option>
                <option v-for="s in students" :key="s.id" :value="s.id">{{ s.name }} <span v-if="s.groups">({{s.groups.name}})</span></option>
              </select>
            </div>
            
            <div class="form-row">
              <div class="form-group">
                <label>Va'da qilingan sana <span class="required">*</span></label>
                <input type="date" v-model="form.promised_date" />
              </div>
              <div class="form-group">
                <label>Miqdor (UZS)</label>
                <div class="input-with-icon">
                  <CreditCard :size="16" class="input-icon" />
                  <input type="number" v-model="form.amount" placeholder="Masalan: 400000" />
                </div>
              </div>
            </div>
            
            <div class="form-group">
              <label>Holati</label>
              <select v-model="form.status">
                <option value="Pending">Kutilmoqda</option>
                <option value="Paid">To'langan</option>
                <option value="Cancelled">Bekor qilingan</option>
              </select>
            </div>
            
            <div class="form-group">
              <label>Qo'shimcha izoh / Eslatmalar</label>
              <textarea v-model="form.notes" rows="3" placeholder="Talaba sabablari yoki qo'shimcha ma'lumotlar..."></textarea>
            </div>
          </div>
          
          <div class="modal-footer">
            <button class="btn-secondary" @click="closeModal">{{ $t('common.cancel') || 'Bekor qilish' }}</button>
            <button class="btn-primary-confirm" @click="submitForm" :disabled="isSubmitting || !form.student_id || !form.promised_date">
              <Loader2 v-if="isSubmitting" :size="18" class="spin" />
              <span v-else>{{ isEditing ? 'Saqlash' : 'Qo\'shish' }}</span>
            </button>
          </div>
        </div>
      </div>
    </transition>

    <!-- Delete Modal -->
    <transition name="modal">
      <div v-if="showDeleteConfirm" class="modal-overlay" @click.self="showDeleteConfirm = false">
        <div class="confirm-modal card text-center">
          <div class="confirm-icon"><AlertTriangle :size="48" style="color: var(--danger)" /></div>
          <h3>Ishonchingiz komilmi?</h3>
          <p class="text-gray" style="margin-bottom: 2rem;">Siz haqiqatdan ham ushbu eslatmani o'chirmokchimisiz?</p>
          <div class="confirm-actions">
            <button class="btn-secondary" @click="showDeleteConfirm = false">Bekor qilish</button>
            <button class="btn-danger-action" @click="deleteItem" :disabled="deletingId">
              <Loader2 v-if="deletingId" :size="18" class="spin" />
              <span v-else>To'liq o'chirish</span>
            </button>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<style scoped>
.reminders-page { padding: 2rem; background: var(--light); min-height: 100vh; }
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 2rem; }
.header-info h1 { font-size: 1.75rem; font-weight: 800; color: var(--dark); }
.header-info p { color: var(--gray); font-size: 0.95rem; margin-top: 4px; }

.btn-primary { background: var(--primary); color: white; padding: 0.75rem 1.5rem; border-radius: 12px; font-weight: 600; display: flex; align-items: center; gap: 0.5rem; transition: all 0.2s; }
.btn-primary:hover { transform: translateY(-2px); box-shadow: 0 4px 12px var(--primary-light); }

.reminders-stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1.5rem; margin-bottom: 2rem; }
.stat-mini { padding: 1.25rem; display: flex; align-items: center; gap: 1rem; border: none; box-shadow: var(--shadow); }
.stat-icon { width: 44px; height: 44px; border-radius: 12px; display: flex; align-items: center; justify-content: center; color: white; }
.stat-icon.pending { background: #FF9F43; } /* Warning Orng */
.stat-icon.overdue { background: #EA5455; } /* Danger Red */
.stat-icon.paid { background: #28C76F; }    /* Success Grn */

.stat-details .label { display: block; font-size: 0.75rem; color: var(--gray); font-weight: 700; text-transform: uppercase; }
.stat-details .value { font-size: 1.5rem; font-weight: 800; color: var(--dark); }

.table-container { background: white; border-radius: 20px; border: none; box-shadow: var(--shadow); padding: 0; }
.table-header { padding: 1.5rem; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; }
.search-box { display: flex; align-items: center; gap: 0.75rem; background: var(--light); padding: 0.6rem 1rem; border-radius: 12px; width: 300px; }
.search-box input { background: transparent; border: none; outline: none; width: 100%; font-size: 0.9rem; }
.filter-tabs { display: flex; background: var(--light); padding: 4px; border-radius: 10px; }
.tab { padding: 0.5rem 1rem; border-radius: 8px; font-size: 0.85rem; font-weight: 600; color: var(--gray); background: transparent; border: none; cursor: pointer; transition: all 0.2s; }
.tab.active { background: white; color: var(--dark); box-shadow: 0 2px 8px rgba(0,0,0,0.05); }

.table-scroll-wrapper { overflow-x: auto; min-height: 300px; padding-bottom: 80px; }
table { width: 100%; border-collapse: collapse; }
th { text-align: left; padding: 1rem 1.5rem; background: #fafafa; font-size: 0.85rem; font-weight: 700; color: var(--gray); text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid var(--border); }
td { padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--border); vertical-align: middle; }

.overdue-row { background: #FFF5F5 !important; }
.student-info { display: flex; align-items: center; gap: 6px; font-size: 0.95rem; color: var(--dark); }
.group-info, .date-val { display: flex; align-items: center; gap: 6px; font-size: 0.85rem; color: var(--gray); font-weight: 600; }
.amount-val { font-weight: 800; color: var(--dark); }
.sub-text { font-size: 0.8rem; color: var(--gray); margin-top: 4px; margin-left: 22px; }

.text-danger { color: #EA5455 !important; }
.badge-danger { background: #EA5455; color: white; padding: 2px 6px; border-radius: 6px; font-size: 0.65rem; font-weight: 800; margin-left: 8px; text-transform: uppercase; }

.status-badge { padding: 6px 14px; border-radius: 8px; font-size: 0.75rem; font-weight: 800; display: inline-block; }
.status-paid { background: #E8F5E9; color: #2E7D32; }
.status-pending { background: #FFF3E0; color: #E65100; }
.status-cancelled { background: #EEEEEE; color: #757575; }

.notes-text { max-width: 250px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-size: 0.85rem; color: var(--gray); }

.actions-wrapper { display: flex; align-items: center; justify-content: flex-end; gap: 8px; }
.btn-action-icon { width: 34px; height: 34px; border-radius: 10px; display: flex; align-items: center; justify-content: center; border: none; outline: none; cursor: pointer; transition: all 0.2s; }
.btn-action-icon.success { background: #E8F5E9; color: #28C76F; }
.btn-action-icon.success:hover { background: #28C76F; color: white; }

.dropdown-container { position: relative; }
.btn-icon-more { width: 34px; height: 34px; display: flex; align-items: center; justify-content: center; border-radius: 8px; border: none; background: transparent; color: var(--gray); cursor: pointer; }
.btn-icon-more:hover { background: var(--light); color: var(--dark); }
.dropdown-menu { position: absolute; top: 100%; right: 0; margin-top: 0.5rem; background: white; border: 1.5px solid var(--border); border-radius: 12px; padding: 0.5rem; min-width: 200px; z-index: 100; box-shadow: 0 10px 40px rgba(0, 0, 0, 0.1); }
.dropdown-item { width: 100%; display: flex; align-items: center; gap: 0.75rem; padding: 0.75rem 1rem; font-size: 0.85rem; font-weight: 600; border-radius: 8px; transition: all 0.2s; border: none; background: transparent; cursor: pointer; color: var(--dark); text-align: left; }
.dropdown-item:hover { background: var(--light); color: var(--primary); }
.dropdown-item.danger { color: var(--danger); }
.dropdown-item.danger:hover { background: #FFEBEE; }
.dropdown-divider { height: 1px; background: var(--border); margin: 6px; }

.pagination-footer { padding: 1.5rem; display: flex; justify-content: space-between; align-items: center; border-top: 1px solid var(--border); }
.pagination-info { font-size: 0.9rem; color: var(--gray); }
.pagination-info b { color: var(--dark); }
.pagination-controls { display: flex; align-items: center; gap: 1rem; }
.page-numbers { display: flex; gap: 0.5rem; }
.btn-page, .btn-number { width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; border-radius: 10px; border: 1px solid var(--border); background: white; font-weight: 600; color: var(--dark); transition: all 0.2s; cursor: pointer; }
.btn-page:not(:disabled):hover, .btn-number:not(.active):hover { border-color: var(--primary); color: var(--primary); }
.btn-number.active { background: var(--primary); color: white; border-color: var(--primary); }
.btn-page:disabled { opacity: 0.5; cursor: not-allowed; }
.no-data-card { text-align: center; color: var(--gray); }

/* Modal Styles */
.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.5); backdrop-filter: blur(4px); z-index: 1000; display: flex; align-items: center; justify-content: center; padding: 1rem; }
.modal-box { background: white; border-radius: 24px; width: 100%; max-width: 500px; box-shadow: 0 20px 60px rgba(0,0,0,0.2); }
.modal-header { padding: 1.5rem; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; }
.title-with-icon { display: flex; align-items: center; gap: 1rem; }
.icon-bg { width: 44px; height: 44px; border-radius: 12px; display: flex; align-items: center; justify-content: center; }
.icon-bg.primary { background: var(--primary-light); color: var(--primary); }
.modal-header h2 { font-size: 1.25rem; font-weight: 800; color: var(--dark); margin: 0; }
.btn-close { border: none; background: transparent; color: var(--gray); cursor: pointer; display: flex; padding: 4px; border-radius: 6px; }
.btn-close:hover { background: var(--light); color: var(--dark); }
.modal-body { padding: 1.5rem; }
.form-group { margin-bottom: 1.25rem; }
.form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
label { display: block; font-size: 0.85rem; font-weight: 700; color: var(--dark); margin-bottom: 6px; }
.required { color: var(--danger); }
input, select, textarea { width: 100%; padding: 0.75rem 1rem; border: 1.5px solid var(--border); border-radius: 12px; background: var(--light); outline: none; transition: all 0.2s; font-family: inherit; font-size: 0.95rem; }
input:focus, select:focus, textarea:focus { border-color: var(--primary); background: white; box-shadow: 0 0 0 4px var(--primary-light); }
.input-with-icon { position: relative; }
.input-with-icon .input-icon { position: absolute; left: 1rem; top: 50%; transform: translateY(-50%); color: var(--gray); }
.input-with-icon input { padding-left: 2.75rem; }
.modal-footer { padding: 1.5rem; background: #F8F9FA; display: flex; justify-content: flex-end; gap: 1rem; border-radius: 0 0 24px 24px; }
.btn-secondary { padding: 0.75rem 1.5rem; font-weight: 700; color: var(--gray); border-radius: 12px; border: none; background: transparent; cursor: pointer; }
.btn-primary-confirm { padding: 0.75rem 2rem; background: var(--primary); color: white; font-weight: 700; border-radius: 12px; border: none; display: flex; align-items: center; gap: 8px; cursor: pointer; transition: all 0.2s; }
.btn-primary-confirm:disabled { opacity: 0.6; cursor: not-allowed; }

.confirm-modal { padding: 2.5rem; max-width: 400px; border-radius: 24px; border: none; }
.confirm-icon { display: flex; justify-content: center; margin-bottom: 1rem; }
.confirm-modal h3 { font-size: 1.5rem; font-weight: 800; margin-bottom: 0.5rem; color: var(--dark); }
.confirm-actions { display: flex; gap: 1rem; }
.btn-danger-action { flex: 1; padding: 0.8rem; background: var(--danger); border: none; color: white; border-radius: 12px; font-weight: 700; cursor: pointer; display: flex; justify-content: center; }
.btn-secondary { background: var(--light); color: var(--gray); flex: 1; border-radius: 12px; }

.spin { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
.skeleton { background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%); background-size: 200% 100%; animation: skeleton-loading 1.5s infinite; border-radius: 4px; }
@keyframes skeleton-loading { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }
</style>
