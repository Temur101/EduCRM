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
  Zap,
  Edit,
  Save
} from 'lucide-vue-next';
import { ref, reactive, nextTick, onMounted, onUnmounted } from 'vue';
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
const isSubmittingBoard = ref(false);
const deletingTaskId = ref(null);
const movingTaskId = ref(null);

const loadData = async () => {
  isLoading.value = true;
  try {
    const { data: boardsData, error: boardsErr } = await supabase
      .from('boards')
      .select('*')
      .eq('is_deleted', false)
      .neq('title', 'Today task list')
      .neq('title', 'Finished tasks')
      .order('created_at', { ascending: true });
    if (boardsErr) throw boardsErr;

    const { data: tasksData, error: tasksErr } = await supabase.from('tasks').select('*').eq('is_deleted', false);
    if (tasksErr) throw tasksErr;

    boards.value = (boardsData || []).map(b => ({
      id: b.id,
      title: b.title,
      color: b.color,
      tasks: tasksData.filter(t => t.board_id === b.id).map(t => ({
        id: t.id,
        title: t.title,
        description: t.description,
        priority: t.priority,
        dueDate: t.due_date,
        progress: t.progress,
        commentsList: t.comments_list || []
      }))
    }));
  } catch (e) {
    console.error('Error loading data:', e);
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

const deleteBoard = async (boardId) => {
  const index = boards.value.findIndex(b => b.id === boardId);
  if (index !== -1) {
    try {
      await supabase
        .from('boards')
        .update({ 
          is_deleted: true, 
          deleted_at: new Date().toISOString() 
        })
        .eq('id', boardId);
      
      // Also soft delete all tasks in this board
      await supabase
        .from('tasks')
        .update({ 
          is_deleted: true, 
          deleted_at: new Date().toISOString() 
        })
        .eq('board_id', boardId);
      boards.value.splice(index, 1);
    } catch (e) {
      console.error(e);
    }
  }
};

const deleteTask = async (boardId, taskId) => {
  if (deletingTaskId.value) return;
  deletingTaskId.value = taskId;
  const board = boards.value.find(b => b.id === boardId);
  if (board) {
    const taskIndex = board.tasks.findIndex(t => t.id === taskId);
    if (taskIndex !== -1) {
      const taskToArchive = board.tasks[taskIndex];
      try {
        // SOFT DELETE instead of hard delete
        await supabase
          .from('tasks')
          .update({ 
            is_deleted: true, 
            deleted_at: new Date().toISOString() 
          })
          .eq('id', taskId);
        board.tasks.splice(taskIndex, 1);
        activeDropdown.value = null;
      } catch (e) {
        console.error('Error archiving/deleting task:', e);
      } finally {
        deletingTaskId.value = null;
      }
    }
  }
};

const moveToToday = async (currentBoardId, task) => {
  if (movingTaskId.value) return;
  movingTaskId.value = task.id;
  try {
    const TODAY_BOARD_TITLE = "Today task list";
    let { data: todayBoard, error: boardErr } = await supabase
      .from('boards')
      .select('id, title, color')
      .eq('title', TODAY_BOARD_TITLE)
      .maybeSingle();

    if (boardErr || !todayBoard) {
      const { data: newBoard, error: createErr } = await supabase
        .from('boards')
        .insert([{ 
          id: `board-today-${Date.now()}`, 
          title: TODAY_BOARD_TITLE, 
          color: '#7366FF',
          created_at: new Date().toISOString()
        }])
        .select()
        .single();
      if (createErr) throw createErr;
      todayBoard = newBoard;
    }

    const { error: updateErr } = await supabase
      .from('tasks')
      .update({ board_id: todayBoard.id })
      .eq('id', task.id);
    
    if (updateErr) throw updateErr;

    const currentBoard = boards.value.find(b => b.id === currentBoardId);
    if (currentBoard) {
      currentBoard.tasks = currentBoard.tasks.filter(t => t.id !== task.id);
    }
    
    
  } catch (e) {
    console.error('Error moving task to today:', e);
  } finally {
    movingTaskId.value = null;
  }
};

const priorityFilters = ['All', 'High', 'Medium', 'Low'];
const activePriority = ref('All');

const filteredCount = (tasks) => {
  if (!tasks) return 0;
  if (activePriority.value === 'All') return tasks.length;
  return tasks.filter(t => t.priority === activePriority.value).length;
};

// --- Board Modal State ---
const showBoardModal = ref(false);
const newBoard = reactive({
  title: '',
  description: '',
  color: '#7366FF'
});
const boardColors = [
  '#7366FF', '#FF9F43', '#28C76F', '#EA5455',
  '#00CFE8', '#FF6B6B', '#A29BFE', '#FD79A8'
];

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
    const { error } = await supabase.from('tasks').update({
      title: editForm.title,
      description: editForm.description,
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
    const locale = localStorage.getItem('userLanguage') === 'uz' ? 'uz-UZ' : 'ru-RU';
    const creationDate = new Date().toLocaleDateString(locale, { day: '2-digit', month: 'long', year: 'numeric' });
    const dbTask = {
      id: `task-${Date.now()}`,
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

const openBoardModal = () => {
  newBoard.title = '';
  newBoard.description = '';
  newBoard.color = '#7366FF';
  showBoardModal.value = true;
};

const closeBoardModal = () => {
  showBoardModal.value = false;
};

const confirmAddBoard = async () => {
  if (!newBoard.title.trim() || isSubmittingBoard.value) return;
  
  const reservedTitles = ['Today task list', 'Finished tasks'];
  if (reservedTitles.includes(newBoard.title.trim())) {
    alert("This title is reserved for the Today page. Please use a different name.");
    return;
  }

  isSubmittingBoard.value = true;
  const newBoardData = {
    id: `board-${Date.now()}`,
    title: newBoard.title.trim(),
    description: newBoard.description?.trim() || '',
    color: newBoard.color,
    created_at: new Date().toISOString()
  };
  try {
    await supabase.from('boards').insert([newBoardData]);
    boards.value.push({
      id: newBoardData.id,
      title: newBoardData.title,
      description: newBoardData.description,
      color: newBoardData.color,
      tasks: []
    });
    closeBoardModal();
  } catch (e) {
    console.error(e);
  } finally {
    isSubmittingBoard.value = false;
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
    <!-- Tasks Header Filters -->
    <div class="tasks-filters">
      <div class="priority-tabs">
        <span class="label">{{ $t('tasks.priority') }}</span>
        <button 
          v-for="p in priorityFilters" 
          :key="p"
          :class="['tab', { active: activePriority === p }]"
          @click="activePriority = p"
        >
          {{ p === 'All' ? $t('common.all') : $t('tasks.' + p.toLowerCase()) }}
        </button>
      </div>

      <div class="filter-actions">
        <button class="btn-add-board" @click="openBoardModal">
          <Plus :size="18" /> {{ $t('tasks.addBoard') }}
        </button>
      </div>
    </div>

    <!-- Kanban Board Container -->
    <div class="kanban-outer-container">
      <div class="kanban-wrapper">
        <!-- Skeleton Loading State -->
        <template v-if="isLoading">
          <div v-for="i in 4" :key="i" class="kanban-column skeleton-column">
            <div class="board-header" style="margin-bottom: 1.5rem;">
              <div class="header-main">
                <div class="skeleton" style="width: 12px; height: 12px; border-radius: 50%;"></div>
                <div class="skeleton" style="width: 100px; height: 18px;"></div>
              </div>
              <div class="skeleton" style="width: 24px; height: 24px; border-radius: 6px;"></div>
            </div>
            
            <div class="drag-area">
              <div v-for="j in 3" :key="j" class="task-card card skeleton-card">
                <div class="card-labels" style="margin-bottom: 1rem;">
                  <div class="skeleton" style="width: 70px; height: 18px; border-radius: 6px;"></div>
                </div>
                <div class="skeleton" style="width: 100%; height: 22px; margin-bottom: 1rem;"></div>
                <div class="skeleton" style="width: 70%; height: 14px; margin-bottom: 1.25rem;"></div>
                <div class="card-footer">
                   <div class="skeleton ml-auto" style="width: 60px; height: 18px;"></div>
                </div>
              </div>
            </div>
            
            <div class="skeleton" style="width: 100%; height: 45px; border-radius: 12px; margin-top: 1rem;"></div>
          </div>
        </template>

        <!-- Real Data -->
        <template v-else>
          <div v-for="board in boards" :key="board.id" class="kanban-column">
            <div class="board-header">
              <div class="header-main">
                <span class="dot" :style="{ backgroundColor: board.color }"></span>
                <h3 class="board-title">{{ board.title }}</h3>
                <span class="count">{{ filteredCount(board.tasks).toString().padStart(2, '0') }}</span>
              </div>
              <div class="dropdown-wrapper">
                <button class="btn-icon" @click="(e) => toggleDropdown('board-' + board.id, e)">
                  <MoreVertical :size="18" />
                </button>
                <div v-if="activeDropdown === 'board-' + board.id" class="dropdown-menu">
                  <button class="dropdown-item" @click="deleteBoard(board.id)">
                    <Trash2 :size="16" /> {{ $t('tasks.delete') }}
                  </button>
                </div>
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
                  <div class="card-labels">
                    <span 
                      class="tag tag-priority"
                      :style="{ backgroundColor: getPriorityColor(task.priority) }"
                    >
                      <span class="dot-small"></span>
                      {{ $t('tasks.' + task.priority.toLowerCase()) }}
                    </span>
                    <div class="dropdown-wrapper ml-auto">
                      <button class="btn-icon" @click="(e) => toggleDropdown('task-' + task.id, e)">
                        <MoreVertical :size="16" />
                      </button>
                      <div v-if="activeDropdown === 'task-' + task.id" class="dropdown-menu">
                        <button class="dropdown-item" @click="deleteTask(board.id, task.id)" :disabled="deletingTaskId === task.id">
                          <Loader2 v-if="deletingTaskId === task.id" :size="16" class="spin" />
                          <Trash2 v-else :size="16" /> 
                          {{ deletingTaskId === task.id ? $t('common.loading') : $t('tasks.delete') }}
                        </button>
                      </div>
                    </div>
                  </div>

                  <h4 class="task-title">{{ task.title }}</h4>

                  <div class="due-on">
                    <span class="label">{{ $t('tasks.dueDate') }}:</span>
                    <span class="date">{{ task.dueDate }}</span>
                  </div>

                  <div class="card-footer">
                    <button class="meta-item btn-msg" @click="openTaskDetails(task)">
                      <MessageSquare :size="16" /> {{ task.commentsList ? task.commentsList.length : task.comments }}
                    </button>
                    
                    <button 
                      v-if="board.title !== 'Today task list' && board.title !== 'Finished tasks'"
                      class="btn-move-today ml-auto" 
                      @click="moveToToday(board.id, task)"
                      :disabled="movingTaskId === task.id"
                      :title="$t('leads.moveToTodayTooltip')"
                    >
                      <Loader2 v-if="movingTaskId === task.id" :size="14" class="spin" />
                      <Zap v-else :size="14" /> 
                      {{ movingTaskId === task.id ? $t('common.loading') : $t('tasks.moveToToday') }}
                    </button>
                  </div>
                </div>
              </template>
            </draggable>

            <button class="btn-new-task" @click="openTaskModal(board.id)">
              <Plus :size="18" /> {{ $t('tasks.addTask') }}
            </button>
          </div>

          <!-- Add Board Placeholder -->
          <div class="kanban-column add-column-placeholder" @click="openBoardModal">
            <div class="placeholder-content">
              <Plus :size="32" />
              <span>{{ $t('tasks.addBoard') }}</span>
            </div>
          </div>
        </template>
      </div>
    </div>

    <!-- Add Task Modal -->
    <transition name="modal">
      <div v-if="showTaskModal" class="modal-overlay" @click.self="closeTaskModal">
        <div class="modal-box task-modal-box">
          <div class="modal-header">
            <div class="modal-title-row">
              <div class="modal-icon task-icon"><CheckSquare :size="22" /></div>
              <h2>{{ $t('tasks.addTask') }}</h2>
            </div>
            <button class="btn-icon" @click="closeTaskModal"><X :size="20" /></button>
          </div>

          <div class="modal-body">
            <!-- Title -->
            <div class="form-group">
              <label>{{ $t('tasks.taskTitle') }} <span class="required">*</span></label>
              <input
                v-model="newTask.title"
                :placeholder="$t('tasks.taskTitlePlaceholder') || 'e.g. Design landing page...'"
                @keyup.enter="confirmAddTask"
                autofocus
              />
            </div>

            <!-- Description -->
            <div class="form-group">
              <label>{{ $t('tasks.description') }} <span class="optional">({{ $t('leads.optional') }})</span></label>
              <textarea
                v-model="newTask.description"
                :placeholder="$t('tasks.descriptionPlaceholder') || 'What needs to be done?'"
                rows="3"
              ></textarea>
            </div>

            <!-- Priority -->
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
            <button
              class="btn-create-board"
              :disabled="!newTask.title.trim() || isSubmittingTask"
              @click="confirmAddTask"
            >
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

    <!-- Add Board Modal -->
    <transition name="modal">
      <div v-if="showBoardModal" class="modal-overlay" @click.self="closeBoardModal">
        <div class="modal-box">
          <div class="modal-header">
            <div class="modal-title-row">
              <div class="modal-icon"><Layout :size="22" /></div>
              <h2>{{ $t('tasks.createBoardTitle') }}</h2>
            </div>
            <button class="btn-icon" @click="closeBoardModal"><X :size="20" /></button>
          </div>

          <div class="modal-body">
            <div class="form-group">
              <label>{{ $t('tasks.boardTitle') }} <span class="required">*</span></label>
              <input
                v-model="newBoard.title"
                :placeholder="$t('tasks.boardTitlePlaceholder') || 'e.g. Design Sprint, Marketing...'"
                @keyup.enter="confirmAddBoard"
                autofocus
              />
            </div>

            <div class="form-group">
              <label>{{ $t('tasks.description') }} <span class="optional">({{ $t('leads.optional') }})</span></label>
              <textarea
                v-model="newBoard.description"
                :placeholder="$t('tasks.boardDescriptionPlaceholder') || 'What is this board about?'"
                rows="3"
              ></textarea>
            </div>

            <div class="form-group">
              <label>{{ $t('leads.stageColor') }}</label>
              <div class="color-swatches">
                <button
                  v-for="color in boardColors"
                  :key="color"
                  class="swatch"
                  :class="{ active: newBoard.color === color }"
                  :style="{ backgroundColor: color }"
                  @click="newBoard.color = color"
                >
                  <Check v-if="newBoard.color === color" :size="14" color="white" />
                </button>
              </div>
            </div>
          </div>

          <div class="modal-footer">
            <button class="btn-cancel-modal" @click="closeBoardModal" :disabled="isSubmittingBoard">{{ $t('common.cancel') }}</button>
            <button class="btn-create-board" @click="confirmAddBoard" :disabled="!newBoard.title.trim() || isSubmittingBoard">
              <template v-if="isSubmittingBoard">
                <Loader2 :size="16" class="spin" /> {{ $t('common.loading') }}
              </template>
              <template v-else>
                <Plus :size="16" /> {{ $t('tasks.addBoard') }}
              </template>
            </button>
          </div>
        </div>
      </div>
    </transition>

    <!-- Task Details Modal -->
    <transition name="modal">
      <div v-if="showTaskDetailsModal" class="modal-overlay" @click.self="closeTaskDetails">
        <div class="modal-box task-details-box">
          <div class="td-layout">
            <!-- Left Side: Task Info -->
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
                  <h2 class="td-title">{{ selectedTaskDetails.title }}</h2>
                  
                  <div class="td-desc">
                    <h3>{{ $t('tasks.description') }}</h3>
                    <p>{{ selectedTaskDetails.description || $t('tasks.noDescription') || 'No description provided.' }}</p>
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
                <div class="td-meta-item">
                  <span class="label">{{ $t('tasks.progress') }}</span>
                  <div style="display: flex; gap: 0.5rem; align-items: center;">
                    <span class="value">{{ selectedTaskDetails.progress || 0 }}%</span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Right Side: Comments -->
            <div class="td-right">
              <div class="td-right-header">
                <h3>{{ $t('leads.comments') }}</h3>
                <button class="btn-icon td-close-desktop" @click="closeTaskDetails"><X :size="20" /></button>
              </div>
              
              <div class="comments-list">
                <div v-if="selectedTaskDetails.commentsList.length === 0" class="no-comments">
                  {{ $t('leads.noComments') }}
                </div>
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
                <textarea 
                  v-model="newComment" 
                  :placeholder="$t('leads.typeComment')" 
                  @keyup.enter.prevent="addComment"
                ></textarea>
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
.tasks-page {
  padding: 1.5rem;
  background: var(--light);
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  height: calc(100vh - 70px);
}

/* Filters */
.tasks-filters {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
  gap: 1rem;
  flex-wrap: nowrap; /* Keep it in a line if possible */
}

.priority-tabs {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  background: white;
  padding: 0.5rem 1rem;
  border-radius: 12px;
  box-shadow: var(--shadow);
  flex-shrink: 0;
}

.priority-tabs .label { 
  font-weight: 700; 
  color: var(--dark); 
  margin-right: 0.5rem;
  font-size: 1rem;
}

.tab {
  padding: 0.4rem 1rem;
  border-radius: 8px;
  font-size: 0.9rem;
  font-weight: 600;
  color: var(--gray);
  border: 2px solid transparent;
  transition: all 0.2s ease;
  background: transparent;
}

.tab:hover {
  color: var(--dark);
}

.tab.active { 
  background: #f0f0ff; 
  color: var(--primary); 
  border-color: var(--primary);
}

.filter-actions {
  display: flex;
  gap: 0.75rem;
  align-items: center;
  flex-shrink: 0;
}

.select-box {
  background: white;
  padding: 0.6rem 1rem;
  border-radius: 10px;
  border: 1px solid var(--border);
  font-size: 0.85rem;
  color: var(--dark);
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.btn-add-board {
  background: var(--primary);
  color: white;
  padding: 0.6rem 1.2rem;
  border-radius: 10px;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.new-board-input-wrapper input {
  padding: 0.6rem 1rem;
  border-radius: 10px;
  border: 2px solid var(--primary);
  outline: none;
  font-family: inherit;
  width: 180px;
}

/* Kanban Container Fix for Horizontal Scroll */
.kanban-outer-container {
  flex: 1;
  overflow: hidden; /* Prevent parent from scrolling */
  position: relative;
}

.kanban-wrapper {
  display: flex;
  gap: 1.5rem;
  overflow-x: auto;
  overflow-y: hidden;
  height: 100%;
  padding-bottom: 2rem; /* Space for scrollbar */
  padding-right: 2rem;
}

.kanban-column {
  width: 320px;
  min-width: 320px;
  background: rgba(235, 237, 242, 0.4);
  padding: 1rem;
  border-radius: 16px;
  display: flex;
  flex-direction: column;
  gap: 1rem;
  height: 100%;
  box-sizing: border-box;
}

.drag-area {
  flex: 1;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding-right: 4px;
}

/* Better Scrollbar for drag area */
.drag-area::-webkit-scrollbar { width: 4px; }
.drag-area::-webkit-scrollbar-thumb { background: var(--border); border-radius: 10px; }

.board-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.header-main { display: flex; align-items: center; gap: 0.75rem; }
.dot { width: 10px; height: 10px; border-radius: 50%; }
.board-title { font-size: 1.1rem; font-weight: 700; }
.count { background: white; font-size: 0.75rem; padding: 0.2rem 0.5rem; border-radius: 6px; color: var(--gray); font-weight: 600; }

/* Card Styling */
.task-card { background: white; padding: 1.25rem; }
.ghost-card { opacity: 0.5; background: var(--primary-light) !important; border: 2px dashed var(--primary) !important; }

.card-labels { display: flex; align-items: center; gap: 0.5rem; margin-bottom: 1rem; }
.tag { font-size: 0.7rem; font-weight: 700; padding: 0.3rem 0.75rem; border-radius: 6px; }
.tag-outline { border: 1px solid var(--border); color: var(--dark); }
.tag-priority { color: white; display: flex; align-items: center; gap: 0.4rem; }
.dot-small { width: 6px; height: 6px; background: white; border-radius: 50%; }
.ml-auto { margin-left: auto; }

.task-title { font-size: 1rem; font-weight: 700; margin-bottom: 1rem; }
.progress-container { display: flex; align-items: center; gap: 1rem; margin-bottom: 1rem; }
.progress-bar { flex: 1; height: 6px; background: var(--light); border-radius: 10px; overflow: hidden; }
.progress-fill { height: 100%; border-radius: 10px; }
.progress-text { font-size: 0.8rem; font-weight: 700; color: var(--dark); }

.due-on { margin-bottom: 1.25rem; font-size: 0.85rem; }
.due-on .label { color: var(--gray); font-weight: 600; margin-right: 0.5rem; }
.due-on .date { font-weight: 700; color: var(--dark); }

.card-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: 1rem;
  border-top: 1px solid var(--border);
}

.assignees { display: flex; }
.avatar-stack { width: 28px; height: 28px; border-radius: 50%; border: 2px solid white; margin-left: -8px; display: flex; align-items: center; justify-content: center; font-size: 0.65rem; font-weight: 700; color: white; }
.avatar-stack:first-child { margin-left: 0; }
.avatar-stack.more { background: #EEE !important; color: var(--gray); }

.meta { display: flex; gap: 0.75rem; color: var(--gray); }
.meta-item { display: flex; align-items: center; gap: 0.3rem; font-size: 0.8rem; font-weight: 600; }

/* Inline Inputs */
.add-task-inline {
  padding: 1rem;
  background: white;
  border: 2px solid var(--primary);
}

.add-task-inline input {
  width: 100%;
  border: none;
  outline: none;
  font-family: inherit;
  font-size: 0.9rem;
  margin-bottom: 0.75rem;
}

.inline-actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
}

.btn-confirm { background: var(--primary); color: white; padding: 0.3rem; border-radius: 4px; }
.btn-cancel { background: var(--light); color: var(--gray); padding: 0.3rem; border-radius: 4px; }

.btn-new-task {
  width: 100%;
  padding: 0.8rem;
  background: white;
  border: 2px dashed var(--border);
  border-radius: 12px;
  color: var(--dark);
  font-weight: 600;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
}

.btn-new-task:hover { border-color: var(--primary); color: var(--primary); background: var(--primary-light); }

/* Placeholder column */
.add-column-placeholder {
  background: rgba(255, 255, 255, 0.5);
  border: 2px dashed var(--border);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.3s ease;
}

.add-column-placeholder:hover {
  background: var(--primary-light);
  border-color: var(--primary);
  color: var(--primary);
}

.placeholder-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  color: var(--gray);
}

.add-column-placeholder:hover .placeholder-content { color: var(--primary); }

.btn-icon { width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; border-radius: 6px; color: var(--gray); }
.btn-icon:hover { background: var(--light); }

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
}

.dropdown-item:hover {
  background: #fdf3f3;
}

/* Custom Scrollbar for Kanban */
.kanban-wrapper::-webkit-scrollbar { height: 8px; }
.kanban-wrapper::-webkit-scrollbar-track { background: transparent; }
.kanban-wrapper::-webkit-scrollbar-thumb { background: var(--border); border-radius: 10px; }
.kanban-wrapper::-webkit-scrollbar-thumb:hover { background: var(--gray); }

/* ========== MODAL ========== */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(75, 70, 92, 0.45);
  backdrop-filter: blur(4px);
  z-index: 1000;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1rem;
}

.modal-box {
  background: #fff;
  border-radius: 20px;
  width: 100%;
  max-width: 520px;
  box-shadow: 0 25px 60px rgba(75, 70, 92, 0.25);
  overflow: hidden;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem 1.75rem 1.25rem;
  border-bottom: 1px solid var(--border);
}

.modal-title-row {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.modal-title-row h2 {
  font-size: 1.2rem;
  font-weight: 700;
  margin: 0;
}

.modal-icon {
  width: 40px;
  height: 40px;
  background: var(--primary-light);
  color: var(--primary);
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.modal-body {
  padding: 1.75rem;
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.form-group label {
  font-size: 0.85rem;
  font-weight: 600;
  color: var(--dark);
}

.form-group .required { color: var(--danger); }
.form-group .optional { color: var(--gray); font-weight: 400; font-size: 0.8rem; }

.form-group input,
.form-group textarea {
  width: 100%;
  padding: 0.75rem 1rem;
  border: 1.5px solid var(--border);
  border-radius: 10px;
  font-family: inherit;
  font-size: 0.9rem;
  color: var(--dark);
  outline: none;
  transition: border-color 0.2s;
  resize: none;
}

.form-group input:focus,
.form-group textarea:focus {
  border-color: var(--primary);
  box-shadow: 0 0 0 3px rgba(115, 102, 255, 0.12);
}

.color-swatches {
  display: flex;
  gap: 0.75rem;
  flex-wrap: wrap;
}

.swatch {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  border: 3px solid transparent;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: transform 0.2s, border-color 0.2s;
}

.swatch:hover { transform: scale(1.15); }

.swatch.active {
  border-color: white;
  box-shadow: 0 0 0 3px currentColor;
  outline: 3px solid transparent;
  transform: scale(1.1);
}

.modal-footer {
  padding: 1.25rem 1.75rem 1.5rem;
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
  border-top: 1px solid var(--border);
}

.btn-cancel-modal {
  padding: 0.65rem 1.4rem;
  border-radius: 10px;
  border: 1.5px solid var(--border);
  font-weight: 600;
  font-family: inherit;
  color: var(--dark);
  background: white;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-cancel-modal:hover { background: var(--light); }

.btn-create-board {
  padding: 0.65rem 1.4rem;
  border-radius: 10px;
  background: var(--primary);
  color: white;
  font-weight: 600;
  font-family: inherit;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  transition: all 0.2s;
}

.btn-create-board:hover {
  background: #6259e6;
  box-shadow: 0 4px 12px rgba(115, 102, 255, 0.4);
}

/* Modal transition animation */
.modal-enter-active { transition: all 0.3s cubic-bezier(0.34, 1.56, 0.64, 1); }
.modal-leave-active { transition: all 0.2s ease; }
.modal-enter-from { opacity: 0; transform: scale(0.85); }
.modal-leave-to { opacity: 0; transform: scale(0.9); }

.modal-enter-active .modal-box { transition: inherit; }

/* ========== TASK MODAL EXTRAS ========== */
.task-modal-box {
  max-width: 580px;
}

.task-icon {
  background: #e8f9ee;
  color: var(--success);
}

.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
}

.priority-selector {
  display: flex;
  gap: 0.5rem;
}

.priority-pill {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.4rem 0.85rem;
  border-radius: 20px;
  border: 1.5px solid var(--border);
  font-size: 0.8rem;
  font-weight: 600;
  cursor: pointer;
  font-family: inherit;
  color: var(--dark);
  background: white;
  transition: all 0.2s;
}

.priority-pill:hover {
  border-color: var(--primary);
}

.pill-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  display: inline-block;
}

.progress-value {
  color: var(--primary);
  font-weight: 700;
  margin-left: 0.5rem;
}

.progress-slider {
  width: 100%;
  -webkit-appearance: none;
  appearance: none;
  height: 6px;
  border-radius: 5px;
  background: var(--light);
  outline: none;
  cursor: pointer;
  border: none;
}

.progress-slider::-webkit-slider-thumb {
  -webkit-appearance: none;
  appearance: none;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: var(--primary);
  cursor: pointer;
  box-shadow: 0 2px 6px rgba(115,102,255,0.4);
}

.progress-preview {
  margin-top: 0.5rem;
}

.progress-preview .progress-bar {
  flex: 1;
  height: 8px;
  background: var(--light);
  border-radius: 10px;
  overflow: hidden;
  width: 100%;
}

.progress-preview .progress-fill {
  height: 100%;
  border-radius: 10px;
  transition: width 0.3s ease;
}

.btn-create-board:disabled {
  opacity: 0.5;
  cursor: not-allowed;
  box-shadow: none;
}

/* Date input */
.form-group input[type="date"] {
  cursor: pointer;
  color: var(--dark);
}

/* ========== TASK DETAILS MODAL ========== */
.task-details-box {
  max-width: 900px;
  width: 95%;
  padding: 0;
  overflow: hidden;
  background: white;
}

.td-layout {
  display: flex;
  height: 600px;
  max-height: 85vh;
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
  margin-bottom: 1.5rem;
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

.no-comments {
  text-align: center;
  color: var(--gray);
  margin-top: 2rem;
  font-weight: 600;
  background: var(--light);
  padding: 1rem;
  border-radius: 10px;
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
  flex-shrink: 0;
  font-size: 1.1rem;
}

.comment-content {
  flex: 1;
}

.comment-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.4rem;
}

.comment-author {
  font-weight: 800;
  font-size: 0.95rem;
  color: var(--dark);
}

.comment-time {
  font-size: 0.75rem;
  color: var(--gray);
  font-weight: 500;
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

.btn-msg {
  background: none;
  border: none;
  padding: 0;
  font-family: inherit;
  cursor: pointer;
  transition: color 0.2s;
  display: flex;
  align-items: center;
  gap: 0.3rem; 
  font-size: 0.8rem; 
  font-weight: 600;
  color: var(--gray);
}
.btn-msg:hover {
  color: var(--primary);
}

.btn-move-today {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.4rem 0.8rem;
  background: var(--primary-light);
  color: var(--primary);
  border: none;
  border-radius: 8px;
  font-size: 0.75rem;
  font-weight: 700;
  cursor: pointer;
  transition: all 0.2s;
  white-space: nowrap;
}

.btn-move-today:hover {
  background: var(--primary);
  color: white;
  transform: translateY(-2px);
  box-shadow: 0 4px 8px rgba(115, 102, 255, 0.2);
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

@media (max-width: 768px) {
  .td-layout {
    flex-direction: column;
    height: 85vh;
  }
  .td-left { border-right: none; border-bottom: 1px solid var(--border); flex: none; height: 50%; padding: 1.5rem; }
  .td-right { width: 100%; height: 50%; }
  .td-close-desktop { display: none; }
  .td-close-mobile { display: flex; margin-left: auto; }
}
</style>
