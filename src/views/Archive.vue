<script setup>
import { 
  Plus, 
  Search, 
  Filter, 
  Trash2, 
  Archive, 
  RotateCcw, 
  CheckSquare, 
  Users, 
  CreditCard,
  Eye,
  X,
  MessageSquare,
  Send,
  GraduationCap,
  DoorOpen,
  AlertTriangle,
  Loader2,
  User,
  BookOpen,
  Layout,
  DollarSign,
  RefreshCcw
} from 'lucide-vue-next';
import { ref, computed, onMounted, reactive } from 'vue';
import { useI18n } from 'vue-i18n';
import { supabase } from '../supabase.js';

const { t } = useI18n();

const archivedItems = ref([]);
const isLoading = ref(true);
const searchQuery = ref('');
const activeFilter = ref('All');
const selectedItem = ref(null);
const showDetailsModal = ref(false);

const statusModal = reactive({
  show: false,
  type: 'success',
  title: '',
  message: ''
});

const showStatus = (type, title, message) => {
  statusModal.show = true;
  statusModal.type = type;
  statusModal.title = title;
  statusModal.message = message;
  if (type === 'success') {
    setTimeout(() => { statusModal.show = false; }, 3000);
  }
};

const showDeleteModal = ref(false);
const itemToDelete = ref(null);
const isDeletingPermanently = ref(false);
const restoringId = ref(null);

const loadArchives = async () => {
  isLoading.value = true;
  try {
    const [
      { data: students },
      { data: teachers },
      { data: groups },
      { data: tasks },
      { data: boards },
      { data: payments }
    ] = await Promise.all([
      supabase.from('students').select('*, groups(name)').eq('is_deleted', true),
      supabase.from('teachers').select('*').eq('is_deleted', true),
      supabase.from('groups').select('*, courses(name), teachers(name)').eq('is_deleted', true),
      supabase.from('tasks').select('*').eq('is_deleted', true),
      supabase.from('boards').select('*').eq('is_deleted', true),
      supabase.from('payments').select('*').eq('is_deleted', true)
    ]);

    const allItems = [
      ...(students || []).map(item => ({ ...item, type: 'student', archived_at: item.deleted_at })),
      ...(teachers || []).map(item => ({ ...item, type: 'teacher', archived_at: item.deleted_at })),
      ...(groups || []).map(item => ({ ...item, type: 'group', archived_at: item.deleted_at })),
      ...(tasks || []).map(item => ({ ...item, type: 'task', archived_at: item.deleted_at })),
      ...(boards || []).map(item => ({ ...item, type: 'board', archived_at: item.deleted_at })),
      ...(payments || []).map(item => ({ ...item, type: 'payment', archived_at: item.deleted_at, name: `Платеж ${item.receipt_id} (${item.amount} UZS)` }))
    ];

    archivedItems.value = allItems.sort((a, b) => new Date(b.archived_at) - new Date(a.archived_at));
  } catch (e) {
    console.error('Error loading archives:', e);
  } finally {
    isLoading.value = false;
  }
};

onMounted(loadArchives);

const typeFilters = ['All', 'Task', 'Group', 'Student', 'Teacher', 'Board', 'Payment'];

const stats = computed(() => {
  const s = {
    total: archivedItems.value.length,
    student: 0,
    teacher: 0,
    group: 0,
    task: 0,
    board: 0,
    payment: 0
  };
  archivedItems.value.forEach(item => {
    if (s[item.type] !== undefined) s[item.type]++;
  });
  return s;
});

const filteredArchives = computed(() => {
  let items = archivedItems.value;
  
  if (activeFilter.value !== 'All') {
    items = items.filter(item => item.type.toLowerCase() === activeFilter.value.toLowerCase());
  }
  
  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase();
    items = items.filter(item => {
      const name = (item.name || item.title || '').toLowerCase();
      return name.includes(q);
    });
  }
  
  return items;
});

const getTypeIcon = (type) => {
  switch (type.toLowerCase()) {
    case 'task': return CheckSquare;
    case 'group': return Users;
    case 'student': return User;
    case 'teacher': return GraduationCap;
    case 'board': return Layout;
    case 'payment': return DollarSign;
    default: return Archive;
  }
};

const getTypeColor = (type) => {
  switch (type.toLowerCase()) {
    case 'task': return '#7366FF';
    case 'group': return '#FF9F43';
    case 'student': return '#00CFE8';
    case 'teacher': return '#28C76F';
    case 'board': return '#EA5455';
    case 'payment': return '#FF6B6B';
    default: return '#4B465C';
  }
};

const getPriorityColor = (priority) => {
  if (!priority) return 'var(--gray)';
  switch (priority.toLowerCase()) {
    case 'high': return 'var(--danger)';
    case 'medium': return 'var(--warning)';
    case 'low': return 'var(--success)';
    default: return 'var(--gray)';
  }
};

const getItemTitle = (item) => {
  return item.name || item.title || item.id;
};

const formatDate = (dateStr) => {
  if (!dateStr) return '-';
  const date = new Date(dateStr);
  const locale = localStorage.getItem('userLanguage') === 'uz' ? 'uz-UZ' : 'ru-RU';
  return date.toLocaleString(locale, {
    day: '2-digit',
    month: 'long',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });
};

const openDetails = (item) => {
  selectedItem.value = item;
  showDetailsModal.value = true;
};

const closeDetails = () => {
  showDetailsModal.value = false;
  selectedItem.value = null;
};

const restoreItem = async (originalItem) => {
  if (restoringId.value) return;
  restoringId.value = originalItem.id;
  try {
    const tableName = 
      originalItem.type === 'task' ? 'tasks' : 
      (originalItem.type === 'teacher' ? 'teachers' : 
      (originalItem.type === 'group' ? 'groups' : 
      (originalItem.type === 'student' ? 'students' : 
      (originalItem.type === 'board' ? 'boards' : 
      (originalItem.type === 'payment' ? 'payments' : null)))));
    
    if (!tableName) throw new Error('Unknown item type');

    const { error } = await supabase
      .from(tableName)
      .update({ is_deleted: false, deleted_at: null })
      .eq('id', originalItem.id);

    if (error) throw error;
    
    archivedItems.value = archivedItems.value.filter(i => i.id !== originalItem.id);
    closeDetails();
    showStatus('success', t('common.success'), 'Запись успешно восстановлена');
  } catch (e) {
    console.error('Error restoring:', e);
    showStatus('error', t('common.error'), 'Не удалось восстановить запись');
  } finally {
    restoringId.value = null;
  }
};

const confirmPermanentDelete = (item) => {
  itemToDelete.value = item;
  showDeleteModal.value = true;
};

const permanentDelete = async () => {
  if (!itemToDelete.value || isDeletingPermanently.value) return;
  
  isDeletingPermanently.value = true;
  try {
    const tableName = 
      itemToDelete.value.type === 'task' ? 'tasks' : 
      (itemToDelete.value.type === 'teacher' ? 'teachers' : 
      (itemToDelete.value.type === 'group' ? 'groups' : 
      (itemToDelete.value.type === 'student' ? 'students' : 
      (itemToDelete.value.type === 'board' ? 'boards' : 
      (itemToDelete.value.type === 'payment' ? 'payments' : null)))));

    if (!tableName) throw new Error('Unknown item type');

    const { error } = await supabase
      .from(tableName)
      .delete()
      .eq('id', itemToDelete.value.id);

    if (error) throw error;

    archivedItems.value = archivedItems.value.filter(i => i.id !== itemToDelete.value.id);
    showDeleteModal.value = false;
    showStatus('success', t('common.delete'), t('common.success'));
  } catch (e) {
    console.error('Error deleting:', e);
    showStatus('error', t('common.error'), t('common.error'));
  } finally {
    isDeletingPermanently.value = false;
    itemToDelete.value = null;
  }
};

const showDeleteAllModal = ref(false);
const isDeletingAll = ref(false);
const showClearConfirm = ref(false);

const confirmDeleteAll = () => {
  showDeleteAllModal.value = true;
};

const deleteAll = async () => {
  if (isDeletingAll.value) return;
  isDeletingAll.value = true;
  try {
    await Promise.all([
      supabase.from('students').delete().eq('is_deleted', true),
      supabase.from('teachers').delete().eq('is_deleted', true),
      supabase.from('groups').delete().eq('is_deleted', true),
      supabase.from('tasks').delete().eq('is_deleted', true),
      supabase.from('boards').delete().eq('is_deleted', true),
      supabase.from('payments').delete().eq('is_deleted', true)
    ]);

    archivedItems.value = [];
    showDeleteAllModal.value = false;
    showStatus('success', 'Удалено', 'Архив полностью очищен');
  } catch (e) {
    console.error('Error deleting all:', e);
    showStatus('error', 'Ошибка', 'Не удалось очистить архив');
  } finally {
    isDeletingAll.value = true; // Wait, this should be false
    isDeletingAll.value = false;
  }
};

</script>

<template>
  <div class="archive-page">
    <div class="header-section">
      <div class="title-info">
        <h1>{{ $t('archive.title') }}</h1>
        <p class="subtitle">{{ $t('archive.subtitle') }}</p>
      </div>
      <button class="btn-clear" v-if="archivedItems.length > 0" @click="showClearConfirm = true">
        <Trash2 :size="18" />
        {{ $t('archive.clearConfirm') }}
      </button>
    </div>

    <!-- Statistics Grid -->
    <div class="stats-grid">
      <div class="stat-card" :class="{ active: activeFilter === 'All' }" @click="activeFilter = 'All'">
        <div class="stat-icon all"><Archive :size="20" /></div>
        <div class="stat-info">
          <span class="stat-label">{{ $t('archive.title') }}</span>
          <h2 class="stat-value">{{ archivedItems.length }}</h2>
        </div>
      </div>
      <div class="stat-card" :class="{ active: activeFilter === 'Student' }" @click="activeFilter = 'Student'">
        <div class="stat-icon student"><User :size="20" /></div>
        <div class="stat-info">
          <span class="stat-label">{{ $t('archive.student') }}</span>
          <h2 class="stat-value">{{ stats.student }}</h2>
        </div>
      </div>
      <div class="stat-card" :class="{ active: activeFilter === 'Teacher' }" @click="activeFilter = 'Teacher'">
        <div class="stat-icon teacher"><GraduationCap :size="20" /></div>
        <div class="stat-info">
          <span class="stat-label">{{ $t('archive.teacher') }}</span>
          <h2 class="stat-value">{{ stats.teacher }}</h2>
        </div>
      </div>
      <div class="stat-card" :class="{ active: activeFilter === 'Group' }" @click="activeFilter = 'Group'">
        <div class="stat-icon group"><Users :size="20" /></div>
        <div class="stat-info">
          <span class="stat-label">{{ $t('archive.group') }}</span>
          <h2 class="stat-value">{{ stats.group }}</h2>
        </div>
      </div>
      <div class="stat-card" :class="{ active: activeFilter === 'Task' }" @click="activeFilter = 'Task'">
        <div class="stat-icon task"><CheckSquare :size="20" /></div>
        <div class="stat-info">
          <span class="stat-label">{{ $t('archive.task') }}</span>
          <h2 class="stat-value">{{ stats.task }}</h2>
        </div>
      </div>
      <div class="stat-card" :class="{ active: activeFilter === 'Payment' }" @click="activeFilter = 'Payment'">
        <div class="stat-icon revenue"><DollarSign :size="20" /></div>
        <div class="stat-info">
          <span class="stat-label">{{ $t('archive.payment') }}</span>
          <h2 class="stat-value">{{ stats.payment }}</h2>
        </div>
      </div>
    </div>

    <!-- Filters & Search -->
    <div class="filter-bar">
      <div class="search-box">
        <Search :size="20" />
        <input type="text" v-model="searchQuery" :placeholder="$t('archive.searchPlaceholder')" />
      </div>
    </div>

    <!-- Archive List -->
    <div class="table-container card">
      <div class="table-scroll-wrapper">
        <table>
          <thead>
            <tr>
              <th>{{ $t('archive.type') }}</th>
              <th>{{ $t('archive.contentTitle') }}</th>
              <th>{{ $t('archive.archivedAt') }}</th>
              <th class="text-right">{{ $t('archive.actions') }}</th>
            </tr>
          </thead>
          <tbody>
            <!-- Loading State -->
            <template v-if="isLoading">
              <tr v-for="i in 5" :key="i">
                <td :data-label="$t('archive.type')">
                  <div class="skeleton" style="width: 90px; height: 26px; border-radius: 8px;"></div>
                </td>
                <td :data-label="$t('archive.contentTitle')">
                  <div class="skeleton" style="width: 200px; height: 18px; margin-bottom: 6px;"></div>
                  <div class="skeleton" style="width: 120px; height: 12px;"></div>
                </td>
                <td :data-label="$t('archive.archivedAt')">
                  <div class="skeleton" style="width: 140px; height: 16px;"></div>
                </td>
                <td class="actions-col" :data-label="$t('archive.actions')">
                  <div style="display: flex; gap: 8px; justify-content: flex-end;">
                    <div class="skeleton" style="width: 32px; height: 32px; border-radius: 8px;"></div>
                    <div class="skeleton" style="width: 32px; height: 32px; border-radius: 8px;"></div>
                  </div>
                </td>
              </tr>
            </template>

            <!-- Empty State -->
            <tr v-else-if="filteredArchives.length === 0">
              <td colspan="4" class="empty-state">
                <div class="empty-content">
                  <Archive :size="48" />
                  <p>{{ $t('archive.noItems') }}</p>
                </div>
              </td>
            </tr>

            <!-- Real Data -->
            <template v-else>
              <tr v-for="item in filteredArchives" :key="item.id">
                <td :data-label="$t('archive.type')">
                  <div class="type-tag" :style="{ color: getTypeColor(item.type), backgroundColor: getTypeColor(item.type) + '15' }">
                    <component :is="getTypeIcon(item.type)" :size="14" />
                    {{ item.type.toUpperCase() }}
                  </div>
                </td>
                <td :data-label="$t('archive.contentTitle')">
                  <span class="item-title">{{ getItemTitle(item) }}</span>
                </td>
                <td :data-label="$t('archive.archivedAt')">
                  <span class="archived-date">{{ formatDate(item.archived_at) }}</span>
                </td>
                <td class="actions-col" :data-label="$t('archive.actions')">
                  <div class="action-buttons">
                    <button class="btn-action view" @click="openDetails(item)" title="View Details">
                      <Eye :size="16" />
                    </button>
                    <button class="btn-action delete" @click="confirmPermanentDelete(item)" title="Permanent Delete" :disabled="isDeletingPermanently && itemToDelete?.id === item.id">
                      <Loader2 v-if="isDeletingPermanently && itemToDelete?.id === item.id" :size="16" class="spin" />
                      <Trash2 v-else :size="16" />
                    </button>
                  </div>
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Details Modal -->
    <transition name="modal">
      <div v-if="showDetailsModal && selectedItem" class="modal-overlay" @click.self="closeDetails">
        <div class="modal-box details-modal">
          <div class="modal-header">
            <h2 class="header-title">{{ $t('archive.detailsTitle') }}</h2>
            <button class="btn-icon" @click="closeDetails"><X :size="20" /></button>
          </div>
          
          <div class="modal-content">
            <div class="details-layout">
              <div class="main-info">
                <!-- Generic Field List based on type -->
                <div v-if="selectedItem.type === 'student'" class="fields-grid">
                  <div class="field">
                    <span class="field-label">{{ $t('archive.fields.name') }}</span>
                    <p class="field-value">{{ selectedItem.name }}</p>
                  </div>
                  <div class="field">
                    <span class="field-label">{{ $t('archive.fields.phone') }}</span>
                    <p class="field-value">{{ selectedItem.phone || '-' }}</p>
                  </div>
                  <div class="field">
                    <span class="field-label">{{ $t('archive.fields.group') }}</span>
                    <p class="field-value">{{ selectedItem.groups?.name || '-' }}</p>
                  </div>
                  <div class="field">
                    <span class="field-label">{{ $t('archive.fields.status') }}</span>
                    <p class="field-value">{{ selectedItem.status || '-' }}</p>
                  </div>
                </div>

                <div v-else-if="selectedItem.type === 'payment'" class="fields-grid">
                  <div class="field">
                    <span class="field-label">{{ $t('archive.fields.student') }}</span>
                    <p class="field-value">{{ selectedItem.student }}</p>
                  </div>
                  <div class="field">
                    <span class="field-label">{{ $t('archive.fields.amount') }}</span>
                    <p class="field-value amount-highlight">{{ selectedItem.amount.toLocaleString() }} UZS</p>
                  </div>
                  <div class="field">
                    <span class="field-label">{{ $t('archive.fields.type') }}</span>
                    <p class="field-value">{{ selectedItem.type === 'refund' ? $t('archive.fields.refund') : $t('archive.fields.payment') }}</p>
                  </div>
                  <div class="field">
                    <span class="field-label">{{ $t('archive.fields.method') }}</span>
                    <p class="field-value">{{ selectedItem.method }}</p>
                  </div>
                  <div class="field">
                    <span class="field-label">{{ $t('archive.fields.month') }}</span>
                    <p class="field-value">{{ selectedItem.month }}</p>
                  </div>
                </div>

                <div v-else class="fields-grid">
                  <div class="field">
                    <span class="field-label">{{ $t('archive.fields.name') }}</span>
                    <p class="field-value">{{ selectedItem.name || selectedItem.title }}</p>
                  </div>
                  <div class="field">
                    <span class="field-label">{{ $t('archive.type') }}</span>
                    <p class="field-value">{{ selectedItem.type }}</p>
                  </div>
                </div>
              </div>
              
              <div class="side-panel">
                <div class="panel-section">
                  <h3 class="section-title"><MessageSquare :size="16" /> {{ $t('archive.history') }}</h3>
                  <div class="empty-state">
                    <MessageSquare :size="32" />
                    <span>{{ $t('archive.noComments') }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
          
          <div class="modal-footer">
             <div class="footer-info">
               <AlertTriangle :size="16" />
               <span>{{ $t('archive.readOnly') }}</span>
             </div>
             <div class="footer-actions">
               <button class="btn-secondary" @click="closeDetails">{{ $t('common.cancel') }}</button>
               <button class="btn-primary" @click="restoreItem(selectedItem)">
                 <RefreshCcw :size="18" />
                 {{ $t('archive.restoreTo', { type: selectedItem.type }) }}
               </button>
             </div>
          </div>
        </div>
      </div>
    </transition>

    <!-- Permanent Delete Confirmation Modal -->
    <transition name="modal">
      <div v-if="showDeleteModal" class="modal-overlay" @click.self="showDeleteModal = false">
        <div class="modal-box confirm-modal">
          <div class="confirm-content">
            <div class="confirm-icon danger">
              <Trash2 :size="32" />
            </div>
            <h2>{{ $t('common.areYouSure') }}</h2>
            <p>{{ $t('archive.deleteConfirm') }}</p>
          </div>
          <div class="confirm-actions">
            <button class="btn-secondary" @click="showDeleteModal = false">{{ $t('common.cancel') }}</button>
            <button class="btn-danger" @click="permanentDelete" :disabled="isDeletingPermanently">
              <Loader2 v-if="isDeletingPermanently" class="animate-spin" :size="18" />
              <span v-else>{{ $t('common.delete') }}</span>
            </button>
          </div>
        </div>
      </div>
    </transition>

    <!-- Clear Confirmation Modal -->
    <div v-if="showClearConfirm" class="modal-overlay">
      <div class="modal-box confirm-modal">
        <div class="confirm-content">
          <div class="confirm-icon danger">
            <AlertTriangle :size="32" />
          </div>
          <h2>{{ $t('archive.clearTitle') }}</h2>
          <p>{{ $t('archive.clearWarning') }}</p>
        </div>
        <div class="confirm-actions">
          <button class="btn-secondary" @click="showClearConfirm = false">
            {{ $t('archive.clearCancel') }}
          </button>
          <button class="btn-danger" @click="clearArchive" :disabled="isDeletingAll">
            <Loader2 v-if="isDeletingAll" class="animate-spin" :size="18" />
            <span v-else>{{ $t('archive.clearConfirm') }}</span>
          </button>
        </div>
      </div>
    </div>

    <!-- Final Status Modal (Success/Error) -->
    <transition name="modal">
      <div v-if="statusModal.show" class="modal-overlay" @click.self="statusModal.show = false">
        <div class="modal-box status-msg-modal">
          <div class="modal-body text-center p-2.5rem">
            <div class="status-icon-circle" :class="statusModal.type">
              <CheckSquare v-if="statusModal.type === 'success'" :size="48" />
              <AlertTriangle v-else :size="48" />
            </div>
            <h2 class="status-title">{{ statusModal.title }}</h2>
            <p class="status-desc">{{ statusModal.message }}</p>
            <button class="btn-status-close" :class="statusModal.type" @click="statusModal.show = false">
              OK
            </button>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<style scoped>
.archive-page {
  padding: 2rem;
  background: var(--light);
  min-height: 100%;
}

.page-header {
  margin-bottom: 2rem;
}

.header-content h1 {
  font-size: 1.75rem;
  font-weight: 800;
  color: var(--dark);
}

.archive-filters {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.5rem;
  gap: 1.5rem;
}

.search-bar {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  background: white;
  padding: 0.75rem 1.25rem;
  border-radius: 12px;
  box-shadow: var(--shadow);
  flex: 1;
  max-width: 400px;
}

.search-bar input {
  border: none;
  outline: none;
  width: 100%;
  font-size: 0.95rem;
}

.type-tabs {
  display: flex;
  background: white;
  padding: 0.4rem;
  border-radius: 12px;
  box-shadow: var(--shadow);
  gap: 0.25rem;
}

.tab {
  padding: 0.5rem 1.25rem;
  border-radius: 8px;
  font-size: 0.9rem;
  font-weight: 600;
  color: var(--gray);
  transition: all 0.2s;
}

.tab:hover {
  background: var(--light);
  color: var(--dark);
}

.tab.active {
  background: var(--primary);
  color: white;
}

.table-container {
  overflow: hidden;
}

.table-scroll-wrapper {
  overflow-x: auto;
}

table {
  width: 100%;
  border-collapse: collapse;
}

th {
  text-align: left;
  padding: 1rem 1.5rem;
  background: #f8f9fa;
  color: var(--gray);
  font-size: 0.85rem;
  font-weight: 700;
  text-transform: uppercase;
}

td {
  padding: 1.25rem 1.5rem;
  border-bottom: 1px solid var(--border);
  vertical-align: middle;
}

.type-tag {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.4rem 0.8rem;
  border-radius: 8px;
  font-size: 0.72rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.tag-priority {
  color: white;
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.35rem 0.8rem;
  border-radius: 8px;
  font-size: 0.75rem;
  font-weight: 700;
}

.dot-small {
  width: 6px;
  height: 6px;
  background: white;
  border-radius: 50%;
}

.item-title {
  font-weight: 600;
  color: var(--dark);
}

.archived-date {
  font-size: 0.85rem;
  color: var(--gray);
}

.original-id {
  font-size: 0.85rem;
  color: var(--primary);
  background: var(--primary-light);
  padding: 0.2rem 0.5rem;
  border-radius: 4px;
}

/* Statistics Grid */
.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
  gap: 1rem;
  margin-bottom: 2rem;
}

.stat-card {
  background: white;
  padding: 1.25rem;
  border-radius: 16px;
  box-shadow: var(--shadow);
  display: flex;
  align-items: center;
  gap: 1rem;
  cursor: pointer;
  transition: all 0.3s;
  border: 2px solid transparent;
}

.stat-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 25px rgba(0,0,0,0.1);
}

.stat-card.active {
  border-color: var(--primary);
  background: var(--primary-light);
}

.stat-icon {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.stat-icon.all { background: rgba(75, 70, 92, 0.1); color: #4B465C; }
.stat-icon.student { background: rgba(0, 207, 232, 0.1); color: #00CFE8; }
.stat-icon.teacher { background: rgba(40, 199, 111, 0.1); color: #28C76F; }
.stat-icon.group { background: rgba(255, 159, 67, 0.1); color: #FF9F43; }
.stat-icon.task { background: rgba(115, 102, 255, 0.1); color: #7366FF; }
.stat-icon.revenue { background: rgba(115, 102, 255, 0.1); color: var(--primary); }

.confirm-modal {
  max-width: 400px;
  padding: 2.5rem;
  text-align: center;
}

.confirm-content {
  margin-bottom: 2rem;
}

.confirm-icon {
  width: 64px;
  height: 64px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 1.5rem;
}

.confirm-icon.danger {
  background: #FFF5F5;
  color: var(--danger);
}

.confirm-content h2 {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--dark);
  margin-bottom: 0.75rem;
}

.confirm-content p {
  color: var(--gray);
  line-height: 1.5;
}

.confirm-actions {
  display: flex;
  gap: 1rem;
}

.confirm-actions button {
  flex: 1;
  padding: 0.75rem;
}

.stat-label {
  font-size: 0.75rem;
  color: var(--gray);
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.stat-value {
  font-size: 1.25rem;
  font-weight: 800;
  color: var(--dark);
  line-height: 1.2;
}

.actions-col {
  text-align: right;
  width: 150px;
}

.action-buttons {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
}

.btn-action {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
}

.btn-action.view { color: var(--primary); background: var(--primary-light); }
.btn-action.restore { color: var(--success); background: #e8f9ee; }
.btn-action.delete { color: var(--danger); background: #fff5f5; }

.btn-action:hover {
  transform: translateY(-2px);
  filter: brightness(0.95);
}

.empty-state {
  padding: 5rem 0 !important;
  text-align: center;
}

.empty-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  color: var(--gray);
}

.empty-content p {
  font-weight: 600;
}

/* Modal specific */
.archive-details-box {
  max-width: 900px;
  width: 95%;
  background: white;
  border-radius: 24px;
  overflow: hidden;
}

.td-layout {
  display: flex;
  height: 80vh;
}

.td-left {
  flex: 1.2;
  border-right: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  background: white;
}

.td-right {
  flex: 0.8;
  background: #fdfdfd;
  display: flex;
  flex-direction: column;
}

.modal-header {
  padding: 1.5rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.modal-header h3 {
  font-size: 1.25rem;
  font-weight: 800;
  color: var(--dark);
}

.modal-header.no-border {
  border-bottom: none;
}

.modal-body { padding: 1.5rem; }
.p-2rem { padding: 2rem; }
.p-2\.5rem { padding: 2.5rem; }
.text-center { text-align: center; }

.td-right-header {
  padding: 1.5rem;
  border-bottom: 1px solid var(--border);
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.td-right-header .header-title {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  color: var(--dark);
}

.td-right-header h3 {
  font-size: 1.1rem;
  font-weight: 700;
}

.comments-list {
  flex: 1;
  padding: 1.5rem;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}

.comment-item {
  display: flex;
  gap: 1rem;
}

.comment-avatar {
  width: 36px;
  height: 36px;
  background: var(--primary-light);
  color: var(--primary);
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  flex-shrink: 0;
}

.comment-content {
  flex: 1;
}

.comment-top {
  display: flex;
  justify-content: space-between;
  margin-bottom: 0.25rem;
}

.comment-author {
  font-weight: 700;
  font-size: 0.9rem;
  color: var(--dark);
}

.comment-time {
  font-size: 0.75rem;
  color: var(--gray);
}

.comment-text {
  font-size: 0.9rem;
  color: var(--gray);
  line-height: 1.5;
}

.no-comments {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: var(--border);
  gap: 0.75rem;
}

.no-comments p {
  font-size: 0.9rem;
  color: var(--gray);
}

.archive-note {
  padding: 1.25rem;
  background: var(--light);
  border-top: 1px solid var(--border);
  text-align: center;
}

.archive-note p {
  font-size: 0.8rem;
  color: var(--gray);
  font-weight: 600;
}

.td-close-mobile { display: none; }

/* Mobile responsiveness */
@media (max-width: 768px) {
  .details-layout { grid-template-columns: 1fr; }
  .main-info { border-right: none; border-bottom: 1px solid var(--border); }
}

.search-box {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  background: white;
  padding: 0.75rem 1.25rem;
  border-radius: 14px;
  box-shadow: 0 2px 10px rgba(0,0,0,0.03);
  flex: 1;
  max-width: 400px;
  border: 1px solid var(--border);
  margin-bottom: 0.5rem;
}

.search-box input {
  border: none;
  background: transparent;
  width: 100%;
  font-weight: 600;
  color: var(--dark);
  outline: none;
}

.search-box input::placeholder {
  color: #B2B2B2;
}

.amount-highlight {
  color: var(--primary);
  font-size: 1.15rem;
  font-weight: 800;
}

.details-layout {
  display: grid;
  grid-template-columns: 1fr 300px;
  min-height: 400px;
}

.main-info {
  padding: 2rem;
  border-right: 1px solid var(--border);
}

.side-panel {
  padding: 1.5rem;
  background: #FAFBFF;
}

.fields-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 2rem;
}

.field-label {
  display: block;
  font-size: 0.75rem;
  font-weight: 800;
  text-transform: uppercase;
  color: var(--gray);
  margin-bottom: 0.5rem;
  letter-spacing: 0.5px;
}

.field-value {
  font-size: 1rem;
  font-weight: 600;
  color: var(--dark);
}

.panel-section .section-title {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.9rem;
  font-weight: 700;
  color: var(--dark);
  margin-bottom: 1rem;
}

.modal-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 1rem;
  padding: 1.5rem 2rem;
  border-top: 1px solid var(--border);
  background: #fdfdfd;
}

.footer-actions {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.btn-primary {
  background: linear-gradient(135deg, var(--primary) 0%, #5a4bd3 100%);
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 12px;
  font-weight: 700;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  box-shadow: 0 4px 15px rgba(115, 102, 255, 0.25);
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  cursor: pointer;
}

.btn-primary:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 20px rgba(115, 102, 255, 0.35);
  filter: brightness(1.1);
}

.btn-primary:active {
  transform: translateY(0);
}

.btn-secondary {
  background: white;
  color: var(--gray);
  border: 1.5px solid var(--border);
  padding: 0.75rem 1.5rem;
  border-radius: 12px;
  font-weight: 700;
  transition: all 0.2s;
  cursor: pointer;
}

.btn-secondary:hover {
  background: #f8f9fa;
  color: var(--dark);
  border-color: var(--gray);
}

.footer-info {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: var(--gray);
  font-size: 0.85rem;
  font-weight: 600;
}

.header-section {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 2rem;
}

.subtitle {
  color: var(--gray);
  font-weight: 600;
  margin-top: 0.25rem;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 1rem;
  padding: 1.5rem;
  border-top: 1px solid var(--border);
}

.filter-chips {
  display: flex;
  gap: 0.8rem;
  flex-wrap: wrap;
  margin-top: 1rem;
}

.chip {
  padding: 0.5rem 1.25rem;
  border-radius: 8px;
  background: white;
  border: 1px solid var(--border);
  color: var(--gray);
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  display: inline-flex;
  align-items: center;
}

.chip.active {
  background: var(--primary);
  color: white;
  border-color: var(--primary);
}

.btn-outline {
  padding: 0.75rem 1.5rem;
  border: 1.5px solid var(--border);
  border-radius: 10px;
  font-weight: 600;
}

/* --- Status & Confirm Modals --- */
.status-msg-modal { max-width: 400px; background: white; border-radius: 30px; overflow: hidden; padding: 1rem; }
.status-icon-circle { width: 90px; height: 90px; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 1.5rem; }
.status-icon-circle.success { background: #e8f9ee; color: var(--success); }
.status-icon-circle.error { background: #fff5f5; color: var(--danger); }
.status-title { font-size: 1.6rem; font-weight: 800; color: var(--dark); margin-bottom: 0.5rem; text-align: center; }
.status-desc { color: var(--gray); font-weight: 600; margin-bottom: 2rem; line-height: 1.5; padding: 0 1rem; text-align: center; }
.btn-status-close { width: 100%; padding: 1rem; border-radius: 14px; font-weight: 700; color: white; transition: all 0.2s; font-size: 1rem; }
.btn-status-close.success { background: var(--success); box-shadow: 0 4px 12px rgba(40, 199, 111, 0.3); }
.btn-status-close.error { background: var(--danger); box-shadow: 0 4px 12px rgba(234, 84, 85, 0.3); }
.btn-status-close:hover { transform: translateY(-2px); opacity: 0.9; }

.confirm-modal-small { max-width: 420px; background: white; border-radius: 28px; overflow: hidden; }
.confirm-icon-large { width: 88px; height: 88px; margin: 0 auto 1.5rem; border-radius: 50%; display: flex; align-items: center; justify-content: center; }
.confirm-icon-large.danger { background: #fff5f5; color: var(--danger); }
.confirm-title { font-size: 1.6rem; font-weight: 800; color: var(--dark); margin-bottom: 0.75rem; text-align: center; }
.confirm-desc { color: var(--gray); font-weight: 600; text-align: center; margin-bottom: 2rem; line-height: 1.5; }
.confirm-actions { display: flex; gap: 1.25rem; padding: 0 1rem; margin-bottom: 1rem; }
.btn-cancel-action { flex: 1; padding: 1rem; border-radius: 14px; background: var(--light); color: var(--gray); font-weight: 700; transition: all 0.2s; }
.btn-danger-confirm-action { flex: 1; padding: 1rem; border-radius: 14px; background: var(--danger); color: white; font-weight: 700; transition: all 0.2s; display: flex; align-items: center; justify-content: center; gap: 0.5rem; box-shadow: 0 4px 12px rgba(234, 84, 85, 0.3); }
.btn-danger-confirm-action:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(234, 84, 85, 0.4); }

.spin { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }

.skeleton { background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%); background-size: 200% 100%; animation: skeleton-loading 1.5s infinite; }
@keyframes skeleton-loading { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }

/* Global Modal Styles */
.modal-overlay { 
  position: fixed; 
  top: 0; 
  left: 0; 
  right: 0; 
  bottom: 0; 
  background: rgba(0, 0, 0, 0.5); 
  display: flex; 
  align-items: center; 
  justify-content: center; 
  z-index: 10000; 
  backdrop-filter: blur(4px); 
}
.modal-box { background: white; border-radius: 20px; box-shadow: var(--shadow); }

.modal-enter-active, .modal-leave-active { transition: opacity 0.3s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
</style>
