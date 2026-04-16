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
  BookOpen
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
const itemToDeleteId = ref(null);
const isDeletingPermanently = ref(false);
const restoringId = ref(null);

const loadArchives = async () => {
  isLoading.value = true;
  try {
    const { data, error } = await supabase
      .from('archives')
      .select('*')
      .order('archived_at', { ascending: false });
    
    if (error) throw error;
    archivedItems.value = data;
  } catch (e) {
    console.error('Error loading archives:', e);
  } finally {
    isLoading.value = false;
  }
};

onMounted(loadArchives);

const typeFilters = ['All', 'Task', 'Lead', 'Payment', 'Teacher', 'Room', 'Group', 'Student', 'Course'];

const filteredArchives = computed(() => {
  let items = archivedItems.value;
  
  if (activeFilter.value !== 'All') {
    items = items.filter(item => item.type.toLowerCase() === activeFilter.value.toLowerCase());
  }
  
  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase();
    items = items.filter(item => {
      const dataStr = JSON.stringify(item.data).toLowerCase();
      return dataStr.includes(q);
    });
  }
  
  return items;
});

const getTypeIcon = (type) => {
  switch (type.toLowerCase()) {
    case 'task': return CheckSquare;
    case 'lead': return Users;
    case 'payment': return CreditCard;
    case 'teacher': return GraduationCap;
    case 'room': return DoorOpen;
    case 'group': return Users;
    case 'student': return User;
    case 'course': return BookOpen;
    default: return Archive;
  }
};

const getTypeColor = (type) => {
  switch (type.toLowerCase()) {
    case 'task': return '#7366FF';
    case 'lead': return '#FF9F43';
    case 'payment': return '#28C76F';
    case 'teacher': return '#4F46E5';
    case 'room': return '#F59E0B';
    case 'group': return '#7366FF';
    case 'student': return '#00CFE8';
    case 'course': return '#9E5CF2';
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
  const d = item.data;
  if (item.type === 'task') return d.title;
  if (item.type === 'lead') return d.name;
  if (item.type === 'payment') return `${d.student} - ${d.amount} UZS`;
  if (item.type === 'teacher') return d.name;
  if (item.type === 'room') return d.name;
  if (item.type === 'group') return d.name;
  if (item.type === 'student') return d.name;
  if (item.type === 'course') return d.name;
  return item.original_id;
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

const restoreItem = async (item) => {
  if (restoringId.value) return;
  restoringId.value = item.id;
  try {
    const tableName = 
      item.type === 'task' ? 'tasks' : 
      (item.type === 'lead' ? 'leads' : 
      (item.type === 'payment' ? 'payments' : 
      (item.type === 'teacher' ? 'teachers' : 
      (item.type === 'group' ? 'groups' : 
      (item.type === 'student' ? 'students' : 
      (item.type === 'course' ? 'courses' : 'rooms'))))));
    
    const restoreData = { ...item.data };
    
    // Clean data from fields that might not exist in the target table or should be fresh
    delete restoreData.created_at;
    delete restoreData.updated_at;
    
    // Remove any nested objects that are results of JOINs (e.g., d.teachers, d.courses)
    // but keep arrays like 'comments_list' if they are supposed to be there
    Object.keys(restoreData).forEach(key => {
      const val = restoreData[key];
      if (val && typeof val === 'object' && !Array.isArray(val)) {
        delete restoreData[key];
      }
    });

    const { error: restoreError } = await supabase.from(tableName).insert([restoreData]);
    if (restoreError) throw restoreError;
    
    const { error: deleteError } = await supabase.from('archives').delete().eq('id', item.id);
    if (deleteError) throw deleteError;
    
    archivedItems.value = archivedItems.value.filter(i => i.id !== item.id);
    closeDetails();
    showStatus('success', t('common.success'), t('archive.restoreSuccess', { type: t('archive.' + item.type) }));
  } catch (e) {
    console.error('Error restoring:', e);
    showStatus('error', t('common.error'), t('archive.restoreFail'));
  } finally {
    restoringId.value = null;
  }
};

const confirmPermanentDelete = (id) => {
  itemToDeleteId.value = id;
  showDeleteModal.value = true;
};

const permanentDelete = async () => {
  if (!itemToDeleteId.value || isDeletingPermanently.value) return;
  
  isDeletingPermanently.value = true;
  try {
    const { error } = await supabase.from('archives').delete().eq('id', itemToDeleteId.value);
    if (error) throw error;
    archivedItems.value = archivedItems.value.filter(i => i.id !== itemToDeleteId.value);
    showDeleteModal.value = false;
    showStatus('success', t('common.delete'), t('common.success'));
  } catch (e) {
    console.error('Error deleting:', e);
    showStatus('error', t('common.error'), t('common.error'));
  } finally {
    isDeletingPermanently.value = false;
    itemToDeleteId.value = null;
  }
};

</script>

<template>
  <div class="archive-page">
    <div class="page-header">
      <div class="header-content">
        <h1>{{ $t('archive.title') }}</h1>
        <p>{{ $t('archive.subtitle') }}</p>
      </div>
    </div>

    <!-- Filters Section -->
    <div class="archive-filters">
      <div class="search-bar">
        <Search :size="18" />
        <input v-model="searchQuery" type="text" :placeholder="$t('archive.searchPlaceholder')" />
      </div>
      
      <div class="type-tabs">
        <button 
          v-for="t in typeFilters" 
          :key="t"
          :class="['tab', { active: activeFilter === t }]"
          @click="activeFilter = t"
        >
          {{ t === 'All' ? $t('common.all') : $t('archive.' + t.toLowerCase()) }}
        </button>
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
              <th>{{ $t('archive.originalId') }}</th>
              <th class="actions-col">{{ $t('archive.actions') }}</th>
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
                <td :data-label="$t('archive.originalId')">
                  <div class="skeleton" style="width: 90px; height: 16px; border-radius: 4px;"></div>
                </td>
                <td class="actions-col" :data-label="$t('archive.actions')">
                  <div style="display: flex; gap: 8px; justify-content: flex-end;">
                    <div class="skeleton" style="width: 32px; height: 32px; border-radius: 8px;"></div>
                    <div class="skeleton" style="width: 32px; height: 32px; border-radius: 8px;"></div>
                    <div class="skeleton" style="width: 32px; height: 32px; border-radius: 8px;"></div>
                  </div>
                </td>
              </tr>
            </template>

            <!-- Empty State -->
            <tr v-else-if="filteredArchives.length === 0">
              <td colspan="5" class="empty-state">
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
                <td :data-label="$t('archive.originalId')">
                  <code class="original-id">{{ item.original_id }}</code>
                </td>
                <td class="actions-col" :data-label="$t('archive.actions')">
                  <div class="action-buttons">
                    <button class="btn-action view" @click="openDetails(item)" title="View Details">
                      <Eye :size="16" />
                    </button>
                    <button class="btn-action restore" @click="restoreItem(item)" title="Restore" :disabled="restoringId === item.id">
                      <Loader2 v-if="restoringId === item.id" :size="16" class="spin" />
                      <RotateCcw v-else :size="16" />
                    </button>
                    <button class="btn-action delete" @click="confirmPermanentDelete(item.id)" title="Permanent Delete" :disabled="isDeletingPermanently && itemToDeleteId === item.id">
                      <Loader2 v-if="isDeletingPermanently && itemToDeleteId === item.id" :size="16" class="spin" />
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
        <div class="modal-box archive-details-box">
          <div class="td-layout">
            <!-- Left Side: Details -->
            <div class="td-left">
              <div class="modal-header no-border">
                <h3>{{ $t('archive.detailsTitle', { type: selectedItem.type }) }}</h3>
                <button class="btn-icon td-close-mobile" @click="closeDetails"><X :size="20" /></button>
              </div>
              
              <div class="details-grid">
                <template v-if="selectedItem.type.toLowerCase() === 'task'">
                  <div class="detail-item">
                    <label>{{ $t('tasks.taskTitle') || 'Title' }}</label>
                    <p class="value">{{ selectedItem.data.title }}</p>
                  </div>
                  <div class="detail-item">
                    <label>{{ $t('tasks.description') || 'Description' }}</label>
                    <p class="value note">{{ selectedItem.data.description || $t('tasks.noDescription') }}</p>
                  </div>
                  <div class="detail-row">
                    <div class="detail-item">
                    <label>{{ $t('tasks.priority') || 'Priority' }}</label>
                    <span class="tag tag-priority" :style="{ backgroundColor: getPriorityColor(selectedItem.data.priority) }">
                      <span class="dot-small"></span> {{ $t('tasks.' + selectedItem.data.priority?.toLowerCase()) || selectedItem.data.priority }}
                    </span>
                  </div>
                    <div class="detail-item">
                      <label>{{ $t('tasks.dueDate') || 'Due Date' }}</label>
                      <p class="value">{{ selectedItem.data.dueDate || selectedItem.data.due_date }}</p>
                    </div>
                  </div>
                </template>

                <template v-else-if="selectedItem.type.toLowerCase() === 'lead'">
                  <div class="detail-item">
                    <label>{{ $t('leads.name') }}</label>
                    <p class="value">{{ selectedItem.data.name }}</p>
                  </div>
                  <div class="detail-item">
                    <label>{{ $t('leads.source') }}</label>
                    <p class="value">{{ selectedItem.data.source }}</p>
                  </div>
                  <div class="detail-row">
                    <div class="detail-item">
                    <label>{{ $t('leads.priority') }}</label>
                    <span class="tag tag-priority" :style="{ backgroundColor: getPriorityColor(selectedItem.data.priority) }">
                      <span class="dot-small"></span> {{ $t('leads.' + selectedItem.data.priority?.toLowerCase()) || selectedItem.data.priority }}
                    </span>
                  </div>
                    <div class="detail-item">
                      <label>{{ $t('payments.status') }}</label>
                      <p class="value">{{ selectedItem.data.status }}</p>
                    </div>
                  </div>
                </template>

                <template v-else-if="selectedItem.type.toLowerCase() === 'payment'">
                  <div class="detail-item">
                    <label>{{ $t('payments.studentName') }}</label>
                    <p class="value">{{ selectedItem.data.student_name || selectedItem.data.student }}</p>
                  </div>
                  <div class="detail-row">
                    <div class="detail-item">
                      <label>{{ $t('payments.amount') }}</label>
                      <p class="value highlight">{{ selectedItem.data.amount }} UZS</p>
                    </div>
                    <div class="detail-item">
                      <label>{{ $t('payments.method') }}</label>
                      <p class="value">{{ selectedItem.data.method }}</p>
                    </div>
                  </div>
                  <div class="detail-item">
                    <label>{{ $t('payments.date') }}</label>
                    <p class="value">{{ selectedItem.data.date }}</p>
                  </div>
                </template>

                <template v-else-if="selectedItem.type.toLowerCase() === 'teacher'">
                  <div class="detail-item">
                    <label>{{ $t('teachers.name') || 'Full Name' }}</label>
                    <p class="value">{{ selectedItem.data.name }}</p>
                  </div>
                  <div class="detail-row">
                    <div class="detail-item">
                      <label>{{ $t('teachers.subject') || 'Subject' }}</label>
                      <p class="value">{{ selectedItem.data.subject }}</p>
                    </div>
                    <div class="detail-item">
                      <label>{{ $t('teachers.phone') || 'Phone' }}</label>
                      <p class="value">{{ selectedItem.data.phone }}</p>
                    </div>
                  </div>
                  <div class="detail-item">
                    <label>{{ $t('teachers.email') || 'Email' }}</label>
                    <p class="value">{{ selectedItem.data.email || 'No email' }}</p>
                  </div>
                </template>

                <template v-else-if="selectedItem.type.toLowerCase() === 'room'">
                  <div class="detail-item">
                    <label>{{ $t('rooms.name') || 'Room Name' }}</label>
                    <p class="value">{{ selectedItem.data.name }}</p>
                  </div>
                  <div class="detail-row">
                    <div class="detail-item">
                      <label>{{ $t('rooms.capacity') || 'Capacity' }}</label>
                      <p class="value highlight">{{ selectedItem.data.capacity }}</p>
                    </div>
                  </div>
                  <div class="detail-item">
                    <label>{{ $t('rooms.description') || 'Description' }}</label>
                    <p class="value note">{{ selectedItem.data.description || 'No description' }}</p>
                  </div>
                </template>

                <template v-else-if="selectedItem.type.toLowerCase() === 'group'">
                  <div class="detail-item">
                    <label>{{ $t('groups.name') || 'Group Name' }}</label>
                    <p class="value">{{ selectedItem.data.name }}</p>
                  </div>
                  <div class="detail-row">
                    <div class="detail-item">
                      <label>{{ $t('groups.course') || 'Course' }}</label>
                      <p class="value">{{ selectedItem.data.courses?.name || '-' }}</p>
                    </div>
                    <div class="detail-item">
                      <label>{{ $t('groups.teacher') || 'Teacher' }}</label>
                      <p class="value">{{ selectedItem.data.teachers?.name || '-' }}</p>
                    </div>
                  </div>
                  <div class="detail-row">
                    <div class="detail-item">
                      <label>{{ $t('groups.days') || 'Days' }}</label>
                      <p class="value">{{ selectedItem.data.days || '-' }}</p>
                    </div>
                    <div class="detail-item">
                      <label>{{ $t('groups.time') || 'Time' }}</label>
                      <p class="value">{{ selectedItem.data.time || '-' }}</p>
                    </div>
                  </div>
                </template>

                <template v-else-if="selectedItem.type.toLowerCase() === 'student'">
                  <div class="detail-item">
                    <label>{{ $t('students.name') || 'Student Name' }}</label>
                    <p class="value">{{ selectedItem.data.name }}</p>
                  </div>
                  <div class="detail-row">
                    <div class="detail-item">
                      <label>{{ $t('students.phone') || 'Phone' }}</label>
                      <p class="value">{{ selectedItem.data.phone || '-' }}</p>
                    </div>
                    <div class="detail-item">
                      <label>{{ $t('students.status') || 'Status' }}</label>
                      <p class="value">{{ selectedItem.data.status || '-' }}</p>
                    </div>
                  </div>
                  <div class="detail-item">
                    <label>{{ $t('students.group') }}</label>
                    <p class="value">{{ selectedItem.data.groups?.name || 'No group' }}</p>
                  </div>
                </template>

                <template v-else-if="selectedItem.type.toLowerCase() === 'course'">
                  <div class="detail-item">
                    <label>{{ $t('courses.name') || 'Course Name' }}</label>
                    <p class="value">{{ selectedItem.data.name }}</p>
                  </div>
                  <div class="detail-row">
                    <div class="detail-item">
                      <label>{{ $t('courses.category') || 'Category' }}</label>
                      <p class="value">{{ selectedItem.data.category || '-' }}</p>
                    </div>
                    <div class="detail-item">
                      <label>{{ $t('courses.price') || 'Price' }}</label>
                      <p class="value">{{ formatCurrency(selectedItem.data.price) }}</p>
                    </div>
                  </div>
                </template>
              </div>

              <div class="modal-footer">
                <button class="btn-outline" @click="closeDetails">{{ $t('common.cancel') }}</button>
                <button class="btn btn-primary btn-restore-large" @click="restoreItem(selectedItem)" :disabled="restoringId">
                  <Loader2 v-if="restoringId" :size="18" class="spin" />
                  <template v-else>
                    <RotateCcw :size="18" /> {{ $t('archive.restoreTo', { type: selectedItem.type }) }}
                  </template>
                </button>
              </div>
            </div>

            <!-- Right Side: Comments (Read Only for Archive) -->
            <div class="td-right">
              <div class="td-right-header">
                <div class="header-title">
                  <MessageSquare :size="18" />
                  <h3>{{ $t('archive.history') }}</h3>
                </div>
                <button class="btn-icon td-close-desktop" @click="closeDetails"><X :size="20" /></button>
              </div>

              <div class="comments-list">
                <template v-if="selectedItem.data.comments_list?.length > 0 || selectedItem.data.commentsList?.length > 0">
                   <div v-for="comment in (selectedItem.data.comments_list || selectedItem.data.commentsList)" :key="comment.id" class="comment-item">
                      <div class="comment-avatar">{{ comment.author?.charAt(0) || 'U' }}</div>
                      <div class="comment-content">
                        <div class="comment-top">
                          <span class="comment-author">{{ comment.author }}</span>
                          <span class="comment-time">{{ comment.time }}</span>
                        </div>
                        <p class="comment-text">{{ comment.text }}</p>
                      </div>
                   </div>
                </template>
                <div v-else class="no-comments">
                  <MessageSquare :size="32" />
                  <p>{{ $t('archive.noComments') }}</p>
                </div>
              </div>
              
              <div class="archive-note">
                <p>{{ $t('archive.readOnly') }}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </transition>

    <!-- Permanent Delete Confirmation Modal -->
    <transition name="modal">
      <div v-if="showDeleteModal" class="modal-overlay" @click.self="showDeleteModal = false">
        <div class="modal-box confirm-modal-small">
          <div class="modal-body text-center p-2rem">
            <div class="confirm-icon-large danger">
              <Trash2 :size="48" />
            </div>
            <h2 class="confirm-title">{{ $t('common.areYouSure') }}</h2>
            <p class="confirm-desc">{{ $t('archive.deleteConfirm') }}</p>
            <div class="confirm-actions">
              <button class="btn-cancel-action" @click="showDeleteModal = false" :disabled="isDeletingPermanently">{{ $t('common.cancel') }}</button>
              <button class="btn-danger-confirm-action" @click="permanentDelete" :disabled="isDeletingPermanently">
                <Loader2 v-if="isDeletingPermanently" :size="18" class="spin" />
                <span v-else>{{ $t('common.delete') }}</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </transition>

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

@media (max-width: 768px) {
  .td-layout {
    flex-direction: column;
    height: 90vh;
  }
  .td-left { border-right: none; border-bottom: 1px solid var(--border); height: 60%; }
  .td-right { height: 40%; }
  .td-close-desktop { display: none; }
  .td-close-mobile { display: flex; }
}

.details-grid {
  flex: 1;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
  padding: 1.5rem;
}

.detail-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.5rem;
}

.detail-item label {
  display: block;
  font-size: 0.75rem;
  font-weight: 800;
  text-transform: uppercase;
  color: var(--gray);
  margin-bottom: 0.5rem;
  letter-spacing: 0.5px;
}

.detail-item .value {
  font-weight: 600;
  color: var(--dark);
  font-size: 1rem;
}

.detail-item .value.note {
  background: var(--light);
  padding: 1rem;
  border-radius: 12px;
  font-style: italic;
  font-size: 0.9rem;
  color: var(--gray);
}

.detail-item .highlight {
  color: var(--success);
  font-size: 1.25rem;
  font-weight: 800;
}

.btn-restore-large {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.8rem 1.5rem;
  border-radius: 12px;
  font-weight: 700;
  box-shadow: 0 4px 12px rgba(115,102,255,0.2);
  transition: all 0.3s;
}

.btn-restore-large:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 15px rgba(115,102,255,0.3);
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 1rem;
  padding: 1.5rem;
  border-top: 1px solid var(--border);
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
