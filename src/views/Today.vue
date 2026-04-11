<script setup>
import { 
  MoreVertical, 
  MessageSquare, 
  Plus, 
  X,
  Check,
  Layout,
  CheckSquare,
  Trash2,
  Send,
  Loader2,
  Archive,
  Zap,
  Phone,
  Globe,
  BookOpen
} from 'lucide-vue-next';
import { ref, reactive, nextTick, onMounted, onUnmounted, computed } from 'vue';
import draggable from 'vuedraggable';
import { supabase } from '../supabase.js';

const activeDropdown = ref(null);

const toggleDropdown = (id, event) => {
  event.stopPropagation();
  activeDropdown.value = activeDropdown.value === id ? null : id;
};

const closeDropdowns = () => {
  activeDropdown.value = null;
};

const boards = ref([]);
const isLoading = ref(true);
const isSubmittingTask = ref(false);
const deletingTaskId = ref(null);

const TODAY_BOARD_TITLE = "Today task list";
const FINISHED_BOARD_TITLE = "Finished tasks";

const loadData = async () => {
  isLoading.value = true;
  try {
    // 1. Fetch boards
    let { data: boardsData, error: boardsErr } = await supabase
      .from('boards')
      .select('*')
      .in('title', [TODAY_BOARD_TITLE, FINISHED_BOARD_TITLE]);
    
    if (boardsErr) throw boardsErr;

    // 2. Create missing boards if needed
    if (!boardsData || boardsData.length < 2) {
      const existingTitles = boardsData ? boardsData.map(b => b.title) : [];
      const boardsToCreate = [];
      
      if (!existingTitles.includes(TODAY_BOARD_TITLE)) {
        boardsToCreate.push({ id: `board-today-${Date.now()}`, title: TODAY_BOARD_TITLE, color: '#7366FF', created_at: new Date().toISOString() });
      }
      if (!existingTitles.includes(FINISHED_BOARD_TITLE)) {
        boardsToCreate.push({ id: `board-finished-${Date.now()}`, title: FINISHED_BOARD_TITLE, color: '#28C76F', created_at: new Date().toISOString() });
      }

      if (boardsToCreate.length > 0) {
        const { data: createdBoards, error: createError } = await supabase.from('boards').insert(boardsToCreate).select();
        if (createError) throw createError;
        boardsData = [...(boardsData || []), ...createdBoards];
      }
    }

    // Sort boards to maintain order: Today -> Finished
    boardsData.sort((a, b) => {
      if (a.title === TODAY_BOARD_TITLE) return -1;
      return 1;
    });

    // 3. Fetch tasks for these boards
    const boardIds = boardsData.map(b => b.id);
    const { data: tasksData, error: tasksErr } = await supabase
      .from('tasks')
      .select('*')
      .in('board_id', boardIds);
    
    if (tasksErr) throw tasksErr;

    boards.value = boardsData.map(b => ({
      id: b.id,
      title: b.title,
      color: b.color,
      tasks: (tasksData || []).filter(t => t.board_id === b.id).map(t => {
        let leadMetadata = null;
        let finalDesc = t.description || '';
        if (finalDesc.includes('[LEAD_DATA]')) {
          const match = finalDesc.match(/\[LEAD_DATA\](.*?)\[\/LEAD_DATA\]/s);
          if (match) {
            try { leadMetadata = JSON.parse(match[1]); } catch(err) { console.error(err); }
            finalDesc = finalDesc.replace(/\[LEAD_DATA\].*?\[\/LEAD_DATA\]\n?/s, '');
          }
        }
        return {
          id: t.id,
          title: t.title,
          description: finalDesc,
          priority: t.priority,
          dueDate: t.due_date,
          progress: t.progress,
          commentsList: t.comments_list || [],
          leadMetadata
        };
      })
    }));
  } catch (e) {
    console.error('Error loading today data:', e);
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  document.addEventListener('click', closeDropdowns);
  loadData();
});

onUnmounted(() => {
  document.removeEventListener('click', closeDropdowns);
});

const deleteTask = async (boardId, taskId) => {
  if (deletingTaskId.value) return;
  deletingTaskId.value = taskId;
  const board = boards.value.find(b => b.id === boardId);
  if (board) {
    const taskIndex = board.tasks.findIndex(t => t.id === taskId);
    if (taskIndex !== -1) {
      const taskToArchive = board.tasks[taskIndex];
      try {
        await supabase.from('archives').insert([{
          type: 'today_task',
          original_id: taskId,
          data: taskToArchive
        }]);
        await supabase.from('tasks').delete().eq('id', taskId);
        board.tasks.splice(taskIndex, 1);
        activeDropdown.value = null;
      } catch (e) {
        console.error('Error archiving/deleting task:', e);
      } finally {
        deletingTaskId.value = null;
      }
    }
  } else {
    deletingTaskId.value = null;
  }
};

const priorityFilters = ['All', 'High', 'Medium', 'Low'];
const activePriority = ref('All');

const filteredCount = (tasks) => {
  if (!tasks) return 0;
  if (activePriority.value === 'All') return tasks.length;
  return tasks.filter(t => t.priority === activePriority.value).length;
};

// --- Task Modal State ---
const showTaskModal = ref(false);
const targetBoardId = ref(null);
const newTask = reactive({
  title: '',
  description: '',
  priority: 'Medium',
  progress: 0,
  dueDate: ''
});
const priorities = ['Low', 'Medium', 'High'];

const getLeadPriorityColor = (p) => {
  switch (p) {
    case 'Hot': return '#EA5455';
    case 'Warm': return '#FF9F43';
    case 'Cold': return '#00CFE8';
    default: return '#7366FF';
  }
};

const getPriorityColor = (priority) => {
  switch (priority.toLowerCase()) {
    case 'high': return 'var(--danger)';
    case 'medium': return 'var(--warning)';
    case 'low': return 'var(--success)';
    default: return 'var(--gray)';
  }
};

const openTaskModal = (boardId) => {
  targetBoardId.value = boardId;
  newTask.title = '';
  newTask.description = '';
  newTask.priority = 'Medium';
  newTask.progress = 0;
  newTask.dueDate = '';
  showTaskModal.value = true;
};

const closeTaskModal = () => {
  showTaskModal.value = false;
};

// --- Task Details Modal State ---
const showTaskDetailsModal = ref(false);
const selectedTaskDetails = ref(null);
const newComment = ref('');

const openTaskDetails = (task) => {
  if (!task.commentsList) {
    task.commentsList = []; 
  }
  selectedTaskDetails.value = task;
  newComment.value = '';
  showTaskDetailsModal.value = true;
};

const closeTaskDetails = () => {
  showTaskDetailsModal.value = false;
  selectedTaskDetails.value = null;
  isEditingDetails.value = false;
};

const isEditingDetails = ref(false);
const editForm = reactive({
  title: '',
  description: '',
  priority: '',
  dueDate: ''
});

const startEditing = () => {
  editForm.title = selectedTaskDetails.value.title;
  editForm.description = selectedTaskDetails.value.description;
  editForm.priority = selectedTaskDetails.value.priority;
  editForm.dueDate = selectedTaskDetails.value.dueDate;
  isEditingDetails.value = true;
};

const saveTaskChanges = async () => {
  if (!editForm.title.trim()) return;
  try {
    // 1. Check if the task has lead metadata and re-attach it to description
    const hasLeadMeta = selectedTaskDetails.value.leadMetadata;
    let descToSave = editForm.description;
    if (hasLeadMeta) {
      descToSave = `[LEAD_DATA]${JSON.stringify(hasLeadMeta)}[/LEAD_DATA]\n${descToSave}`;
    }

    const { error } = await supabase.from('tasks').update({
      title: editForm.title,
      description: descToSave,
      priority: editForm.priority,
      due_date: editForm.dueDate
    }).eq('id', selectedTaskDetails.value.id);
    
    if (error) throw error;
    
    selectedTaskDetails.value.title = editForm.title;
    selectedTaskDetails.value.description = editForm.description;
    selectedTaskDetails.value.priority = editForm.priority;
    selectedTaskDetails.value.dueDate = editForm.dueDate;
    
    boards.value.forEach(b => {
      const t = b.tasks.find(tk => tk.id === selectedTaskDetails.value.id);
      if (t) {
        t.title = editForm.title;
        t.description = editForm.description;
        t.priority = editForm.priority;
        t.dueDate = editForm.dueDate;
      }
    });

    isEditingDetails.value = false;
  } catch (e) {
    console.error(e);
  }
};

const addComment = async () => {
  if (!newComment.value.trim() || !selectedTaskDetails.value) return;
  const comment = {
    id: Date.now(),
    text: newComment.value.trim(),
    author: 'Admin User',
    time: new Date().toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})
  };
  const updatedComments = [...(selectedTaskDetails.value.commentsList || []), comment];
  try {
    await supabase.from('tasks').update({ comments_list: updatedComments }).eq('id', selectedTaskDetails.value.id);
    selectedTaskDetails.value.commentsList.push(comment);
    newComment.value = '';
  } catch (e) {
    console.error(e);
  }
};

const confirmAddTask = async () => {
  if (!newTask.title.trim() || isSubmittingTask.value) return;
  isSubmittingTask.value = true;
  const boardId = targetBoardId.value;
  const boardIndex = boards.value.findIndex(b => b.id === boardId);
  if (boardIndex > -1) {
    const creationDate = new Date().toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
    const dbTask = {
      id: `task-today-${Date.now()}`,
      board_id: boardId,
      title: newTask.title.trim(),
      description: newTask.description?.trim() || '',
      priority: newTask.priority,
      due_date: creationDate,
      progress: newTask.progress || 0,
      comments_list: []
    };
    try {
      await supabase.from('tasks').insert([dbTask]);
      boards.value[boardIndex].tasks.push({
        id: dbTask.id,
        title: dbTask.title,
        description: dbTask.description,
        priority: dbTask.priority,
        progress: dbTask.progress,
        dueDate: dbTask.due_date,
        commentsList: []
      });
      closeTaskModal();
    } catch (e) {
      console.error(e);
    } finally {
      isSubmittingTask.value = false;
    }
  } else {
    isSubmittingTask.value = false;
  }
};

const handleDragChange = async (event, boardId) => {
  if (event.added) {
    const taskId = event.added.element.id;
    try {
      await supabase.from('tasks').update({ board_id: boardId }).eq('id', taskId);
    } catch (e) {
      console.error('Error updating task board:', e);
    }
  }
};
</script>

<template>
  <div class="tasks-page">
    <div class="tasks-filters">
      <div class="today-title">
        <h2>{{ $t('today.schedule') }}</h2>
      </div>
      <div class="priority-tabs">
        <span class="label">{{ $t('tasks.priority') }}</span>
        <button 
          v-for="p in priorityFilters" 
          :key="p"
          :class="['tab', { active: activePriority === p }]"
          @click="activePriority = p"
        >
          {{ $t('tasks.' + p.toLowerCase()) || p }}
        </button>
      </div>
    </div>

    <div class="kanban-outer-container">
      <div class="kanban-wrapper two-cols">
        <template v-if="isLoading">
          <div v-for="i in 2" :key="i" class="kanban-column skeleton-column">
            <div class="board-header" style="margin-bottom: 1.5rem;">
              <div class="header-main">
                <div class="skeleton" style="width: 12px; height: 12px; border-radius: 50%;"></div>
                <div class="skeleton" style="width: 140px; height: 18px;"></div>
              </div>
            </div>
            <div class="drag-area">
              <div v-for="j in 3" :key="j" class="task-card card skeleton-card">
                <div class="skeleton" style="width: 100%; height: 22px; margin-bottom: 1rem;"></div>
                <div class="skeleton" style="width: 70%; height: 14px;"></div>
              </div>
            </div>
          </div>
        </template>

        <template v-else>
          <div v-for="board in boards" :key="board.id" class="kanban-column">
            <div class="board-header">
              <div class="header-main">
                <span class="dot" :style="{ backgroundColor: board.color }"></span>
                <h3 class="board-title">
                  {{ board.title === TODAY_BOARD_TITLE ? $t('tasks.todayTitle') : (board.title === FINISHED_BOARD_TITLE ? $t('tasks.finishedTitle') : board.title) }}
                </h3>
                <span class="count">{{ filteredCount(board.tasks).toString().padStart(2, '0') }}</span>
              </div>
            </div>

            <draggable 
              v-model="board.tasks" 
              group="tasks" 
              item-key="id"
              class="drag-area"
              ghost-class="ghost-card"
              @change="(e) => handleDragChange(e, board.id)"
            >
              <template #item="{ element: task }">
                <div class="task-card card" v-show="activePriority === 'All' || task.priority === activePriority">
                  <!-- Conditional Render: Lead card style -->
                  <template v-if="task.leadMetadata">
                    <div class="lead-top">
                      <div class="lead-avatar" :style="{ backgroundColor: task.leadMetadata.avatarColor + '25', color: task.leadMetadata.avatarColor }">
                        {{ task.leadMetadata.initials }}
                      </div>
                      <div class="lead-identity">
                        <h4 class="lead-name">{{ task.title }}</h4>
                        <span 
                          class="tag tag-priority"
                          :style="{ backgroundColor: getLeadPriorityColor(task.leadMetadata.leadPriority) }"
                        >
                          <span class="dot-small"></span>
                          {{ $t('leads.' + task.leadMetadata.leadPriority.toLowerCase()) }}
                        </span>
                      </div>
                      <div class="dropdown-wrapper ml-auto">
                        <button class="btn-icon" @click="(e) => toggleDropdown('task-' + task.id, e)">
                          <MoreVertical :size="16" />
                        </button>
                        <transition name="dropdown">
                          <div v-if="activeDropdown === 'task-' + task.id" class="dropdown-menu">
                            <button class="dropdown-item danger" @click="deleteTask(board.id, task.id)" :disabled="deletingTaskId === task.id">
                              <Loader2 v-if="deletingTaskId === task.id" :size="16" class="spin" />
                              <Trash2 v-else :size="16" /> 
                              {{ deletingTaskId === task.id ? $t('common.loading') : $t('tasks.delete') }}
                            </button>
                          </div>
                        </transition>
                      </div>
                    </div>

                    <div class="lead-tags">
                      <span v-if="task.leadMetadata.interest" class="tag tag-interest">
                        <BookOpen :size="12" />
                        {{ task.leadMetadata.interest }}
                      </span>
                      <span class="tag tag-source">
                        <Globe :size="12" />
                        {{ task.leadMetadata.source }}
                      </span>
                    </div>

                    <div class="lead-contacts">
                      <div class="contact-row" v-if="task.leadMetadata.phone">
                        <Phone :size="14" />
                        <span>{{ task.leadMetadata.phone }}</span>
                      </div>
                      <div class="contact-row" v-if="task.leadMetadata.phone2">
                        <Phone :size="14" />
                        <span>{{ task.leadMetadata.phone2 }}</span>
                      </div>
                    </div>

                    <div class="card-footer" style="margin-top: 1rem;">
                      <button class="meta-item btn-msg" @click="openTaskDetails(task)">
                        <MessageSquare :size="16" /> {{ task.commentsList ? task.commentsList.length : (task.comments || 0) }}
                      </button>
                    </div>
                  </template>

                  <!-- Standard task card style -->
                  <template v-else>
                    <div class="card-labels">
                      <span 
                        class="tag tag-priority"
                        :style="{ backgroundColor: getPriorityColor(task.priority || 'Medium') }"
                      >
                        <span class="dot-small"></span>
                        {{ $t('tasks.' + (task.priority || 'Medium').toLowerCase()) }}
                      </span>
                      <div class="dropdown-wrapper ml-auto">
                        <button class="btn-icon" @click="(e) => toggleDropdown('task-' + task.id, e)">
                          <MoreVertical :size="16" />
                        </button>
                        <transition name="dropdown">
                          <div v-if="activeDropdown === 'task-' + task.id" class="dropdown-menu">
                            <button class="dropdown-item danger" @click="deleteTask(board.id, task.id)" :disabled="deletingTaskId === task.id">
                              <Loader2 v-if="deletingTaskId === task.id" :size="16" class="spin" />
                              <Trash2 v-else :size="16" /> 
                              {{ deletingTaskId === task.id ? $t('common.loading') : $t('tasks.delete') }}
                            </button>
                          </div>
                        </transition>
                      </div>
                    </div>

                    <h4 class="task-title">{{ task.title }}</h4>

                    <div class="due-on">
                      <div class="due-row">
                        <span class="label">{{ $t('tasks.dueDate') }}:</span>
                        <span class="date">{{ task.dueDate }}</span>
                      </div>
                    </div>

                    <div class="card-footer">
                      <button class="meta-item btn-msg" @click="openTaskDetails(task)">
                        <MessageSquare :size="16" /> {{ task.commentsList ? task.commentsList.length : (task.comments || 0) }}
                      </button>
                    </div>
                  </template>
                </div>
              </template>
            </draggable>

            <button class="btn-new-task" @click="openTaskModal(board.id)">
              <Plus :size="18" /> {{ $t('today.addTodayTask') }}
            </button>
          </div>
        </template>
      </div>
    </div>

    <!-- Modals (Borrowed from Tasks.vue) -->
    <transition name="modal">
      <div v-if="showTaskModal" class="modal-overlay" @click.self="closeTaskModal">
        <div class="modal-box task-modal-box">
          <div class="modal-header">
            <div class="modal-title-row">
              <div class="modal-icon task-icon"><CheckSquare :size="22" /></div>
              <h2>{{ $t('today.newTask') }}</h2>
            </div>
            <button class="btn-icon" @click="closeTaskModal"><X :size="20" /></button>
          </div>
          <div class="modal-body">
            <div class="form-group">
              <label>{{ $t('tasks.taskTitle') }} <span class="required">*</span></label>
              <input v-model="newTask.title" :placeholder="$t('today.taskPlaceholder')" @keyup.enter="confirmAddTask" autofocus />
            </div>
            <div class="form-group">
              <label>{{ $t('tasks.description') }} <span class="optional">({{ $t('leads.optional') }})</span></label>
              <textarea v-model="newTask.description" :placeholder="$t('today.notesPlaceholder')" rows="3"></textarea>
            </div>
            <div class="form-group">
              <label>{{ $t('tasks.priority') }}</label>
              <div class="priority-selector">
                <button
                  v-for="p in priorities"
                  :key="p"
                  :class="['priority-pill', { active: newTask.priority === p }]"
                  :style="newTask.priority === p ? { background: getPriorityColor(p), color: 'white' } : {}"
                  @click="newTask.priority = p"
                >
                  <span class="pill-dot" :style="{ backgroundColor: newTask.priority === p ? 'white' : getPriorityColor(p) }"></span>
                  {{ $t('tasks.' + p.toLowerCase()) }}
                </button>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn-cancel-modal" @click="closeTaskModal" :disabled="isSubmittingTask">{{ $t('common.cancel') }}</button>
            <button class="btn-create-board" :disabled="!newTask.title.trim() || isSubmittingTask" @click="confirmAddTask">
              <template v-if="isSubmittingTask">
                <Loader2 :size="16" class="spin" /> {{ $t('common.loading') }}
              </template>
              <template v-else>
                <Plus :size="16" /> {{ $t('tasks.addTask') }}
              </template>
            </button>
          </div>
        </div>
      </div>
    </transition>

    <!-- Task Details Modal (Borrowed from Tasks.vue) -->
    <transition name="modal">
      <div v-if="showTaskDetailsModal" class="modal-overlay" @click.self="closeTaskDetails">
        <div class="modal-box task-details-box">
          <div class="td-layout" v-if="selectedTaskDetails">
            <div class="td-left">
              <div class="td-header">
                <span v-if="!isEditingDetails" class="tag tag-priority" :style="{ backgroundColor: getPriorityColor(selectedTaskDetails.priority) }">
                  <span class="dot-small"></span> {{ $t('tasks.' + selectedTaskDetails.priority.toLowerCase()) }}
                </span>
                <div v-else class="edit-priority-select">
                   <select v-model="editForm.priority">
                     <option v-for="p in priorities" :key="p" :value="p">{{ $t('tasks.' + p.toLowerCase()) }}</option>
                   </select>
                </div>

                <div class="td-header-actions ml-auto">
                   <button v-if="!isEditingDetails" class="btn-edit-task" @click="startEditing">
                     <Edit :size="16" /> {{ $t('common.edit') }}
                   </button>
                   <button v-else class="btn-save-task" @click="saveTaskChanges">
                     <Save :size="16" /> {{ $t('common.save') }}
                   </button>
                   <button class="btn-icon td-close-mobile" @click="closeTaskDetails"><X :size="20" /></button>
                </div>
              </div>

               <div class="td-info-body">
                <template v-if="!isEditingDetails">
                  <!-- Lead identification header -->
                  <div v-if="selectedTaskDetails.leadMetadata" class="td-lead-profile-mini">
                    <div class="td-lead-avatar" :style="{ backgroundColor: selectedTaskDetails.leadMetadata.avatarColor + '25', color: selectedTaskDetails.leadMetadata.avatarColor }">
                       {{ selectedTaskDetails.leadMetadata.initials }}
                    </div>
                    <div class="td-lead-info">
                       <h2 class="td-title">{{ selectedTaskDetails.title }}</h2>
                       <div class="td-lead-phones">
                         <span v-if="selectedTaskDetails.leadMetadata.phone"><Phone :size="14" /> {{ selectedTaskDetails.leadMetadata.phone }}</span>
                         <span v-if="selectedTaskDetails.leadMetadata.phone2"><Phone :size="14" /> {{ selectedTaskDetails.leadMetadata.phone2 }}</span>
                       </div>
                    </div>
                  </div>
                  <h2 v-else class="td-title">{{ selectedTaskDetails.title }}</h2>

                  <div class="td-desc">
                    <h3>{{ $t('tasks.description') }}</h3>
                    <p>{{ selectedTaskDetails.description || $t('tasks.noDescription') }}</p>
                  </div>
                </template>
                <template v-else>
                  <div class="edit-group">
                    <label>{{ $t('tasks.taskTitle') }}</label>
                    <input v-model="editForm.title" class="edit-input-title" />
                  </div>
                  <div class="edit-group">
                    <label>{{ $t('tasks.description') }}</label>
                    <textarea v-model="editForm.description" rows="4" class="edit-textarea"></textarea>
                  </div>
                </template>
              </div>

              <div class="td-meta">
                <div class="td-meta-item">
                  <span class="label">{{ $t('tasks.dueDate') }}</span>
                  <span v-if="!isEditingDetails" class="value">{{ selectedTaskDetails.dueDate }}</span>
                  <input v-else v-model="editForm.dueDate" class="edit-input-small" />
                </div>
              </div>
            </div>
            <div class="td-right">
              <div class="td-right-header">
                <h3>{{ $t('leads.comments') }}</h3>
                <button class="btn-icon td-close-desktop" @click="closeTaskDetails"><X :size="20" /></button>
              </div>
              <div class="comments-list">
                <div v-if="selectedTaskDetails.commentsList.length === 0" class="no-comments">{{ $t('leads.noComments') }}</div>
                <div v-for="comment in selectedTaskDetails.commentsList" :key="comment.id" class="comment-item">
                  <div class="comment-avatar">{{ comment.author.charAt(0) }}</div>
                  <div class="comment-content">
                    <div class="comment-top">
                      <span class="comment-author">{{ comment.author }}</span>
                      <span class="comment-time">{{ comment.time }}</span>
                    </div>
                    <p class="comment-text">{{ comment.text }}</p>
                  </div>
                </div>
              </div>
              <div class="comment-input-area">
                <textarea v-model="newComment" :placeholder="$t('leads.typeComment')" @keyup.enter.prevent="addComment"></textarea>
                <div class="comment-actions">
                    <button class="btn-send-comment" :disabled="!newComment.trim()" @click="addComment">
                      <Send :size="16" /> {{ $t('leads.send') }}
                    </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<style scoped>
/* Borrowed and adapted styles from Tasks.vue */
.tasks-page {
  padding: 1.5rem;
  background: var(--light);
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  height: calc(100vh - 70px);
}

.tasks-filters {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
  gap: 1rem;
}

.priority-tabs {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  background: white;
  padding: 0.5rem 1rem;
  border-radius: 12px;
  box-shadow: var(--shadow);
}

.priority-tabs .label { font-weight: 700; color: var(--dark); font-size: 1rem; margin-right: 0.5rem; }

.tab {
  padding: 0.4rem 1rem;
  border-radius: 8px;
  font-size: 0.9rem;
  font-weight: 600;
  color: var(--gray);
  transition: all 0.2s;
}

.tab.active { background: #f0f0ff; color: var(--primary); border: 1.5px solid var(--primary); }

.today-title h2 { font-size: 1.25rem; font-weight: 800; color: var(--dark); }

.kanban-outer-container { flex: 1; overflow: hidden; position: relative; }

.kanban-wrapper {
  display: flex;
  gap: 2rem;
  overflow-x: auto;
  height: 100%;
  padding-bottom: 2rem;
  justify-content: space-between; /* Align with header edges */
}

.two-cols .kanban-column { 
  flex: 1; 
  max-width: calc(50% - 1rem);
  min-width: 400px; 
}

.kanban-column {
  background: rgba(235, 237, 242, 0.4);
  padding: 1.5rem;
  border-radius: 20px;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
  height: 100%;
}

.drag-area {
  flex: 1;
  overflow-y: auto;
  display: flex;
  flex-direction: row;
  flex-wrap: wrap;
  gap: 0.75rem;
  padding-right: 8px;
}

.drag-area::-webkit-scrollbar { width: 4px; }
.drag-area::-webkit-scrollbar-thumb { background: var(--border); border-radius: 10px; }

.board-header { display: flex; justify-content: space-between; align-items: center; }
.header-main { display: flex; align-items: center; gap: 0.75rem; }
.dot { width: 12px; height: 12px; border-radius: 50%; }
.board-title { font-size: 1.2rem; font-weight: 800; }
.count { background: white; padding: 0.2rem 0.6rem; border-radius: 8px; color: var(--gray); font-weight: 700; font-size: 0.85rem; }

.task-card { 
  background: white; 
  padding: 1.25rem; 
  border-radius: 12px; 
  border: 1px solid transparent; 
  transition: all 0.2s;
  width: calc(50% - 0.375rem); 
  display: flex;
  flex-direction: column;
}
.task-card:hover { border-color: var(--primary); transform: translateY(-3px); }
.ghost-card { opacity: 0.4; background: var(--primary-light) !important; border: 2px dashed var(--primary) !important; }

/* Lead card elements in Today board */
.lead-top {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 1.25rem;
}
.lead-avatar {
  width: 42px;
  height: 42px;
  background-color: var(--primary-light);
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 800;
  font-size: 1rem;
  flex-shrink: 0;
}
.lead-identity {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}
.lead-name {
  font-size: 1.05rem;
  font-weight: 800;
  color: var(--dark);
  margin: 0;
}
.lead-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
  margin-bottom: 1rem;
}
.tag-interest {
  background: #FFF8EB;
  color: #FFA800;
  display: flex;
  align-items: center;
  gap: 0.35rem;
}
.tag-source {
  background: #F0F8FF;
  color: #007BFF;
  display: flex;
  align-items: center;
  gap: 0.35rem;
}
.lead-desc {
  font-size: 0.88rem;
  color: var(--gray);
  margin-bottom: 1rem;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.4;
}
.lead-contacts {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  margin-bottom: 0.5rem;
}
.contact-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.85rem;
  color: var(--dark);
  font-weight: 600;
}
.contact-row span {
  opacity: 0.8;
}

.card-labels { display: flex; align-items: center; gap: 0.5rem; margin-bottom: 1rem; }
.tag { font-size: 0.75rem; font-weight: 700; padding: 0.35rem 0.8rem; border-radius: 8px; }
.tag-priority { color: white; display: flex; align-items: center; gap: 0.4rem; }
.dot-small { width: 6px; height: 6px; background: white; border-radius: 50%; }

.td-lead-profile-mini {
  display: flex;
  align-items: center;
  gap: 1.25rem;
  margin-bottom: 2rem;
}

.td-lead-avatar {
  width: 56px;
  height: 56px;
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 800;
  font-size: 1.2rem;
}

.td-lead-info {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.td-lead-phones {
  display: flex;
  gap: 1.5rem;
  font-size: 0.9rem;
  font-weight: 700;
  color: var(--gray);
}

.td-lead-phones span {
  display: flex;
  align-items: center;
  gap: 0.4rem;
}

.task-header-group { display: flex; align-items: flex-start; gap: 1rem; margin-bottom: 1.25rem; }
.task-header-group.has-lead { align-items: center; }

.lead-avatar-mini {
  width: 40px;
  height: 40px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 800;
  font-size: 0.95rem;
  flex-shrink: 0;
}

.task-title { font-size: 1.1rem; font-weight: 700; line-height: 1.3; color: var(--dark); margin: 0; flex: 1; }

.due-on { font-size: 0.82rem; margin-bottom: 1.25rem; display: flex; flex-direction: column; gap: 0.4rem; }
.due-row { display: flex; align-items: center; }
.due-on .label { color: var(--gray); font-weight: 600; margin-right: 0.5rem; white-space: nowrap; }
.due-on .date { font-weight: 700; color: var(--dark); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.sent-by .label { color: var(--gray); }
.sent-by .date { color: var(--primary); font-weight: 800; }

.card-footer { 
  display: flex; 
  justify-content: space-between; 
  align-items: center; 
  padding-top: 1rem; 
  border-top: 1px solid var(--border); 
}
.btn-msg { color: var(--gray); font-weight: 600; font-size: 0.85rem; display: flex; align-items: center; gap: 0.4rem; }
.btn-msg:hover { color: var(--primary); }

.btn-archive-small {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.35rem 0.75rem;
  background: var(--light);
  color: var(--gray);
  border: none;
  border-radius: 8px;
  font-size: 0.72rem;
  font-weight: 700;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-archive-small:hover {
  background: #fdf3f3;
  color: var(--danger);
  transform: translateY(-2px);
  box-shadow: 0 4px 8px rgba(234, 84, 85, 0.1);
}

.btn-new-task {
  width: 100%;
  padding: 1rem;
  background: white;
  border: 2px dashed var(--border);
  border-radius: 14px;
  color: var(--dark);
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  transition: all 0.2s;
}

.btn-new-task:hover { background: var(--primary-light); border-color: var(--primary); color: var(--primary); }

/* Modal specific styles */
.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.5); backdrop-filter: blur(4px); z-index: 1000; display: flex; align-items: center; justify-content: center; }
.modal-box { background: white; border-radius: 24px; width: 100%; max-width: 500px; box-shadow: 0 20px 50px rgba(0,0,0,0.2); overflow: hidden; }
.modal-header { padding: 1.5rem 2rem; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; }
.modal-title-row { display: flex; align-items: center; gap: 1rem; }
.modal-icon { width: 44px; height: 44px; border-radius: 12px; display: flex; align-items: center; justify-content: center; }
.task-icon { background: #e8f9ee; color: var(--success); }
.btn-icon { width: 32px; height: 32px; border-radius: 8px; display: flex; align-items: center; justify-content: center; color: var(--gray); }
.modal-body { padding: 2rem; display: flex; flex-direction: column; gap: 1.5rem; }
.form-group { display: flex; flex-direction: column; gap: 0.6rem; }
.form-group label { font-size: 0.9rem; font-weight: 700; color: var(--dark); }
.form-group input, .form-group textarea { padding: 0.8rem 1rem; border: 1.5px solid var(--border); border-radius: 12px; outline: none; transition: border-color 0.2s; font-family: inherit; }
.form-group input:focus, .form-group textarea:focus { border-color: var(--primary); }
.priority-selector { display: flex; gap: 0.75rem; }
.priority-pill { padding: 0.5rem 1rem; border-radius: 20px; border: 1.5px solid var(--border); font-weight: 700; font-size: 0.85rem; display: flex; align-items: center; gap: 0.5rem; background: white; }
.pill-dot { width: 8px; height: 8px; border-radius: 50%; }
.modal-footer { padding: 1.5rem 2rem; border-top: 1px solid var(--border); display: flex; justify-content: flex-end; gap: 1rem; }
.btn-cancel-modal { padding: 0.8rem 1.5rem; border-radius: 12px; border: 1.5px solid var(--border); font-weight: 700; }
.btn-create-board { background: var(--primary); color: white; padding: 0.8rem 1.8rem; border-radius: 12px; font-weight: 700; display: flex; align-items: center; gap: 0.5rem; }
.comment-input-area {
  padding: 1.5rem;
  border-top: 1px solid var(--border);
  background: white;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.comment-input-area textarea {
  width: 100%;
  resize: none;
  border: 1.5px solid var(--border);
  border-radius: 12px;
  padding: 0.85rem 1rem;
  font-family: inherit;
  font-size: 0.95rem;
  outline: none;
  transition: border-color 0.2s;
  height: 90px;
}

.comment-input-area textarea:focus {
  border-color: var(--primary);
  box-shadow: 0 0 0 3px rgba(115,102,255,0.1);
}

.comment-actions {
  display: flex;
  justify-content: flex-end;
}

.btn-send-comment {
  background: var(--primary);
  color: white;
  padding: 0.6rem 1.25rem;
  border-radius: 10px;
  font-weight: 700;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  border: none;
  cursor: pointer;
  font-family: inherit;
}

.btn-send-comment:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-send-comment:not(:disabled):hover {
  background: #6259e6;
  box-shadow: 0 4px 12px rgba(115,102,255,0.3);
}

/* Details Modal Styles synced with Tasks.vue */
.task-details-box { max-width: 900px; width: 90%; }

.td-layout {
  display: flex;
  height: min(700px, 85vh);
  background: white;
}

.td-left {
  flex: 1;
  padding: 2.5rem;
  overflow-y: auto;
  border-right: 1px solid var(--border);
}

.td-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 2rem;
}

.td-close-mobile { display: none; }
.td-close-desktop { margin-left: auto; }

.td-title {
  font-size: 1.75rem;
  font-weight: 800;
  color: var(--dark);
  margin-bottom: 2rem;
  line-height: 1.3;
}

.td-desc h3 {
  font-size: 0.85rem;
  color: var(--gray);
  margin-bottom: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  font-weight: 700;
}

.td-desc p {
  line-height: 1.6;
  color: var(--dark);
  margin-bottom: 2rem;
  background: var(--light);
  padding: 1.5rem;
  border-radius: 12px;
  font-size: 1rem;
}

.td-meta {
  display: flex;
  gap: 3.5rem;
  padding-top: 1.5rem;
  border-top: 1px solid var(--light);
}

.td-meta-item {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.td-meta-item .label {
  font-size: 0.8rem;
  color: var(--gray);
  font-weight: 700;
  text-transform: uppercase;
}

.td-meta-item .value {
  font-weight: 800;
  font-size: 1.15rem;
  color: var(--dark);
}

.td-right {
  width: 400px;
  display: flex;
  flex-direction: column;
  background: #fcfcfc;
}

.td-right-header {
  padding: 1.5rem;
  border-bottom: 1px solid var(--border);
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: white;
}

.td-right-header h3 {
  font-size: 1.1rem;
  font-weight: 800;
  margin: 0;
}

.comments-list {
  flex: 1;
  padding: 1.5rem;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.comment-item {
  display: flex;
  gap: 1rem;
}

.comment-avatar {
  width: 38px;
  height: 38px;
  border-radius: 12px;
  background: var(--primary-light);
  color: var(--primary);
  font-weight: 800;
  display: flex;
  align-items: center;
  justify-content: center;
}

.comment-text {
  font-size: 0.95rem;
  line-height: 1.5;
  color: var(--dark);
  background: white;
  padding: 0.85rem 1rem;
  border-radius: 0 12px 12px 12px;
  border: 1px solid var(--border);
  box-shadow: 0 4px 10px rgba(75,70,92,0.03);
}

.btn-edit-task, .btn-save-task {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  border-radius: 10px;
  font-weight: 700;
  font-size: 0.85rem;
  transition: all 0.2s;
  border: none;
  cursor: pointer;
  font-family: inherit;
}
.btn-edit-task {
  background: var(--light);
  color: var(--gray);
}
.btn-edit-task:hover {
  background: var(--primary-light);
  color: var(--primary);
}
.btn-save-task {
  background: var(--primary);
  color: white;
}
.btn-save-task:hover {
  background: #6259e6;
  box-shadow: 0 4px 12px rgba(115,102,255,0.3);
}

.edit-group {
  margin-bottom: 2rem;
}
.edit-group label {
  display: block;
  font-size: 0.85rem;
  font-weight: 700;
  color: var(--gray);
  text-transform: uppercase;
  margin-bottom: 0.75rem;
}
.edit-input-title {
  width: 100%;
  font-size: 1.75rem;
  font-weight: 800;
  color: var(--dark);
  border: none;
  border-bottom: 2px solid var(--primary-light);
  background: transparent;
  outline: none;
  padding: 0.5rem 0;
  transition: all 0.2s;
}
.edit-input-title:focus {
  border-bottom-color: var(--primary);
}
.edit-textarea {
  width: 100%;
  padding: 1rem;
  border: 1.5px solid var(--border);
  border-radius: 12px;
  background: white;
  font-size: 1.05rem;
  color: var(--dark);
  line-height: 1.6;
  outline: none;
  resize: vertical;
}
.edit-textarea:focus {
  border-color: var(--primary);
  box-shadow: 0 0 0 3px rgba(115,102,255,0.1);
}
.edit-input-small {
  padding: 0.4rem 0.75rem;
  border: 1.5px solid var(--border);
  border-radius: 8px;
  font-size: 1.15rem;
  font-weight: 800;
  color: var(--dark);
  width: 100%;
  outline: none;
}
.edit-input-small:focus { border-color: var(--primary); }

.edit-priority-select select {
  padding: 0.4rem 1rem;
  border-radius: 20px;
  border: 1.5px solid var(--border);
  font-weight: 700;
  font-size: 0.85rem;
  background: white;
  outline: none;
}
.edit-priority-select select:focus { border-color: var(--primary); }

.td-header-actions {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.td-info-body {
  margin-top: 1.5rem;
  margin-bottom: 2.5rem;
}

/* Dropdown Positioning Fix */
.dropdown-wrapper {
  position: relative;
  display: flex;
}

.dropdown-menu {
  position: absolute;
  top: calc(100% + 5px);
  right: 0;
  background: white;
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 0.5rem;
  z-index: 1000;
  min-width: 160px;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.15);
  transform-origin: top right;
}

.dropdown-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem 1rem;
  width: 100%;
  border-radius: 8px;
  font-size: 0.9rem;
  font-weight: 700;
  color: var(--dark);
  transition: all 0.2s;
  cursor: pointer;
  border: none;
  background: transparent;
  font-family: inherit;
}

.dropdown-item:hover {
  background: var(--light);
}

.dropdown-item.danger {
  color: var(--danger);
}

.dropdown-item.danger:hover {
  background: #fff5f5;
}

/* Transition */
.dropdown-enter-active, .dropdown-leave-active {
  transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
}
.dropdown-enter-from, .dropdown-leave-to {
  opacity: 0;
  transform: scale(0.95) translateY(-10px);
}
</style>
