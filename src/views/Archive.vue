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
  Send
} from 'lucide-vue-next';
import { ref, computed, onMounted, reactive } from 'vue';
import { supabase } from '../supabase.js';

const archivedItems = ref([]);
const isLoading = ref(true);
const searchQuery = ref('');
const activeFilter = ref('All');
const selectedItem = ref(null);
const showDetailsModal = ref(false);

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

const typeFilters = ['All', 'Task', 'Lead', 'Payment'];

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
    default: return Archive;
  }
};

const getTypeColor = (type) => {
  switch (type.toLowerCase()) {
    case 'task': return '#7366FF';
    case 'lead': return '#FF9F43';
    case 'payment': return '#28C76F';
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
  return item.original_id;
};

const formatDate = (dateStr) => {
  return new Date(dateStr).toLocaleString('en-GB', {
    day: '2-digit',
    month: 'short',
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
  try {
    const tableName = item.type === 'task' ? 'tasks' : (item.type === 'lead' ? 'leads' : 'payments');
    
    // Normalize data (remove id if it exists as type double or handle appropriately)
    const restoreData = { ...item.data };
    
    const { error: restoreError } = await supabase.from(tableName).insert([restoreData]);
    if (restoreError) throw restoreError;
    
    const { error: deleteError } = await supabase.from('archives').delete().eq('id', item.id);
    if (deleteError) throw deleteError;
    
    archivedItems.value = archivedItems.value.filter(i => i.id !== item.id);
    alert(`${item.type.charAt(0).toUpperCase() + item.type.slice(1)} restored successfully!`);
  } catch (e) {
    console.error('Error restoring:', e);
    alert('Failed to restore item.');
  }
};

const permanentDelete = async (id) => {
  if (!confirm('Are you sure you want to permanently delete this item? This cannot be undone.')) return;
  
  try {
    const { error } = await supabase.from('archives').delete().eq('id', id);
    if (error) throw error;
    archivedItems.value = archivedItems.value.filter(i => i.id !== id);
  } catch (e) {
    console.error('Error deleting:', e);
  }
};

</script>

<template>
  <div class="archive-page">
    <div class="page-header">
      <div class="header-content">
        <h1>Archives</h1>
        <p>Manage deleted accounts, leads, and historical data</p>
      </div>
    </div>

    <!-- Filters Section -->
    <div class="archive-filters">
      <div class="search-bar">
        <Search :size="18" />
        <input v-model="searchQuery" type="text" placeholder="Search archives..." />
      </div>
      
      <div class="type-tabs">
        <button 
          v-for="t in typeFilters" 
          :key="t"
          :class="['tab', { active: activeFilter === t }]"
          @click="activeFilter = t"
        >
          {{ t }}s
        </button>
      </div>
    </div>

    <!-- Archive List -->
    <div class="table-container card">
      <div class="table-scroll-wrapper">
        <table>
          <thead>
            <tr>
              <th>Type</th>
              <th>Content Title</th>
              <th>Archived At</th>
              <th>Original ID</th>
              <th class="actions-col">Actions</th>
            </tr>
          </thead>
          <tbody>
            <!-- Loading State -->
            <template v-if="isLoading">
              <tr v-for="i in 5" :key="i">
                <td>
                  <div class="skeleton" style="width: 90px; height: 26px; border-radius: 8px;"></div>
                </td>
                <td>
                  <div class="skeleton" style="width: 200px; height: 18px; margin-bottom: 6px;"></div>
                  <div class="skeleton" style="width: 120px; height: 12px;"></div>
                </td>
                <td>
                  <div class="skeleton" style="width: 140px; height: 16px;"></div>
                </td>
                <td>
                  <div class="skeleton" style="width: 90px; height: 16px; border-radius: 4px;"></div>
                </td>
                <td class="actions-col">
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
                  <p>No archived items found</p>
                </div>
              </td>
            </tr>

            <!-- Real Data -->
            <template v-else>
              <tr v-for="item in filteredArchives" :key="item.id">
                <td>
                  <div class="type-tag" :style="{ color: getTypeColor(item.type), backgroundColor: getTypeColor(item.type) + '15' }">
                    <component :is="getTypeIcon(item.type)" :size="14" />
                    {{ item.type.toUpperCase() }}
                  </div>
                </td>
                <td>
                  <span class="item-title">{{ getItemTitle(item) }}</span>
                </td>
                <td>
                  <span class="archived-date">{{ formatDate(item.archived_at) }}</span>
                </td>
                <td>
                  <code class="original-id">{{ item.original_id }}</code>
                </td>
                <td class="actions-col">
                  <div class="action-buttons">
                    <button class="btn-action view" @click="openDetails(item)" title="View Details">
                      <Eye :size="16" />
                    </button>
                    <button class="btn-action restore" @click="restoreItem(item)" title="Restore">
                      <RotateCcw :size="16" />
                    </button>
                    <button class="btn-action delete" @click="permanentDelete(item.id)" title="Permanent Delete">
                      <Trash2 :size="16" />
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
                <h3>Archived {{ selectedItem.type }} Details</h3>
                <button class="btn-icon td-close-mobile" @click="closeDetails"><X :size="20" /></button>
              </div>
              
              <div class="details-grid">
                <template v-if="selectedItem.type.toLowerCase() === 'task'">
                  <div class="detail-item">
                    <label>Title</label>
                    <p class="value">{{ selectedItem.data.title }}</p>
                  </div>
                  <div class="detail-item">
                    <label>Description</label>
                    <p class="value note">{{ selectedItem.data.description || 'No description' }}</p>
                  </div>
                  <div class="detail-row">
                    <div class="detail-item">
                    <label>Priority</label>
                    <span class="tag tag-priority" :style="{ backgroundColor: getPriorityColor(selectedItem.data.priority) }">
                      <span class="dot-small"></span> {{ selectedItem.data.priority }}
                    </span>
                  </div>
                    <div class="detail-item">
                      <label>Due Date</label>
                      <p class="value">{{ selectedItem.data.dueDate || selectedItem.data.due_date }}</p>
                    </div>
                  </div>
                </template>

                <template v-else-if="selectedItem.type.toLowerCase() === 'lead'">
                  <div class="detail-item">
                    <label>Name</label>
                    <p class="value">{{ selectedItem.data.name }}</p>
                  </div>
                  <div class="detail-item">
                    <label>Source</label>
                    <p class="value">{{ selectedItem.data.source }}</p>
                  </div>
                  <div class="detail-row">
                    <div class="detail-item">
                    <label>Priority</label>
                    <span class="tag tag-priority" :style="{ backgroundColor: getPriorityColor(selectedItem.data.priority) }">
                      <span class="dot-small"></span> {{ selectedItem.data.priority }}
                    </span>
                  </div>
                    <div class="detail-item">
                      <label>Status</label>
                      <p class="value">{{ selectedItem.data.status }}</p>
                    </div>
                  </div>
                </template>

                <template v-else-if="selectedItem.type.toLowerCase() === 'payment'">
                  <div class="detail-item">
                    <label>Student Name</label>
                    <p class="value">{{ selectedItem.data.student_name || selectedItem.data.student }}</p>
                  </div>
                  <div class="detail-row">
                    <div class="detail-item">
                      <label>Amount</label>
                      <p class="value highlight">{{ selectedItem.data.amount }} UZS</p>
                    </div>
                    <div class="detail-item">
                      <label>Method</label>
                      <p class="value">{{ selectedItem.data.method }}</p>
                    </div>
                  </div>
                  <div class="detail-item">
                    <label>Date</label>
                    <p class="value">{{ selectedItem.data.date }}</p>
                  </div>
                </template>
              </div>

              <div class="modal-footer">
                <button class="btn btn-white" @click="closeDetails">Close</button>
                <button class="btn btn-primary btn-restore-large" @click="restoreItem(selectedItem)">
                  <RotateCcw :size="18" /> Restore to {{ selectedItem.type }}s
                </button>
              </div>
            </div>

            <!-- Right Side: Comments (Read Only for Archive) -->
            <div class="td-right">
              <div class="td-right-header">
                <div class="header-title">
                  <MessageSquare :size="18" />
                  <h3>History & Comments</h3>
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
                  <p>No comments found for this record.</p>
                </div>
              </div>
              
              <div class="archive-note">
                <p>This record is archived. To add new comments, please restore the item first.</p>
              </div>
            </div>
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

.modal-header.no-border {
  border-bottom: none;
}

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

.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-box {
  background: white;
  border-radius: 20px;
  box-shadow: var(--shadow);
}

.modal-header {
  padding: 1.5rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid var(--border);
}
</style>
