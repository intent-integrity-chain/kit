'use strict';

/**
 * Compute board state: assign stories to todo/in_progress/done columns
 * based on their task completion status.
 *
 * Column assignment rules (from data-model.md):
 * - todo: all tasks unchecked (or no tasks)
 * - in_progress: at least 1 task checked but not all
 * - done: all tasks checked
 *
 * @param {Array<{id: string, title: string, priority: string}>} stories
 * @param {Array<{id: string, storyTag: string|null, description: string, checked: boolean}>} tasks
 * @returns {{todo: Array, in_progress: Array, done: Array}}
 */
function computeBoardState(stories, tasks) {
  const board = { todo: [], in_progress: [], done: [] };

  if (!stories || !Array.isArray(stories)) return board;
  if (!tasks) tasks = [];

  // Group tasks by storyTag or bugTag
  const tasksByStory = {};
  const tasksByBug = {};
  const untaggedTasks = [];

  for (const task of tasks) {
    if (task.storyTag) {
      if (!tasksByStory[task.storyTag]) {
        tasksByStory[task.storyTag] = [];
      }
      tasksByStory[task.storyTag].push(task);
    } else if (task.bugTag) {
      if (!tasksByBug[task.bugTag]) {
        tasksByBug[task.bugTag] = [];
      }
      tasksByBug[task.bugTag].push(task);
    } else {
      untaggedTasks.push(task);
    }
  }

  // Assign each story to a column
  for (const story of stories) {
    const storyTasks = tasksByStory[story.id] || [];
    const checkedCount = storyTasks.filter(t => t.checked).length;
    const totalCount = storyTasks.length;

    let column;
    if (totalCount === 0 || checkedCount === 0) {
      column = 'todo';
    } else if (checkedCount === totalCount) {
      column = 'done';
    } else {
      column = 'in_progress';
    }

    const card = {
      id: story.id,
      title: story.title,
      priority: story.priority,
      tasks: storyTasks,
      progress: `${checkedCount}/${totalCount}`,
      column
    };

    board[column].push(card);
  }

  // Handle untagged tasks — put them in an "Unassigned" card
  if (untaggedTasks.length > 0) {
    const checkedCount = untaggedTasks.filter(t => t.checked).length;
    const totalCount = untaggedTasks.length;

    let column;
    if (checkedCount === 0) {
      column = 'todo';
    } else if (checkedCount === totalCount) {
      column = 'done';
    } else {
      column = 'in_progress';
    }

    const card = {
      id: 'Unassigned',
      title: 'Unassigned Tasks',
      priority: 'P3',
      tasks: untaggedTasks,
      progress: `${checkedCount}/${totalCount}`,
      column
    };

    board[column].push(card);
  }

  // Handle bug fix tasks — group into per-bug cards
  for (const [bugId, bugTasks] of Object.entries(tasksByBug)) {
    const checkedCount = bugTasks.filter(t => t.checked).length;
    const totalCount = bugTasks.length;

    let column;
    if (checkedCount === 0) {
      column = 'todo';
    } else if (checkedCount === totalCount) {
      column = 'done';
    } else {
      column = 'in_progress';
    }

    const card = {
      id: bugId,
      title: `Bug Fix: ${bugId}`,
      priority: 'P2',
      tasks: bugTasks,
      progress: `${checkedCount}/${totalCount}`,
      column,
      isBugCard: true
    };

    board[column].push(card);
  }

  return board;
}

module.exports = { computeBoardState };
