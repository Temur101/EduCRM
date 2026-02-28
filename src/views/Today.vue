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
  Archive
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
      tasks: (tasksData || []).filter(t => t.board_id === b.id).map(t => ({
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
        <h2>Today's Schedule</h2>
      </div>
      <div class="priority-tabs">
        <span class="label">Priority</span>
        <button 
          v-for="p in priorityFilters" 
          :key="p"
          :class="['tab', { active: activePriority === p }]"
          @click="activePriority = p"
        >
          {{ p }}
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
                <h3 class="board-title">{{ board.title }}</h3>
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
                  <div class="card-labels">
                    <span 
                      class="tag tag-priority"
                      :style="{ backgroundColor: getPriorityColor(task.priority) }"
                    >
                      <span class="dot-small"></span>
                      {{ task.priority }}
                    </span>
                    <div class="dropdown-wrapper ml-auto">
                      <button class="btn-icon" @click="(e) => toggleDropdown('task-' + task.id, e)">
                        <MoreVertical :size="16" />
                      </button>
                      <div v-if="activeDropdown === 'task-' + task.id" class="dropdown-menu">
                        <button class="dropdown-item" @click="deleteTask(board.id, task.id)" :disabled="deletingTaskId === task.id">
                          <Loader2 v-if="deletingTaskId === task.id" :size="16" class="spin" />
                          <Trash2 v-else :size="16" /> 
                          {{ deletingTaskId === task.id ? 'Loading...' : 'Delete Task' }}
                        </button>
                      </div>
                    </div>
                  </div>

                  <h4 class="task-title">{{ task.title }}</h4>

                  <div class="due-on">
                    <div class="due-row">
                      <span class="label">Created:</span>
                      <span class="date">{{ task.dueDate }}</span>
                    </div>
                    <div v-if="task.description && task.description.includes('(Sent by:')" class="due-row sent-by">
                      <span class="label">Sent by:</span>
                      <span class="date">{{ task.description.split('(Sent by:')[1].replace(')', '').trim() }}</span>
                    </div>
                  </div>

                  <div class="card-footer">
                    <button class="meta-item btn-msg" @click="openTaskDetails(task)">
                      <MessageSquare :size="16" /> {{ task.commentsList ? task.commentsList.length : task.comments }}
                    </button>
                    <button 
                      class="btn-archive-small" 
                      @click="deleteTask(board.id, task.id)"
                      :disabled="deletingTaskId === task.id"
                    >
                      <template v-if="deletingTaskId === task.id">
                        <Loader2 :size="14" class="spin" />
                      </template>
                      <template v-else>
                        <Archive :size="14" /> Archive
                      </template>
                    </button>
                  </div>
                </div>
              </template>
            </draggable>

            <button class="btn-new-task" @click="openTaskModal(board.id)">
              <Plus :size="18" /> Add Today's Task
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
              <h2>New Today's Task</h2>
            </div>
            <button class="btn-icon" @click="closeTaskModal"><X :size="20" /></button>
          </div>
          <div class="modal-body">
            <div class="form-group">
              <label>Task Title <span class="required">*</span></label>
              <input v-model="newTask.title" placeholder="What to do today?" @keyup.enter="confirmAddTask" autofocus />
            </div>
            <div class="form-group">
              <label>Description <span class="optional">(optional)</span></label>
              <textarea v-model="newTask.description" placeholder="Notes for today..." rows="3"></textarea>
            </div>
            <div class="form-group">
              <label>Priority</label>
              <div class="priority-selector">
                <button
                  v-for="p in priorities"
                  :key="p"
                  :class="['priority-pill', { active: newTask.priority === p }]"
                  :style="newTask.priority === p ? { background: getPriorityColor(p), color: 'white' } : {}"
                  @click="newTask.priority = p"
                >
                  <span class="pill-dot" :style="{ backgroundColor: newTask.priority === p ? 'white' : getPriorityColor(p) }"></span>
                  {{ p }}
                </button>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn-cancel-modal" @click="closeTaskModal" :disabled="isSubmittingTask">Cancel</button>
            <button class="btn-create-board" :disabled="!newTask.title.trim() || isSubmittingTask" @click="confirmAddTask">
              <template v-if="isSubmittingTask">
                <Loader2 :size="16" class="spin" /> Loading...
              </template>
              <template v-else>
                <Plus :size="16" /> Add Task
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
                <span class="tag tag-priority" :style="{ backgroundColor: getPriorityColor(selectedTaskDetails.priority) }">
                  <span class="dot-small"></span> {{ selectedTaskDetails.priority }}
                </span>
                <button class="btn-icon td-close-mobile" @click="closeTaskDetails"><X :size="20" /></button>
              </div>
              <h2 class="td-title">{{ selectedTaskDetails.title }}</h2>
              <div class="td-desc">
                <h3>Description</h3>
                <p>{{ selectedTaskDetails.description || 'No description provided.' }}</p>
              </div>
              <div class="td-meta">
                <div class="td-meta-item">
                  <span class="label">Created</span>
                  <span class="value">{{ selectedTaskDetails.dueDate }}</span>
                </div>
              </div>
            </div>
            <div class="td-right">
              <div class="td-right-header">
                <h3>Comments</h3>
                <button class="btn-icon td-close-desktop" @click="closeTaskDetails"><X :size="20" /></button>
              </div>
              <div class="comments-list">
                <div v-if="selectedTaskDetails.commentsList.length === 0" class="no-comments">No comments yet.</div>
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
                <textarea v-model="newComment" placeholder="Type a comment..." @keyup.enter.prevent="addComment"></textarea>
                <div class="comment-actions">
                    <button class="btn-send-comment" :disabled="!newComment.trim()" @click="addComment">
                      <Send :size="16" /> Send
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
  align-content: flex-start;
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
  border-radius: 16px; 
  border: 1px solid transparent; 
  transition: all 0.2s;
  width: calc(50% - 0.375rem); 
  display: flex;
  flex-direction: column;
}
.task-card:hover { border-color: var(--primary); transform: translateY(-3px); }
.ghost-card { opacity: 0.4; background: var(--primary-light) !important; border: 2px dashed var(--primary) !important; }

.card-labels { display: flex; align-items: center; gap: 0.5rem; margin-bottom: 1rem; }
.tag { font-size: 0.75rem; font-weight: 700; padding: 0.35rem 0.8rem; border-radius: 8px; }
.tag-priority { color: white; display: flex; align-items: center; gap: 0.4rem; }
.dot-small { width: 6px; height: 6px; background: white; border-radius: 50%; }

.task-title { font-size: 1.1rem; font-weight: 700; margin-bottom: 1.25rem; line-height: 1.4; color: var(--dark); }

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

/* Details Modal */
.task-details-box { max-width: 900px; width: 90%; }
.td-layout { display: flex; height: 600px; }
.td-left { flex: 1; padding: 2.5rem; border-right: 1px solid var(--border); overflow-y: auto; }
.td-right { width: 380px; display: flex; flex-direction: column; background: #fcfcfc; }
.td-header { margin-bottom: 1.5rem; }
.td-title { font-size: 1.75rem; font-weight: 800; margin-bottom: 2rem; }
.td-desc h3 { font-size: 0.9rem; color: var(--gray); text-transform: uppercase; margin-bottom: 1rem; letter-spacing: 1px; }
.td-desc p { background: var(--light); padding: 1.5rem; border-radius: 12px; line-height: 1.6; }
.td-right-header { padding: 1.5rem; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; }
.comments-list { flex: 1; padding: 1.5rem; overflow-y: auto; display: flex; flex-direction: column; gap: 1.5rem; }
.comment-item { display: flex; gap: 1rem; }
.comment-avatar { width: 36px; height: 36px; border-radius: 10px; background: var(--primary-light); color: var(--primary); font-weight: 800; display: flex; align-items: center; justify-content: center; }
.comment-text { background: white; padding: 1rem; border-radius: 0 12px 12px 12px; border: 1px solid var(--border); font-size: 0.95rem; line-height: 1.5; }
.comment-input-area { padding: 1.5rem; border-top: 1px solid var(--border); display: flex; flex-direction: column; gap: 1rem; }
.comment-input-area textarea { height: 80px; padding: 1rem; border: 1.5px solid var(--border); border-radius: 12px; resize: none; outline: none; }
.btn-send-comment { background: var(--primary); color: white; padding: 0.7rem 1.5rem; border-radius: 10px; font-weight: 700; border: none; }

.spin { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }

.dropdown-menu { position: absolute; top: 100%; right: 0; background: white; border: 1px solid var(--border); border-radius: 10px; padding: 0.5rem; z-index: 100; min-width: 150px; box-shadow: 0 5px 15px rgba(0,0,0,0.1); }
.dropdown-item { width: 100%; padding: 0.6rem; border-radius: 8px; color: var(--danger); font-weight: 700; display: flex; align-items: center; gap: 0.5rem; transition: background 0.2s; }
.dropdown-item:hover { background: #fff1f0; }

@media (max-width: 900px) {
  .kanban-wrapper { flex-direction: column; align-items: center; }
  .kanban-column { width: 100%; max-width: 500px; }
  .td-layout { flex-direction: column; height: auto; }
  .td-right { width: 100%; border-top: 1px solid var(--border); }
}
</style>
