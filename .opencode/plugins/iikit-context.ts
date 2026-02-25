// OpenCode plugin: restore IIKit feature context on session start
//
// Reads .specify/active-feature and injects context into the system prompt
// so the agent knows the current feature and workflow stage after /clear.

import type { Plugin } from "opencode"
import { readFileSync, existsSync } from "fs"
import { join } from "path"

function getFeatureStage(specsDir: string, feature: string): string {
  const featureDir = join(specsDir, feature)
  if (!existsSync(featureDir)) return "unknown"

  const tasksFile = join(featureDir, "tasks.md")
  if (existsSync(tasksFile)) {
    const content = readFileSync(tasksFile, "utf-8")
    const lines = content.split("\n").filter((l) => /^- \[.\]/.test(l))
    const total = lines.length
    const done = lines.filter((l) => /^- \[[xX]\]/.test(l)).length
    if (total > 0) {
      if (done === total) return "complete"
      if (done > 0) return `implementing-${Math.floor((done * 100) / total)}%`
      return "tasks-ready"
    }
  }

  if (existsSync(join(featureDir, "plan.md"))) return "planned"
  if (existsSync(join(featureDir, "spec.md"))) return "specified"
  return "unknown"
}

function getNextStep(stage: string): string {
  if (stage === "specified") return "Next: /iikit-clarify or /iikit-02-plan"
  if (stage === "planned") return "Next: /iikit-03-checklist or /iikit-05-tasks"
  if (stage === "tasks-ready") return "Next: /iikit-06-analyze or /iikit-07-implement"
  if (stage.startsWith("implementing")) return "Next: /iikit-07-implement (resume)"
  if (stage === "complete")
    return "All tasks complete. /iikit-08-taskstoissues to export."
  return "Run /iikit-core status to see current state."
}

export const IIKitContext: Plugin = async ({ directory }) => {
  const projectDir = directory || process.cwd()

  return {
    "experimental.chat.system.transform": async ({ system }) => {
      const constitutionExists = existsSync(join(projectDir, "CONSTITUTION.md"))
      const specifyExists = existsSync(join(projectDir, ".specify"))

      if (!constitutionExists && !specifyExists) return system

      const activeFile = join(projectDir, ".specify", "active-feature")
      if (!existsSync(activeFile)) {
        return system + "\n\nIIKit project. Run /iikit-core status to see current state."
      }

      const feature = readFileSync(activeFile, "utf-8").trim()
      const specsDir = join(projectDir, "specs")

      if (!feature || !existsSync(join(specsDir, feature))) {
        return system + "\n\nIIKit project. Run /iikit-core status to see current state."
      }

      const stage = getFeatureStage(specsDir, feature)
      const next = getNextStep(stage)

      return system + `\n\nIIKit active feature: ${feature} (stage: ${stage}). ${next}`
    },
  }
}
