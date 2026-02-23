const { computeBoardState } = require('../../.claude/skills/iikit-core/scripts/dashboard/src/board');

// TS-016: Board state computes column assignment correctly
describe('computeBoardState', () => {
  test('assigns story with 0 checked tasks to todo', () => {
    const stories = [{ id: 'US1', title: 'Story One', priority: 'P1' }];
    const tasks = [
      { id: 'T001', storyTag: 'US1', description: 'Task A', checked: false },
      { id: 'T002', storyTag: 'US1', description: 'Task B', checked: false },
      { id: 'T003', storyTag: 'US1', description: 'Task C', checked: false }
    ];
    const board = computeBoardState(stories, tasks);
    expect(board.todo).toHaveLength(1);
    expect(board.in_progress).toHaveLength(0);
    expect(board.done).toHaveLength(0);
    expect(board.todo[0].id).toBe('US1');
    expect(board.todo[0].column).toBe('todo');
  });

  test('assigns story with some checked tasks to in_progress', () => {
    const stories = [{ id: 'US1', title: 'Story One', priority: 'P1' }];
    const tasks = [
      { id: 'T001', storyTag: 'US1', description: 'Task A', checked: true },
      { id: 'T002', storyTag: 'US1', description: 'Task B', checked: false },
      { id: 'T003', storyTag: 'US1', description: 'Task C', checked: false }
    ];
    const board = computeBoardState(stories, tasks);
    expect(board.todo).toHaveLength(0);
    expect(board.in_progress).toHaveLength(1);
    expect(board.done).toHaveLength(0);
    expect(board.in_progress[0].id).toBe('US1');
    expect(board.in_progress[0].column).toBe('in_progress');
  });

  test('assigns story with all checked tasks to done', () => {
    const stories = [{ id: 'US1', title: 'Story One', priority: 'P1' }];
    const tasks = [
      { id: 'T001', storyTag: 'US1', description: 'Task A', checked: true },
      { id: 'T002', storyTag: 'US1', description: 'Task B', checked: true },
      { id: 'T003', storyTag: 'US1', description: 'Task C', checked: true }
    ];
    const board = computeBoardState(stories, tasks);
    expect(board.todo).toHaveLength(0);
    expect(board.in_progress).toHaveLength(0);
    expect(board.done).toHaveLength(1);
    expect(board.done[0].id).toBe('US1');
    expect(board.done[0].column).toBe('done');
  });

  test('computes progress string correctly', () => {
    const stories = [{ id: 'US1', title: 'Story One', priority: 'P1' }];
    const tasks = [
      { id: 'T001', storyTag: 'US1', description: 'Task A', checked: true },
      { id: 'T002', storyTag: 'US1', description: 'Task B', checked: true },
      { id: 'T003', storyTag: 'US1', description: 'Task C', checked: false },
      { id: 'T004', storyTag: 'US1', description: 'Task D', checked: false },
      { id: 'T005', storyTag: 'US1', description: 'Task E', checked: false }
    ];
    const board = computeBoardState(stories, tasks);
    expect(board.in_progress[0].progress).toBe('2/5');
  });

  test('handles multiple stories in different columns', () => {
    const stories = [
      { id: 'US1', title: 'Story One', priority: 'P1' },
      { id: 'US2', title: 'Story Two', priority: 'P1' },
      { id: 'US3', title: 'Story Three', priority: 'P2' }
    ];
    const tasks = [
      // US1: all done
      { id: 'T001', storyTag: 'US1', description: 'Task A', checked: true },
      { id: 'T002', storyTag: 'US1', description: 'Task B', checked: true },
      // US2: in progress
      { id: 'T003', storyTag: 'US2', description: 'Task C', checked: true },
      { id: 'T004', storyTag: 'US2', description: 'Task D', checked: false },
      // US3: todo
      { id: 'T005', storyTag: 'US3', description: 'Task E', checked: false },
      { id: 'T006', storyTag: 'US3', description: 'Task F', checked: false }
    ];
    const board = computeBoardState(stories, tasks);
    expect(board.done).toHaveLength(1);
    expect(board.done[0].id).toBe('US1');
    expect(board.in_progress).toHaveLength(1);
    expect(board.in_progress[0].id).toBe('US2');
    expect(board.todo).toHaveLength(1);
    expect(board.todo[0].id).toBe('US3');
  });

  test('story with no matching tasks goes to todo', () => {
    const stories = [{ id: 'US1', title: 'Story One', priority: 'P1' }];
    const tasks = [];
    const board = computeBoardState(stories, tasks);
    expect(board.todo).toHaveLength(1);
    expect(board.todo[0].tasks).toEqual([]);
    expect(board.todo[0].progress).toBe('0/0');
  });

  test('includes task list on each story card', () => {
    const stories = [{ id: 'US1', title: 'Story One', priority: 'P1' }];
    const tasks = [
      { id: 'T001', storyTag: 'US1', description: 'Task A', checked: true },
      { id: 'T002', storyTag: 'US1', description: 'Task B', checked: false }
    ];
    const board = computeBoardState(stories, tasks);
    const card = board.in_progress[0];
    expect(card.tasks).toHaveLength(2);
    expect(card.tasks[0]).toEqual({ id: 'T001', storyTag: 'US1', description: 'Task A', checked: true });
    expect(card.tasks[1]).toEqual({ id: 'T002', storyTag: 'US1', description: 'Task B', checked: false });
  });

  test('handles empty stories array', () => {
    const board = computeBoardState([], []);
    expect(board.todo).toEqual([]);
    expect(board.in_progress).toEqual([]);
    expect(board.done).toEqual([]);
  });

  test('untagged tasks are grouped into Unassigned card', () => {
    const stories = [{ id: 'US1', title: 'Story One', priority: 'P1' }];
    const tasks = [
      { id: 'T001', storyTag: 'US1', description: 'Tagged task', checked: false },
      { id: 'T002', storyTag: null, description: 'Untagged task', checked: false }
    ];
    const board = computeBoardState(stories, tasks);
    // Untagged tasks should appear in an "Unassigned" card
    const allCards = [...board.todo, ...board.in_progress, ...board.done];
    const unassigned = allCards.find(c => c.id === 'Unassigned');
    expect(unassigned).toBeDefined();
    expect(unassigned.tasks).toHaveLength(1);
    expect(unassigned.tasks[0].id).toBe('T002');
  });
});
