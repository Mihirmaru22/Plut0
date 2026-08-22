import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { habitsRepo } from "../db/habits.js";
import { tasksRepo } from "../db/tasks.js";
import { notesRepo } from "../db/notes.js";
import { projectsRepo } from "../db/projects.js";
import { focusRepo } from "../db/focus.js";
import { lifeRepo } from "../db/life.js";
import { ghostRepo } from "../db/ghost.js";

export function registerTools(server: McpServer): void {
  // MARK: - 1. Day Architecture & Daily Briefing

  server.tool(
    "get_daily_briefing",
    "Generates a complete, real-time morning or daily briefing across habit completions, scheduled tasks, P1 high-priority tasks, and deep work focus time for today.",
    {},
    async () => {
      const habits = habitsRepo.listHabits({ activeOnly: true });
      const completedHabits = habits.filter((h) => h.todayCompleted);
      const tasksToday = tasksRepo.listTasks({ bucket: "Today", completed: false });
      const focusStats = focusRepo.getFocusStats(1);
      const recentNotes = notesRepo.searchNotes({ limit: 3 });

      const dateStr = new Date().toLocaleDateString("en-US", {
        weekday: "long",
        year: "numeric",
        month: "long",
        day: "numeric",
      });

      let briefing = `# ☀️ Daily Briefing — ${dateStr}\n\n`;

      // Habit status
      briefing += `### ⚡️ Habits & Discipline (${completedHabits.length}/${habits.length} Complete)\n`;
      if (habits.length === 0) {
        briefing += `_No active habits configured._\n`;
      } else {
        for (const h of habits) {
          const status = h.todayCompleted ? "✅" : "⏳";
          const streak = h.currentStreak > 0 ? `🔥 ${h.currentStreak}d` : "0d";
          const progress = h.metricType === "quantitative" ? ` (${h.todayLoggedValue}/${h.targetValue} ${h.unitLabel})` : "";
          briefing += `- ${status} **${h.emoji} ${h.name}**${progress} — Streak: ${streak}\n`;
        }
      }

      // Priority Tasks
      briefing += `\n### 🎯 Today's Focus Tasks (${tasksToday.length} Pending)\n`;
      if (tasksToday.length === 0) {
        briefing += `_No active tasks scheduled for today._\n`;
      } else {
        for (const t of tasksToday) {
          const due = t.dueDate ? ` ⏰ Due: ${new Date(t.dueDate).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}` : "";
          briefing += `- [ ] **[${t.priorityLabel}]** ${t.title}${due}\n`;
        }
      }

      // Focus Room
      briefing += `\n### 🧠 Focus Room Telemetry\n`;
      briefing += `- Today's Deep Work: **${focusStats.totalMinutes} minutes** across **${focusStats.totalSessions} session(s)**\n`;
      briefing += `- Micro-Goals Conquered: **${focusStats.completedGoalsCount}**\n`;

      // Recent Notes
      if (recentNotes.length > 0) {
        briefing += `\n### 📝 Recent Studio Notes\n`;
        for (const n of recentNotes) {
          briefing += `- **${n.title}** ${n.tags.join(" ")} — _"${n.snippet}"_\n`;
        }
      }

      return {
        content: [{ type: "text", text: briefing }],
      };
    }
  );

  // MARK: - 2. Habits & Streaks

  server.tool(
    "list_habits",
    "List all habit boards with their current streaks, best streaks, daily targets, units, and today's completion status.",
    {
      activeOnly: z.boolean().optional().default(true).describe("If true, only returns active unarchived habits"),
    },
    async ({ activeOnly }) => {
      const habits = habitsRepo.listHabits({ activeOnly });
      return {
        content: [{ type: "text", text: JSON.stringify(habits, null, 2) }],
      };
    }
  );

  server.tool(
    "log_habit",
    "Check in or log progress for a habit for today or a specific historical date.",
    {
      habitId: z.string().describe("UUID of the habit board"),
      value: z.number().optional().default(1.0).describe("Numeric amount logged (1.0 for binary check-ins)"),
      note: z.string().optional().describe("Optional reflection note attached to this check-in"),
      date: z.string().optional().describe("Optional ISO date string (defaults to now)"),
    },
    async ({ habitId, value, note, date }) => {
      const res = habitsRepo.logHabit({ habitId, value, note, date });
      return {
        content: [
          {
            type: "text",
            text: `✅ Habit check-in recorded successfully! Log ID: ${res.logId}. Active streak is now ${res.newStreak} days.`,
          },
        ],
      };
    }
  );

  server.tool(
    "create_habit",
    "Create a new habit board with custom target, metric type, unit label, and emoji.",
    {
      name: z.string().describe("Name of the habit (e.g. 'Cold Shower', 'Zone 2 Running')"),
      metricType: z.enum(["binary", "quantitative"]).optional().default("binary").describe("Binary (0/1) or quantitative (numeric count)"),
      targetValue: z.number().optional().describe("Numeric target for quantitative habits (e.g. 5.0)"),
      unitLabel: z.string().optional().describe("Unit string (e.g. 'miles', 'pages', 'mins')"),
      emoji: z.string().optional().default("⚡️").describe("Single emoji icon for the habit card"),
      dimension: z.enum(["focus", "energy", "stress", "mood"]).optional().describe("Life dimension affected"),
    },
    async ({ name, metricType, targetValue, unitLabel, emoji, dimension }) => {
      const habit = habitsRepo.createHabit({ name, metricType, targetValue, unitLabel, emoji, dimension });
      return {
        content: [
          {
            type: "text",
            text: `🎉 Habit '${habit.name}' created with ID: ${habit.id}.`,
          },
        ],
      };
    }
  );

  // MARK: - 3. Tasks & Day Planner

  server.tool(
    "list_tasks",
    "Query tasks filtered by priority (P1 High, P2 Med, P3 Standard, P4 Backlog), due date bucket (Today, Upcoming, Anytime), or completion.",
    {
      priority: z.number().min(1).max(4).optional().describe("1 = P1 High, 2 = P2 Med, 3 = P3 Standard, 4 = P4 Backlog"),
      bucket: z.enum(["Today", "Upcoming", "Anytime"]).optional().describe("Due date bucket"),
      completed: z.boolean().optional().describe("Filter by completion state (true = completed, false = active)"),
    },
    async (options) => {
      const tasks = tasksRepo.listTasks(options);
      return {
        content: [{ type: "text", text: JSON.stringify(tasks, null, 2) }],
      };
    }
  );

  server.tool(
    "create_task",
    "Create a new task with priority, due date, and optional notes.",
    {
      title: z.string().describe("Task title / action description"),
      priority: z.number().min(1).max(4).optional().default(3).describe("1 = P1, 2 = P2, 3 = P3, 4 = P4"),
      notes: z.string().optional().describe("Optional notes or checklist details"),
      dueDate: z.string().optional().describe("Optional ISO date string when task is due"),
    },
    async (params) => {
      const task = tasksRepo.createTask(params);
      return {
        content: [
          {
            type: "text",
            text: `🎯 Task created: [${task.priorityLabel}] '${task.title}' (ID: ${task.id})`,
          },
        ],
      };
    }
  );

  server.tool(
    "complete_task",
    "Mark a task as completed or toggle it back to active.",
    {
      taskId: z.string().describe("UUID of the task"),
      completed: z.boolean().optional().default(true).describe("true to mark done, false to un-complete"),
    },
    async ({ taskId, completed }) => {
      const res = tasksRepo.completeTask(taskId, completed);
      return {
        content: [
          {
            type: "text",
            text: `Task ${taskId} is now ${res.isCompleted ? "COMPLETED ✅" : "ACTIVE ⏳"}.`,
          },
        ],
      };
    }
  );

  server.tool(
    "schedule_task",
    "Schedule or reschedule a task's due date.",
    {
      taskId: z.string().describe("UUID of the task"),
      dueDate: z.string().describe("ISO date-time string when the task is due"),
    },
    async ({ taskId, dueDate }) => {
      tasksRepo.scheduleDueDate(taskId, dueDate);
      return {
        content: [
          {
            type: "text",
            text: `⏰ Task ${taskId} scheduled for ${dueDate}.`,
          },
        ],
      };
    }
  );

  // MARK: - 4. Notes & Studio

  server.tool(
    "search_notes",
    "Search notes full-text or filter by #tags, folder, or favorites.",
    {
      query: z.string().optional().describe("Full-text search keyword"),
      tag: z.string().optional().describe("Tag filter (e.g. '#architecture', '#ideas')"),
      folderId: z.string().optional().describe("Filter by folder UUID"),
      isFavorite: z.boolean().optional().describe("Filter favorite notes"),
      isPinned: z.boolean().optional().describe("Filter pinned notes"),
      limit: z.number().optional().default(20).describe("Max notes to return"),
    },
    async (options) => {
      const notes = notesRepo.searchNotes(options);
      return {
        content: [{ type: "text", text: JSON.stringify(notes, null, 2) }],
      };
    }
  );

  server.tool(
    "get_note",
    "Retrieve the full markdown text, checklist items, structured tables, and metadata for a specific note.",
    {
      noteId: z.string().describe("UUID of the note"),
    },
    async ({ noteId }) => {
      const note = notesRepo.getNote(noteId);
      if (!note) {
        throw new Error(`Note not found with ID: ${noteId}`);
      }
      return {
        content: [{ type: "text", text: JSON.stringify(note, null, 2) }],
      };
    }
  );

  server.tool(
    "create_note",
    "Create a new sovereign note with markdown body, tags, and folder.",
    {
      title: z.string().describe("Note title"),
      bodyText: z.string().describe("Markdown content of the note"),
      tags: z.array(z.string()).optional().describe("Array of tags like ['#strategy', '#roadmap']"),
      folderId: z.string().optional().describe("Optional folder UUID"),
      isPinned: z.boolean().optional().describe("Pin note to the top"),
      isFavorite: z.boolean().optional().describe("Mark note as favorite"),
    },
    async (params) => {
      const note = notesRepo.createNote(params);
      return {
        content: [
          {
            type: "text",
            text: `📝 Note created: '${note.title}' (ID: ${note.id}) with ${note.bodyText.length} characters.`,
          },
        ],
      };
    }
  );

  server.tool(
    "update_note",
    "Append text or update the title, body, or tags of an existing note.",
    {
      noteId: z.string().describe("UUID of the note to update"),
      title: z.string().optional().describe("New title"),
      bodyText: z.string().optional().describe("Full replacement markdown body"),
      appendText: z.string().optional().describe("Text to append to the end of the note"),
      tags: z.array(z.string()).optional().describe("Updated array of tags"),
      isPinned: z.boolean().optional().describe("Update pinned status"),
      isFavorite: z.boolean().optional().describe("Update favorite status"),
    },
    async (params) => {
      const note = notesRepo.updateNote({ ...params, id: params.noteId });
      if (!note) {
        throw new Error(`Note not found with ID: ${params.noteId}`);
      }
      return {
        content: [
          {
            type: "text",
            text: `📝 Note '${note.title}' updated successfully.`,
          },
        ],
      };
    }
  );

  // MARK: - 5. Work Projects & Milestones

  server.tool(
    "list_projects",
    "List all work projects with progress percentage, milestone count, and completion metrics.",
    {
      activeOnly: z.boolean().optional().default(true).describe("Filter active vs archived projects"),
    },
    async ({ activeOnly }) => {
      const projects = projectsRepo.listProjects({ activeOnly });
      return {
        content: [{ type: "text", text: JSON.stringify(projects, null, 2) }],
      };
    }
  );

  server.tool(
    "create_project",
    "Create a new work project with milestones and initial deliverables.",
    {
      title: z.string().describe("Project title"),
      description: z.string().optional().describe("High-level project mission and scope"),
      colorHex: z.string().optional().default("#6366F1").describe("Hex accent color"),
      initialTasks: z.array(z.string()).optional().describe("List of milestone task titles to generate"),
    },
    async (params) => {
      const project = projectsRepo.createProject(params);
      return {
        content: [
          {
            type: "text",
            text: `🚀 Project '${project.title}' created with ID: ${project.id} (${project.totalTasks} initial tasks).`,
          },
        ],
      };
    }
  );

  // MARK: - 6. Focus Room

  server.tool(
    "get_focus_stats",
    "Retrieve deep work focus statistics, total minutes, tag breakdown, and completed micro-goals.",
    {
      days: z.number().optional().default(7).describe("Number of past days to query"),
    },
    async ({ days }) => {
      const stats = focusRepo.getFocusStats(days);
      return {
        content: [{ type: "text", text: JSON.stringify(stats, null, 2) }],
      };
    }
  );

  server.tool(
    "log_focus_session",
    "Record a completed deep work focus sprint with duration and completed micro-goals.",
    {
      durationSeconds: z.number().min(60).describe("Total sprint length in seconds"),
      sessionTag: z.string().optional().default("Deep Work").describe("Tag (e.g. 'Coding', 'Writing', 'Study')"),
      category: z.string().optional().default("Study").describe("Acoustic category"),
      goals: z.array(z.string()).optional().describe("List of micro-goals conquered during session"),
    },
    async (params) => {
      const session = focusRepo.logFocusSession(params);
      return {
        content: [
          {
            type: "text",
            text: `🧠 Logged ${session.durationMinutes} minutes of focus sprint (ID: ${session.id}).`,
          },
        ],
      };
    }
  );

  // MARK: - 7. Life: Trek Atlas & Blueprint

  server.tool(
    "list_treks",
    "Query conquered mountain summits, wishlist peaks, GPS coordinates, and elevation telemetry.",
    {
      status: z.enum(["wishlist", "conquered", "inProgress"]).optional().describe("Filter by trek progression status"),
    },
    async (options) => {
      const treks = lifeRepo.listTreks(options);
      return {
        content: [{ type: "text", text: JSON.stringify(treks, null, 2) }],
      };
    }
  );

  server.tool(
    "log_summit",
    "Record a mountain peak summit conquest with coordinates, elevation, and personal expedition reflection.",
    {
      name: z.string().describe("Mountain or trek name (e.g. 'Matterhorn', 'Mount Rainier')"),
      region: z.string().optional().describe("Region / State"),
      country: z.string().optional().describe("Country"),
      latitude: z.number().describe("GPS Latitude"),
      longitude: z.number().describe("GPS Longitude"),
      elevationMeters: z.number().describe("Summit elevation in meters"),
      personalNotes: z.string().optional().describe("Expedition summary notes"),
      rating: z.number().min(1).max(5).optional().default(5).describe("Experience rating 1-5"),
    },
    async (params) => {
      const trek = lifeRepo.logSummit(params);
      return {
        content: [
          {
            type: "text",
            text: `🏔 Summit Conquered: '${trek.name}' (${trek.elevationMeters}m) recorded in Atlas!`,
          },
        ],
      };
    }
  );

  server.tool(
    "get_life_blueprint",
    "Retrieve the 10-Year Horizon Master Blueprint, Core Personal Manifesto, and decade goals.",
    {},
    async () => {
      const blueprint = lifeRepo.getLifeBlueprint();
      return {
        content: [{ type: "text", text: JSON.stringify(blueprint, null, 2) }],
      };
    }
  );

  server.tool(
    "add_blueprint_goal",
    "Add an ambitious lifetime goal or milestone to the 10-Year Life Horizon.",
    {
      category: z.enum(["Adventure", "Mastery", "Freedom", "Principles"]).describe("Horizon category"),
      title: z.string().describe("Goal title or principle statement"),
      targetYear: z.number().optional().describe("Target milestone year (e.g. 2028)"),
      manifestoNotes: z.string().optional().describe("Core motivation / personal manifesto"),
    },
    async (params) => {
      const goal = lifeRepo.addBlueprintGoal(params);
      return {
        content: [
          {
            type: "text",
            text: `🌟 Horizon Goal added to [${goal.category}]: '${goal.title}' (${goal.targetYear || "Ongoing"}).`,
          },
        ],
      };
    }
  );

  // MARK: - 6. Ghost Mode / Winter Arc Pillar

  server.tool(
    "ghost_status",
    "Inspects active Winter Arc / Ghost Mode season, day progress, Three Rings (Body, Mind, Silence), current streak, and rank.",
    {},
    async () => {
      const status = ghostRepo.getGhostStatus();
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(status, null, 2),
          },
        ],
      };
    }
  );

  server.tool(
    "ghost_check_in",
    "Executes daily check-in sealing Ghost Mode rings (Body, Mind, Silence) and logging focus silence minutes.",
    {
      bodyClosed: z.boolean().optional().describe("Whether physical forge / body ring was closed today"),
      mindClosed: z.boolean().optional().describe("Whether mental synthesis / mind ring was closed today"),
      silenceMinutes: z.number().optional().describe("Total attested focus silence or offline minutes logged"),
      reflectionNote: z.string().optional().describe("Optional evening reflection synthesis text"),
    },
    async (params) => {
      const res = ghostRepo.checkIn(params);
      return {
        content: [
          {
            type: "text",
            text: res.success
              ? `👻 Ghost Check-In Sealed: Score ${res.score}/100. Ghost Day achieved: ${res.isGhostDay ? "YES 🔥" : "NO ⏳"}`
              : `⚠️ No active Ghost Season found. Sign a covenant in Pluto first.`,
          },
        ],
      };
    }
  );
}
