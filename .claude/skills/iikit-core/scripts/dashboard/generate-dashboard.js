#!/usr/bin/env node
"use strict";
var __getOwnPropNames = Object.getOwnPropertyNames;
var __commonJS = (cb, mod) => function __require() {
  return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
};

// src/parser.js
var require_parser = __commonJS({
  "src/parser.js"(exports2, module2) {
    "use strict";
    var fs2 = require("fs");
    var path2 = require("path");
    function parseSpecStories2(content) {
      if (!content || typeof content !== "string") return [];
      const regex = /### User Story (\d+) - (.+?) \(Priority: (P\d+)\)/g;
      const stories = [];
      const storyStarts = [];
      let match;
      while ((match = regex.exec(content)) !== null) {
        storyStarts.push({
          id: `US${match[1]}`,
          title: match[2].trim(),
          priority: match[3],
          index: match.index
        });
      }
      for (let i = 0; i < storyStarts.length; i++) {
        const start = storyStarts[i].index;
        const end = i + 1 < storyStarts.length ? storyStarts[i + 1].index : content.length;
        const section = content.substring(start, end);
        const scenarioCount = (section.match(/^\d+\.\s+\*\*Given\*\*/gm) || []).length;
        const headingEnd = section.indexOf("\n");
        let body = headingEnd >= 0 ? section.substring(headingEnd + 1) : "";
        const separatorIdx = body.indexOf("\n---");
        if (separatorIdx >= 0) body = body.substring(0, separatorIdx);
        body = body.trim();
        stories.push({
          id: storyStarts[i].id,
          title: storyStarts[i].title,
          priority: storyStarts[i].priority,
          scenarioCount,
          body
        });
      }
      return stories;
    }
    function parseTasks2(content) {
      if (!content || typeof content !== "string") return [];
      const regex = /- \[([ x])\] (T(?:-B)?\d+)\s+(?:\[P\]\s*)?(?:\[(US\d+|BUG-\d+)\]\s*)?(.*)/g;
      const tasks = [];
      let match;
      while ((match = regex.exec(content)) !== null) {
        const id = match[2];
        const tag = match[3] || null;
        const isBugFix = id.startsWith("T-B");
        const isBugTag = tag && /^BUG-\d+$/.test(tag);
        tasks.push({
          id,
          storyTag: tag && !isBugTag ? tag : null,
          bugTag: isBugTag ? tag : null,
          description: match[4].trim(),
          checked: match[1] === "x",
          isBugFix
        });
      }
      return tasks;
    }
    function parseChecklists(checklistDir) {
      const result = { total: 0, checked: 0, percentage: 0 };
      if (!fs2.existsSync(checklistDir)) return result;
      const files = fs2.readdirSync(checklistDir).filter((f) => f.endsWith(".md"));
      const hasDomainChecklists = files.some((f) => f !== "requirements.md");
      if (!hasDomainChecklists) return result;
      for (const file of files) {
        const content = fs2.readFileSync(path2.join(checklistDir, file), "utf-8");
        const lines = content.split("\n");
        for (const line of lines) {
          if (/- \[x\]/i.test(line)) {
            result.total++;
            result.checked++;
          } else if (/- \[ \]/.test(line)) {
            result.total++;
          }
        }
      }
      result.percentage = result.total > 0 ? Math.round(result.checked / result.total * 100) : 0;
      return result;
    }
    function parseChecklistsDetailed(checklistDir) {
      if (!fs2.existsSync(checklistDir)) return [];
      const files = fs2.readdirSync(checklistDir).filter((f) => f.endsWith(".md"));
      const hasDomainChecklists = files.some((f) => f !== "requirements.md");
      if (!hasDomainChecklists) return [];
      const result = [];
      for (const file of files) {
        const content = fs2.readFileSync(path2.join(checklistDir, file), "utf-8");
        const lines = content.split("\n");
        const baseName = file.replace(/\.md$/, "");
        const name = baseName.split("-").map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
        const items = [];
        let currentCategory = null;
        let totalCount = 0;
        let checkedCount = 0;
        for (const line of lines) {
          const headingMatch = line.match(/^#{2,3}\s+(.+)/);
          if (headingMatch) {
            currentCategory = headingMatch[1].trim();
            continue;
          }
          const checkboxMatch = line.match(/^- \[([ x])\]\s+(.*)/i);
          if (!checkboxMatch) continue;
          const isChecked = checkboxMatch[1].toLowerCase() === "x";
          let itemText = checkboxMatch[2].trim();
          totalCount++;
          if (isChecked) checkedCount++;
          let chkId = null;
          const chkMatch = itemText.match(/^(CHK-\d{3})\s+/);
          if (chkMatch) {
            chkId = chkMatch[1];
            itemText = itemText.substring(chkMatch[0].length);
          }
          const tags = [];
          const tagRegex = /\[([^\]]+)\]\s*$/;
          let tagMatch;
          while (tagMatch = itemText.match(tagRegex)) {
            tags.unshift(tagMatch[1]);
            itemText = itemText.substring(0, tagMatch.index).trim();
          }
          items.push({
            text: itemText,
            checked: isChecked,
            chkId,
            category: currentCategory,
            tags
          });
        }
        result.push({
          name,
          filename: file,
          total: totalCount,
          checked: checkedCount,
          items
        });
      }
      return result;
    }
    function parseConstitutionTDD(constitutionPath) {
      if (!fs2.existsSync(constitutionPath)) return false;
      const content = fs2.readFileSync(constitutionPath, "utf-8").toLowerCase();
      const hasTDDTerms = /\btdd\b|test-first|red-green-refactor|write tests before|tests must be written before/.test(content);
      const hasMandatory = /\bmust\b|\brequired\b|non-negotiable/.test(content);
      return hasTDDTerms && hasMandatory;
    }
    function hasClarifications(specContent) {
      if (!specContent || typeof specContent !== "string") return false;
      return /^## Clarifications/m.test(specContent);
    }
    function parsePremise2(projectPath) {
      const premisePath = path2.join(projectPath, "PREMISE.md");
      if (!fs2.existsSync(premisePath)) {
        return { content: null, exists: false };
      }
      const content = fs2.readFileSync(premisePath, "utf-8");
      return { content, exists: true };
    }
    function parseConstitutionPrinciples2(projectPath) {
      const constitutionPath = path2.join(projectPath, "CONSTITUTION.md");
      if (!fs2.existsSync(constitutionPath)) {
        return { principles: [], version: null, exists: false };
      }
      const content = fs2.readFileSync(constitutionPath, "utf-8");
      const lines = content.split("\n");
      const principles = [];
      const principleRegex = /^### ([IVXLC]+)\.\s+(.+?)(?:\s+\(.*\))?\s*$/;
      let currentPrinciple = null;
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const match = line.match(principleRegex);
        if (match) {
          if (currentPrinciple) {
            finalizePrinciple(currentPrinciple);
            principles.push(currentPrinciple);
          }
          currentPrinciple = {
            number: match[1],
            name: match[2].trim(),
            text: "",
            rationale: "",
            level: "SHOULD"
          };
        } else if (currentPrinciple) {
          if (/^## /.test(line)) {
            finalizePrinciple(currentPrinciple);
            principles.push(currentPrinciple);
            currentPrinciple = null;
          } else {
            currentPrinciple.text += line + "\n";
          }
        }
      }
      if (currentPrinciple) {
        finalizePrinciple(currentPrinciple);
        principles.push(currentPrinciple);
      }
      const versionMatch = content.match(/\*\*Version\*\*:\s*(\S+)\s*\|\s*\*\*Ratified\*\*:\s*(\S+)\s*\|\s*\*\*Last Amended\*\*:\s*(\S+)/);
      const version = versionMatch ? { version: versionMatch[1], ratified: versionMatch[2], lastAmended: versionMatch[3] } : null;
      return { principles, version, exists: true };
    }
    function finalizePrinciple(principle) {
      const text = principle.text.trim();
      const rationaleMatch = text.match(/\*\*Rationale\*\*:\s*([\s\S]*?)$/m);
      if (rationaleMatch) {
        principle.rationale = rationaleMatch[1].trim();
      }
      if (/\bMUST\b/.test(text)) {
        principle.level = "MUST";
      } else if (/\bSHOULD\b/.test(text)) {
        principle.level = "SHOULD";
      } else if (/\bMAY\b/.test(text)) {
        principle.level = "MAY";
      }
      principle.text = text;
    }
    function parseRequirements(content) {
      if (!content || typeof content !== "string") return [];
      const regex = /- \*\*FR-(\d+)\*\*:\s*(.*)/g;
      const requirements = [];
      let match;
      while ((match = regex.exec(content)) !== null) {
        requirements.push({
          id: `FR-${match[1]}`,
          text: match[2].trim()
        });
      }
      return requirements;
    }
    function parseSuccessCriteria(content) {
      if (!content || typeof content !== "string") return [];
      const regex = /- \*\*SC-(\d+)\*\*:\s*(.*)/g;
      const criteria = [];
      let match;
      while ((match = regex.exec(content)) !== null) {
        criteria.push({
          id: `SC-${match[1]}`,
          text: match[2].trim()
        });
      }
      return criteria;
    }
    function parseClarifications(content) {
      if (!content || typeof content !== "string") return [];
      if (!/^## Clarifications/m.test(content)) return [];
      const clarifications = [];
      const lines = content.split("\n");
      let currentSession = null;
      let inClarifications = false;
      for (const line of lines) {
        if (/^## Clarifications/.test(line)) {
          inClarifications = true;
          continue;
        }
        if (inClarifications && /^## /.test(line) && !/^## Clarifications/.test(line)) {
          break;
        }
        if (!inClarifications) continue;
        const sessionMatch = line.match(/^### Session (\d{4}-\d{2}-\d{2})/);
        if (sessionMatch) {
          currentSession = sessionMatch[1];
          continue;
        }
        const qaMatch = line.match(/^- Q:\s*(.*?)\s*->\s*A:\s*(.*)/);
        if (qaMatch && currentSession) {
          let answer = qaMatch[2].trim();
          let refs = [];
          const refsMatch = answer.match(/\[((?:(?:FR|US|SC)-\w+(?:,\s*)?)+)\]\s*$/);
          if (refsMatch) {
            refs = refsMatch[1].split(/,\s*/).map((r) => r.trim());
            answer = answer.substring(0, answer.lastIndexOf("[")).trim();
          }
          clarifications.push({
            session: currentSession,
            question: qaMatch[1].trim(),
            answer,
            refs
          });
        }
      }
      return clarifications;
    }
    function parseStoryRequirementRefs(content) {
      if (!content || typeof content !== "string") return [];
      const edges = [];
      const storyRegex = /### User Story (\d+) - .+? \(Priority: P\d+\)/g;
      const storyStarts = [];
      let match;
      while ((match = storyRegex.exec(content)) !== null) {
        storyStarts.push({ id: `US${match[1]}`, index: match.index });
      }
      for (let i = 0; i < storyStarts.length; i++) {
        const start = storyStarts[i].index;
        const end = i + 1 < storyStarts.length ? storyStarts[i + 1].index : content.length;
        const section = content.substring(start, end);
        const storyId = storyStarts[i].id;
        const frRegex = /FR-\d+/g;
        const seen = /* @__PURE__ */ new Set();
        let frMatch;
        while ((frMatch = frRegex.exec(section)) !== null) {
          const frId = frMatch[0];
          if (!seen.has(frId)) {
            seen.add(frId);
            edges.push({ from: storyId, to: frId });
          }
        }
      }
      return edges;
    }
    function parseTechContext(content) {
      if (!content || typeof content !== "string") return [];
      const sectionMatch = content.match(/^## Technical Context\s*$/m);
      if (!sectionMatch) return [];
      const sectionStart = sectionMatch.index + sectionMatch[0].length;
      const nextSection = content.indexOf("\n## ", sectionStart);
      const sectionEnd = nextSection >= 0 ? nextSection : content.length;
      const section = content.substring(sectionStart, sectionEnd);
      const entries = [];
      const regex = /\*\*(.+?)\*\*:\s*(.+)/g;
      let match;
      while ((match = regex.exec(section)) !== null) {
        entries.push({
          label: match[1].trim(),
          value: match[2].trim()
        });
      }
      return entries;
    }
    function parseFileStructure(content) {
      if (!content || typeof content !== "string") return null;
      const sectionRegex = /^##[^#].*(?:File Structure|Project Structure|Source Code)/m;
      const sectionMatch = content.match(sectionRegex);
      if (!sectionMatch) return null;
      const afterSection = content.substring(sectionMatch.index);
      const codeBlockMatch = afterSection.match(/```(?:\w*)\n([\s\S]*?)```/);
      if (!codeBlockMatch) return null;
      const treeText = codeBlockMatch[1];
      const lines = treeText.split("\n").filter((l) => l.trim());
      if (lines.length === 0) return null;
      let rootName = "";
      let startIdx = 0;
      const firstLine = lines[0].trim();
      if (firstLine.endsWith("/") && !firstLine.includes("\u251C") && !firstLine.includes("\u2514")) {
        const dirName = firstLine.replace(/\/$/, "");
        const commonDirs = /* @__PURE__ */ new Set(["src", "lib", "test", "tests", "bin", "cmd", "pkg", "app", "api", "docs", "public", "config", "scripts", "build", "dist", "out", "vendor", "internal"]);
        const isProjectName = !commonDirs.has(dirName);
        if (isProjectName) {
          rootName = dirName;
          startIdx = 1;
        }
      }
      const entries = [];
      let bareDirDepthOffset = 0;
      for (let i = startIdx; i < lines.length; i++) {
        const line = lines[i];
        const bareDirMatch = line.match(/^([a-zA-Z0-9._-]+\/)\s*(?:#\s*(.*))?$/);
        if (bareDirMatch && !line.includes("\u251C") && !line.includes("\u2514") && !line.includes("\u2502")) {
          const name2 = bareDirMatch[1].replace(/\/$/, "");
          const comment2 = bareDirMatch[2] ? bareDirMatch[2].trim() : null;
          entries.push({ name: name2, type: "directory", comment: comment2, depth: 0 });
          bareDirDepthOffset = 1;
          continue;
        }
        let depth = 0;
        const branchMatch = line.match(/^([\s│]*)[├└]/);
        if (branchMatch) {
          const prefix = branchMatch[1];
          depth = Math.round(prefix.replace(/│/g, " ").length / 4) + bareDirDepthOffset;
        }
        const entryMatch = line.match(/[├└]──\s*([^#\n]+?)(?:\s+#\s*(.*))?$/);
        if (!entryMatch) continue;
        let name = entryMatch[1].trim();
        const comment = entryMatch[2] ? entryMatch[2].trim() : null;
        const isDir = name.endsWith("/");
        if (isDir) name = name.replace(/\/$/, "");
        entries.push({
          name,
          type: isDir ? "directory" : "file",
          comment,
          depth
        });
      }
      for (let i = 0; i < entries.length; i++) {
        if (i + 1 < entries.length && entries[i + 1].depth > entries[i].depth) {
          entries[i].type = "directory";
        }
      }
      return { rootName, entries };
    }
    function parseAsciiDiagram(content) {
      if (!content || typeof content !== "string") return null;
      const sectionMatch = content.match(/^## Architecture Overview\s*$/m);
      if (!sectionMatch) return null;
      const afterSection = content.substring(sectionMatch.index);
      const codeBlockMatch = afterSection.match(/```(?:\w*)\n([\s\S]*?)```/);
      if (!codeBlockMatch) return null;
      const raw = codeBlockMatch[1];
      const lines = raw.split("\n");
      const grid = lines.map((l) => [...l]);
      const height = grid.length;
      const width = Math.max(...grid.map((r) => r.length), 0);
      const boxCells = Array.from({ length: height }, () => new Array(width).fill(false));
      const nodes = [];
      const used = Array.from({ length: height }, () => new Array(width).fill(false));
      for (let y = 0; y < height; y++) {
        for (let x = 0; x < (grid[y] ? grid[y].length : 0); x++) {
          if (grid[y][x] === "\u250C") {
            const box = traceBox(grid, x, y, used);
            if (box) {
              for (let by = box.y; by <= box.y2; by++) {
                for (let bx = box.x; bx <= box.x2; bx++) {
                  boxCells[by][bx] = true;
                }
              }
              const textLines = [];
              for (let by = box.y + 1; by < box.y2; by++) {
                const lineText = lines[by] ? lines[by].substring(box.x + 1, box.x2).replace(/│/g, " ").trim() : "";
                if (lineText) textLines.push(lineText);
              }
              if (textLines.length > 0) {
                nodes.push({
                  id: `node-${nodes.length}`,
                  label: textLines[0],
                  content: textLines.join("\n"),
                  type: "default",
                  x: box.x,
                  y: box.y,
                  width: box.x2 - box.x,
                  height: box.y2 - box.y
                });
              }
            }
          }
        }
      }
      const leafNodes = nodes.filter((node) => {
        const containsOther = nodes.some(
          (other) => other !== node && other.x > node.x && other.y > node.y && other.x + other.width < node.x + node.width && other.y + other.height < node.y + node.height
        );
        return !containsOther;
      });
      nodes.length = 0;
      nodes.push(...leafNodes);
      const edges = [];
      const connectorChars = /* @__PURE__ */ new Set(["\u2502", "\u2500", "\u252C", "\u2534", "\u251C", "\u2524", "\u253C", "\u250C", "\u2510", "\u2514", "\u2518"]);
      for (let x = 0; x < width; x++) {
        let lastBoxIdx = -1;
        let hasConnector = false;
        let labelText = "";
        for (let y = 0; y < height; y++) {
          const ch = grid[y] && grid[y][x] ? grid[y][x] : " ";
          for (let ni = 0; ni < nodes.length; ni++) {
            const n = nodes[ni];
            if (x >= n.x && x <= n.x + n.width) {
              if (y === n.y || y === n.y + n.height) {
                if (lastBoxIdx >= 0 && lastBoxIdx !== ni && hasConnector) {
                  const existingEdge = edges.find(
                    (e) => e.from === nodes[lastBoxIdx].id && e.to === nodes[ni].id || e.from === nodes[ni].id && e.to === nodes[lastBoxIdx].id
                  );
                  if (!existingEdge) {
                    edges.push({
                      from: nodes[lastBoxIdx].id,
                      to: nodes[ni].id,
                      label: labelText.trim() || null
                    });
                  }
                }
                lastBoxIdx = ni;
                hasConnector = false;
                labelText = "";
              }
            }
          }
          if (!boxCells[y][x] && (ch === "\u2502" || ch === "\u252C" || ch === "\u2534" || ch === "\u2524" || ch === "\u251C")) {
            hasConnector = true;
            if (grid[y]) {
              const restOfLine = lines[y] ? lines[y].substring(x + 1).trim() : "";
              if (restOfLine && !connectorChars.has(restOfLine[0])) {
                labelText = restOfLine.split(/[┌┐└┘│─┬┴├┤┼]/).filter(Boolean)[0] || "";
              }
            }
          }
        }
      }
      return { nodes, edges, raw };
    }
    function traceBox(grid, startX, startY, used) {
      const height = grid.length;
      const topEdgeChars = /* @__PURE__ */ new Set(["\u2500", "\u252C", "\u2534", "\u253C"]);
      const leftEdgeChars = /* @__PURE__ */ new Set(["\u2502", "\u251C", "\u2524", "\u253C"]);
      let x2 = startX + 1;
      while (x2 < (grid[startY] ? grid[startY].length : 0) && grid[startY][x2] !== "\u2510") {
        if (!topEdgeChars.has(grid[startY][x2])) return null;
        x2++;
      }
      if (x2 >= (grid[startY] ? grid[startY].length : 0)) return null;
      let y2 = startY + 1;
      while (y2 < height && grid[y2] && grid[y2][startX] !== "\u2514") {
        if (!leftEdgeChars.has(grid[y2][startX])) return null;
        y2++;
      }
      if (y2 >= height) return null;
      if (!grid[y2] || grid[y2][x2] !== "\u2518") return null;
      for (let y = startY; y <= y2; y++) {
        for (let x = startX; x <= x2; x++) {
          if (used[y]) used[y][x] = true;
        }
      }
      return { x: startX, y: startY, x2, y2 };
    }
    function parseTesslJson(projectPath) {
      const tesslPath = path2.join(projectPath, "tessl.json");
      if (!fs2.existsSync(tesslPath)) return [];
      try {
        const content = fs2.readFileSync(tesslPath, "utf-8");
        const json = JSON.parse(content);
        if (!json.dependencies || typeof json.dependencies !== "object") return [];
        return Object.entries(json.dependencies).map(([name, info]) => ({
          name,
          version: info.version || "unknown",
          eval: null
        }));
      } catch {
        return [];
      }
    }
    function parseResearchDecisions(content) {
      if (!content || typeof content !== "string") return [];
      if (!/^## Decisions/m.test(content)) return [];
      const decisions = [];
      const lines = content.split("\n");
      let inDecisions = false;
      let current = null;
      for (const line of lines) {
        if (/^## Decisions/.test(line)) {
          inDecisions = true;
          continue;
        }
        if (inDecisions && /^## /.test(line) && !/^## Decisions/.test(line)) {
          break;
        }
        if (!inDecisions) continue;
        const titleMatch = line.match(/^### \d+\.\s+(.+)/);
        if (titleMatch) {
          if (current) decisions.push(current);
          current = { title: titleMatch[1].trim(), decision: "", rationale: "" };
          continue;
        }
        if (current) {
          const decisionMatch = line.match(/^\*\*Decision\*\*:\s*(.+)/);
          if (decisionMatch) {
            current.decision = decisionMatch[1].trim();
            continue;
          }
          const rationaleMatch = line.match(/^\*\*Rationale\*\*:\s*(.+)/);
          if (rationaleMatch) {
            current.rationale = rationaleMatch[1].trim();
          }
        }
      }
      if (current) decisions.push(current);
      return decisions;
    }
    function parseTestSpecs(content) {
      if (!content || typeof content !== "string") return [];
      const specs = [];
      const headingRegex = /### TS-(\d+): (.+)/g;
      const headingStarts = [];
      let match;
      while ((match = headingRegex.exec(content)) !== null) {
        headingStarts.push({
          id: `TS-${match[1]}`,
          title: match[2].trim(),
          index: match.index
        });
      }
      for (let i = 0; i < headingStarts.length; i++) {
        const start = headingStarts[i].index;
        const end = i + 1 < headingStarts.length ? headingStarts[i + 1].index : content.length;
        const section = content.substring(start, end);
        const typeMatch = section.match(/\*\*Type\*\*:\s*(acceptance|contract|validation)/);
        const type = typeMatch ? typeMatch[1] : "validation";
        const priorityMatch = section.match(/\*\*Priority\*\*:\s*(P\d+)/);
        const priority = priorityMatch ? priorityMatch[1] : "P3";
        let traceability = [];
        const traceMatch = section.match(/\*\*Traceability\*\*:\s*(.+)/);
        if (traceMatch) {
          traceability = traceMatch[1].split(/,\s*/).map((s) => s.trim()).filter((s) => /^(FR|SC)-\d+$/.test(s));
        }
        specs.push({
          id: headingStarts[i].id,
          title: headingStarts[i].title,
          type,
          priority,
          traceability
        });
      }
      return specs;
    }
    function parseTaskTestRefs(tasks) {
      if (!tasks || !Array.isArray(tasks)) return {};
      const refs = {};
      for (const task of tasks) {
        const matches = task.description ? task.description.match(/TS-\d+/g) : null;
        refs[task.id] = matches ? [...new Set(matches)] : [];
      }
      return refs;
    }
    function extractSection(content, heading) {
      const regex = new RegExp(`^## ${heading}\\s*$`, "m");
      const match = content.match(regex);
      if (!match) return null;
      const start = match.index + match[0].length;
      const nextSection = content.indexOf("\n## ", start);
      return content.substring(start, nextSection >= 0 ? nextSection : content.length).trim();
    }
    function parseMarkdownTable(text) {
      const lines = text.split("\n").filter((l) => l.trim().startsWith("|"));
      if (lines.length < 2) return [];
      return lines.slice(2).map(
        (line) => line.split("|").slice(1, -1).map((cell) => cell.trim())
      ).filter((cells) => cells.length > 0 && cells.some((c) => c !== ""));
    }
    function parseAnalysisFindings(content) {
      if (!content || typeof content !== "string") return [];
      const section = extractSection(content, "Findings");
      if (!section) return [];
      const rows = parseMarkdownTable(section);
      if (rows.length === 0) return [];
      return rows.map((cells) => {
        if (cells.length < 6) return null;
        const rawSeverity = cells[2];
        const resolvedMatch = rawSeverity.match(/~~(\w+)~~\s*RESOLVED/);
        const resolved = !!resolvedMatch;
        const severity = resolved ? resolvedMatch[1] : rawSeverity;
        return {
          id: cells[0],
          category: cells[1],
          severity,
          resolved,
          location: cells[3],
          summary: cells[4],
          recommendation: cells[5]
        };
      }).filter(Boolean);
    }
    function parseAnalysisCoverage(content) {
      if (!content || typeof content !== "string") return [];
      const section = extractSection(content, "Coverage Summary");
      if (!section) return [];
      const rows = parseMarkdownTable(section);
      if (rows.length === 0) return [];
      const hasPlanCols = rows[0].length >= 8;
      const isDetailed = rows[0].length >= 6;
      return rows.map((cells) => {
        const id = cells[0];
        const hasTask = /^yes$/i.test(cells[1]);
        if (isDetailed) {
          const taskIds = parseIdList(cells[2]);
          const hasTest = /^yes$/i.test(cells[3]);
          const testIds = parseIdList(cells[4]);
          if (hasPlanCols) {
            const hasPlan = /^yes$/i.test(cells[5]);
            const planRefs = parseIdList(cells[6]);
            const status2 = cells[7] && cells[7] !== "\u2014" && cells[7] !== "-" ? cells[7] : null;
            return { id, hasTask, taskIds, hasTest, testIds, hasPlan, planRefs, status: status2, notes: "" };
          }
          const status = cells[5] && cells[5] !== "\u2014" && cells[5] !== "-" ? cells[5] : null;
          return { id, hasTask, taskIds, hasTest, testIds, status, notes: "" };
        } else {
          const notes = cells[2] || "";
          return { id, hasTask, taskIds: [], hasTest: false, testIds: [], status: null, notes };
        }
      });
    }
    function parseIdList(cell) {
      if (!cell || cell === "\u2014" || cell === "-" || cell === "\u2013") return [];
      return cell.split(",").map((s) => s.trim()).filter((s) => s && s !== "\u2014" && s !== "-" && s !== "\u2013");
    }
    function parseAnalysisMetrics(content) {
      const defaults = {
        totalRequirements: 0,
        totalTasks: 0,
        totalTestSpecs: 0,
        requirementCoverage: "",
        requirementCoveragePct: 0,
        testCoverage: null,
        testCoveragePct: 100,
        criticalIssues: 0,
        highIssues: 0,
        mediumIssues: 0,
        lowIssues: 0
      };
      if (!content || typeof content !== "string") return defaults;
      const section = extractSection(content, "Metrics");
      if (!section) return defaults;
      const kvMap = {};
      const tableRows = parseMarkdownTable(section);
      if (tableRows.length > 0) {
        for (const cells of tableRows) {
          if (cells.length >= 2) kvMap[cells[0].toLowerCase()] = cells[1];
        }
      } else {
        const bulletRegex = /^-\s+(.+?):\s+(.+)$/gm;
        let match;
        while ((match = bulletRegex.exec(section)) !== null) {
          kvMap[match[1].trim().toLowerCase()] = match[2].trim();
        }
      }
      function findValue(keys) {
        for (const key of keys) {
          for (const [k, v] of Object.entries(kvMap)) {
            if (k.includes(key)) return v;
          }
        }
        return null;
      }
      function extractPct(raw) {
        if (!raw) return null;
        const pctMatch = raw.match(/(\d+)%/);
        if (pctMatch) return parseInt(pctMatch[1], 10);
        const fracMatch = raw.match(/\((\d+)%\)/);
        if (fracMatch) return parseInt(fracMatch[1], 10);
        return null;
      }
      const reqCovRaw = findValue(["requirement coverage"]);
      const testCovRaw = findValue(["test coverage"]);
      return {
        totalRequirements: parseInt(findValue(["total requirements"]) || "0", 10),
        totalTasks: parseInt(findValue(["total tasks"]) || "0", 10),
        totalTestSpecs: parseInt(findValue(["total test spec"]) || "0", 10),
        requirementCoverage: reqCovRaw || "",
        requirementCoveragePct: extractPct(reqCovRaw) || 0,
        testCoverage: testCovRaw || null,
        testCoveragePct: testCovRaw ? extractPct(testCovRaw) || 0 : 100,
        criticalIssues: parseInt(findValue(["critical"]) || "0", 10),
        highIssues: parseInt(findValue(["high"]) || "0", 10),
        mediumIssues: parseInt(findValue(["medium"]) || "0", 10),
        lowIssues: parseInt(findValue(["low"]) || "0", 10)
      };
    }
    function parseConstitutionAlignment(content) {
      if (!content || typeof content !== "string") return [];
      const section = extractSection(content, "Constitution Alignment");
      if (!section) return [];
      if (/none detected/i.test(section) && !section.includes("|")) return [];
      const rows = parseMarkdownTable(section);
      return rows.map((cells) => {
        if (cells.length < 3) return null;
        return {
          principle: cells[0],
          status: cells[1],
          evidence: cells[2]
        };
      }).filter(Boolean);
    }
    function parsePhaseSeparation(content) {
      if (!content || typeof content !== "string") return [];
      const section = extractSection(content, "Phase Separation Violations");
      if (!section) return [];
      const noneIdx = section.search(/none detected/i);
      const tableIdx = section.indexOf("|");
      if (noneIdx >= 0 && (tableIdx < 0 || noneIdx < tableIdx)) return [];
      const rows = parseMarkdownTable(section);
      return rows.map((cells) => {
        if (cells.length < 2) return null;
        const severity = cells.length >= 3 && cells[2] && cells[2] !== "\u2014" && cells[2] !== "-" && cells[2] !== "\u2013" ? cells[2] : null;
        return {
          artifact: cells[0],
          status: cells[1],
          severity
        };
      }).filter(Boolean);
    }
    function parseBugs(content) {
      if (!content || typeof content !== "string") return [];
      const validSeverities = /* @__PURE__ */ new Set(["critical", "high", "medium", "low"]);
      const validStatuses = /* @__PURE__ */ new Set(["reported", "fixed"]);
      const headingRegex = /^## (BUG-\d+)\s*$/gm;
      const bugStarts = [];
      let match;
      while ((match = headingRegex.exec(content)) !== null) {
        bugStarts.push({ id: match[1], index: match.index });
      }
      const bugs = [];
      for (let i = 0; i < bugStarts.length; i++) {
        const start = bugStarts[i].index;
        const end = i + 1 < bugStarts.length ? bugStarts[i + 1].index : content.length;
        const section = content.substring(start, end);
        const bug = {
          id: bugStarts[i].id,
          reported: extractField(section, "Reported"),
          severity: extractField(section, "Severity") || "medium",
          status: extractField(section, "Status") || "reported",
          githubIssue: extractField(section, "GitHub Issue"),
          description: extractField(section, "Description"),
          rootCause: extractField(section, "Root Cause"),
          fixReference: extractField(section, "Fix Reference")
        };
        if (!validSeverities.has(bug.severity)) {
          bug.severity = "medium";
        }
        if (!validStatuses.has(bug.status)) {
          bug.status = "reported";
        }
        bugs.push(bug);
      }
      return bugs;
    }
    function extractField(section, fieldName) {
      const regex = new RegExp(`\\*\\*${fieldName}\\*\\*:\\s*(.+)`, "m");
      const match = section.match(regex);
      if (!match) return null;
      const value = match[1].trim();
      if (!value || /^_\(/.test(value)) return null;
      return value;
    }
    module2.exports = { parseSpecStories: parseSpecStories2, parseTasks: parseTasks2, parseChecklists, parseChecklistsDetailed, parseConstitutionTDD, hasClarifications, parseConstitutionPrinciples: parseConstitutionPrinciples2, parsePremise: parsePremise2, parseRequirements, parseSuccessCriteria, parseClarifications, parseStoryRequirementRefs, parseTechContext, parseFileStructure, parseAsciiDiagram, parseTesslJson, parseResearchDecisions, parseTestSpecs, parseTaskTestRefs, parseAnalysisFindings, parseAnalysisCoverage, parseAnalysisMetrics, parseConstitutionAlignment, parsePhaseSeparation, parseBugs };
  }
});

// src/board.js
var require_board = __commonJS({
  "src/board.js"(exports2, module2) {
    "use strict";
    function computeBoardState2(stories, tasks) {
      const board = { todo: [], in_progress: [], done: [] };
      if (!stories || !Array.isArray(stories)) return board;
      if (!tasks) tasks = [];
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
      for (const story of stories) {
        const storyTasks = tasksByStory[story.id] || [];
        const checkedCount = storyTasks.filter((t) => t.checked).length;
        const totalCount = storyTasks.length;
        let column;
        if (totalCount === 0 || checkedCount === 0) {
          column = "todo";
        } else if (checkedCount === totalCount) {
          column = "done";
        } else {
          column = "in_progress";
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
      if (untaggedTasks.length > 0) {
        const checkedCount = untaggedTasks.filter((t) => t.checked).length;
        const totalCount = untaggedTasks.length;
        let column;
        if (checkedCount === 0) {
          column = "todo";
        } else if (checkedCount === totalCount) {
          column = "done";
        } else {
          column = "in_progress";
        }
        const card = {
          id: "Unassigned",
          title: "Unassigned Tasks",
          priority: "P3",
          tasks: untaggedTasks,
          progress: `${checkedCount}/${totalCount}`,
          column
        };
        board[column].push(card);
      }
      for (const [bugId, bugTasks] of Object.entries(tasksByBug)) {
        const checkedCount = bugTasks.filter((t) => t.checked).length;
        const totalCount = bugTasks.length;
        let column;
        if (checkedCount === 0) {
          column = "todo";
        } else if (checkedCount === totalCount) {
          column = "done";
        } else {
          column = "in_progress";
        }
        const card = {
          id: bugId,
          title: `Bug Fix: ${bugId}`,
          priority: "P2",
          tasks: bugTasks,
          progress: `${checkedCount}/${totalCount}`,
          column,
          isBugCard: true
        };
        board[column].push(card);
      }
      return board;
    }
    module2.exports = { computeBoardState: computeBoardState2 };
  }
});

// src/integrity.js
var require_integrity = __commonJS({
  "src/integrity.js"(exports2, module2) {
    "use strict";
    var crypto = require("crypto");
    function computeAssertionHash2(content) {
      if (!content || typeof content !== "string") return null;
      const lines = content.split("\n");
      const assertionLines = [];
      for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed.startsWith("**Given**:") || trimmed.startsWith("**When**:") || trimmed.startsWith("**Then**:")) {
          const normalized = trimmed.replace(/\s+/g, " ").trim();
          assertionLines.push(normalized);
        }
      }
      if (assertionLines.length === 0) return null;
      assertionLines.sort();
      const joined = assertionLines.join("\n");
      return crypto.createHash("sha256").update(joined, "utf8").digest("hex");
    }
    function checkIntegrity2(currentHash, storedHash) {
      if (!currentHash || !storedHash) {
        return {
          status: "missing",
          currentHash: currentHash || null,
          storedHash: storedHash || null
        };
      }
      return {
        status: currentHash === storedHash ? "valid" : "tampered",
        currentHash,
        storedHash
      };
    }
    module2.exports = { computeAssertionHash: computeAssertionHash2, checkIntegrity: checkIntegrity2 };
  }
});

// src/pipeline.js
var require_pipeline = __commonJS({
  "src/pipeline.js"(exports2, module2) {
    "use strict";
    var fs2 = require("fs");
    var path2 = require("path");
    var { parseTasks: parseTasks2, parseChecklists, parseConstitutionTDD, hasClarifications } = require_parser();
    function computePipelineState2(projectPath, featureId) {
      const featureDir = path2.join(projectPath, "specs", featureId);
      const constitutionPath = path2.join(projectPath, "CONSTITUTION.md");
      const specPath = path2.join(featureDir, "spec.md");
      const planPath = path2.join(featureDir, "plan.md");
      const checklistDir = path2.join(featureDir, "checklists");
      const testSpecsPath = path2.join(featureDir, "tests", "test-specs.md");
      const tasksPath = path2.join(featureDir, "tasks.md");
      const analysisPath = path2.join(featureDir, "analysis.md");
      const specExists = fs2.existsSync(specPath);
      const planExists = fs2.existsSync(planPath);
      const tasksExists = fs2.existsSync(tasksPath);
      const testSpecsExists = fs2.existsSync(testSpecsPath);
      const constitutionExists = fs2.existsSync(constitutionPath);
      const premiseExists = fs2.existsSync(path2.join(projectPath, "PREMISE.md"));
      const analysisExists = fs2.existsSync(analysisPath);
      const specContent = specExists ? fs2.readFileSync(specPath, "utf-8") : "";
      const tasksContent = tasksExists ? fs2.readFileSync(tasksPath, "utf-8") : "";
      const tasks = parseTasks2(tasksContent);
      const checkedCount = tasks.filter((t) => t.checked).length;
      const totalCount = tasks.length;
      const checklistStatus = parseChecklists(checklistDir);
      const tddRequired = constitutionExists ? parseConstitutionTDD(constitutionPath) : false;
      const phases = [
        {
          id: "constitution",
          name: premiseExists ? "Premise &\nConstitution" : "Constitution",
          status: constitutionExists ? "complete" : "not_started",
          progress: null,
          optional: false
        },
        {
          id: "spec",
          name: "Spec",
          status: specExists ? "complete" : "not_started",
          progress: null,
          optional: false
        },
        {
          id: "clarify",
          name: "Clarify",
          status: hasClarifications(specContent) ? "complete" : planExists && !hasClarifications(specContent) ? "skipped" : "not_started",
          progress: null,
          optional: true
        },
        {
          id: "plan",
          name: "Plan",
          status: planExists ? "complete" : "not_started",
          progress: null,
          optional: false
        },
        {
          id: "checklist",
          name: "Checklist",
          status: checklistStatus.total === 0 ? "not_started" : checklistStatus.checked === checklistStatus.total ? "complete" : "in_progress",
          progress: checklistStatus.total > 0 ? `${Math.round(checklistStatus.checked / checklistStatus.total * 100)}%` : null,
          optional: false
        },
        {
          id: "testify",
          name: "Testify",
          status: testSpecsExists ? "complete" : !tddRequired && planExists ? "skipped" : "not_started",
          progress: null,
          optional: !tddRequired
        },
        {
          id: "tasks",
          name: "Tasks",
          status: tasksExists ? "complete" : "not_started",
          progress: null,
          optional: false
        },
        {
          id: "analyze",
          name: "Analyze",
          status: analysisExists ? "complete" : "not_started",
          progress: null,
          optional: false
        },
        {
          id: "implement",
          name: "Implement",
          status: totalCount === 0 || checkedCount === 0 ? "not_started" : checkedCount === totalCount ? "complete" : "in_progress",
          progress: totalCount > 0 && checkedCount > 0 ? `${Math.round(checkedCount / totalCount * 100)}%` : null,
          optional: false
        }
      ];
      return { phases };
    }
    module2.exports = { computePipelineState: computePipelineState2 };
  }
});

// src/storymap.js
var require_storymap = __commonJS({
  "src/storymap.js"(exports2, module2) {
    "use strict";
    var fs2 = require("fs");
    var path2 = require("path");
    var { parseSpecStories: parseSpecStories2, parseRequirements, parseSuccessCriteria, parseClarifications, parseStoryRequirementRefs } = require_parser();
    function computeStoryMapState2(projectPath, featureId) {
      const featureDir = path2.join(projectPath, "specs", featureId);
      const specPath = path2.join(featureDir, "spec.md");
      if (!fs2.existsSync(specPath)) {
        return { stories: [], requirements: [], successCriteria: [], clarifications: [], edges: [] };
      }
      const content = fs2.readFileSync(specPath, "utf-8");
      const rawStories = parseSpecStories2(content);
      const requirements = parseRequirements(content);
      const successCriteria = parseSuccessCriteria(content);
      const clarifications = parseClarifications(content);
      const edges = parseStoryRequirementRefs(content);
      const clarificationCount = clarifications.length;
      const stories = rawStories.map((s) => ({
        ...s,
        clarificationCount
      }));
      return { stories, requirements, successCriteria, clarifications, edges };
    }
    module2.exports = { computeStoryMapState: computeStoryMapState2 };
  }
});

// src/planview.js
var require_planview = __commonJS({
  "src/planview.js"(exports2, module2) {
    "use strict";
    var fs2 = require("fs");
    var path2 = require("path");
    var childProcess = require("child_process");
    var { promisify } = require("util");
    var { parseTechContext, parseFileStructure, parseAsciiDiagram, parseTesslJson, parseResearchDecisions } = require_parser();
    module2.exports = { computePlanViewState: computePlanViewState2, classifyNodeTypes, fetchTesslEvalData };
    var classificationCache = /* @__PURE__ */ new Map();
    async function computePlanViewState2(projectPath, featureId, options = {}) {
      const evalFetcher = options.fetchEvalData || fetchTesslEvalData;
      const featureDir = path2.join(projectPath, "specs", featureId);
      const planPath = path2.join(featureDir, "plan.md");
      if (!fs2.existsSync(planPath)) {
        return {
          techContext: [],
          researchDecisions: [],
          fileStructure: null,
          diagram: null,
          tesslTiles: [],
          exists: false
        };
      }
      const planContent = fs2.readFileSync(planPath, "utf-8");
      const techContext = parseTechContext(planContent);
      const researchPath = path2.join(featureDir, "research.md");
      let researchDecisions = [];
      if (fs2.existsSync(researchPath)) {
        const researchContent = fs2.readFileSync(researchPath, "utf-8");
        researchDecisions = parseResearchDecisions(researchContent);
      }
      let fileStructure = parseFileStructure(planContent);
      if (fileStructure) {
        fileStructure.entries = fileStructure.entries.map((entry) => {
          const filePath = buildFilePath(fileStructure.entries, entry, fileStructure.rootName);
          const fullPath = path2.join(projectPath, filePath);
          return { ...entry, exists: fs2.existsSync(fullPath) };
        });
      }
      let diagram = parseAsciiDiagram(planContent);
      if (diagram && diagram.nodes.length > 0) {
        const cacheKey = `${featureId}:${planContent.length}`;
        if (classificationCache.has(cacheKey)) {
          const cached = classificationCache.get(cacheKey);
          diagram.nodes = diagram.nodes.map((n) => ({
            ...n,
            type: cached[n.label] || "default"
          }));
        } else {
          const labels = diagram.nodes.map((n) => n.label);
          const types = await classifyNodeTypes(labels);
          classificationCache.set(cacheKey, types);
          diagram.nodes = diagram.nodes.map((n) => ({
            ...n,
            type: types[n.label] || "default"
          }));
        }
      }
      const tesslTiles = parseTesslJson(projectPath);
      const evalResults = await Promise.all(
        tesslTiles.map((tile) => evalFetcher(tile.name).catch(() => null))
      );
      tesslTiles.forEach((tile, i) => {
        tile.eval = evalResults[i];
      });
      return {
        techContext,
        researchDecisions,
        fileStructure,
        diagram,
        tesslTiles,
        exists: true
      };
    }
    function buildFilePath(entries, targetEntry, rootName) {
      const idx = entries.indexOf(targetEntry);
      const parts = [targetEntry.name];
      let currentDepth = targetEntry.depth;
      for (let i = idx - 1; i >= 0; i--) {
        if (entries[i].depth < currentDepth && entries[i].type === "directory") {
          parts.unshift(entries[i].name);
          currentDepth = entries[i].depth;
          if (currentDepth === 0) break;
        }
      }
      if (currentDepth === 0 && rootName && parts[0] !== rootName) {
        let hasDepth0DirParent = false;
        for (let i = idx - 1; i >= 0; i--) {
          if (entries[i].depth === 0 && entries[i].type === "directory") {
            hasDepth0DirParent = true;
            break;
          }
        }
        if (!hasDepth0DirParent) {
          parts.unshift(rootName);
        }
      }
      return parts.join("/");
    }
    async function classifyNodeTypes(labels) {
      const result = {};
      for (const label of labels) result[label] = "default";
      const apiKey = process.env.ANTHROPIC_API_KEY;
      if (!apiKey || labels.length === 0) return result;
      try {
        const Anthropic = require("@anthropic-ai/sdk");
        const client = new Anthropic({ apiKey });
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 5e3);
        const response = await client.messages.create({
          model: "claude-haiku-4-5-20251001",
          max_tokens: 256,
          messages: [{
            role: "user",
            content: `Classify each of these software architecture diagram component labels into exactly one category: "client", "server", "storage", or "external".

Labels: ${JSON.stringify(labels)}

Respond with ONLY a JSON object mapping each label to its category. Example: {"Browser": "client", "API Server": "server"}
No explanation, just the JSON.`
          }]
        }, { signal: controller.signal });
        clearTimeout(timeout);
        const text = response.content[0]?.text || "";
        const jsonMatch = text.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          const parsed = JSON.parse(jsonMatch[0]);
          const validTypes = /* @__PURE__ */ new Set(["client", "server", "storage", "external"]);
          for (const [label, type] of Object.entries(parsed)) {
            if (validTypes.has(type)) {
              result[label] = type;
            }
          }
        }
      } catch {
      }
      return result;
    }
    var evalCache = /* @__PURE__ */ new Map();
    async function fetchTesslEvalData(tileName) {
      if (evalCache.has(tileName)) return evalCache.get(tileName);
      try {
        const execAsync = promisify(childProcess.exec);
        const { stdout: listOut } = await execAsync(
          `tessl eval list --json --tile "${tileName}" --limit 1`,
          { timeout: 1e4 }
        );
        const listJson = JSON.parse(listOut.substring(listOut.indexOf("{")));
        if (!listJson.data || listJson.data.length === 0) {
          evalCache.set(tileName, null);
          return null;
        }
        const completedRun = listJson.data.find((r) => r.attributes && r.attributes.status === "completed");
        if (!completedRun) {
          evalCache.set(tileName, null);
          return null;
        }
        const { stdout: viewOut } = await execAsync(
          `tessl eval view --json ${completedRun.id}`,
          { timeout: 15e3 }
        );
        const viewJson = JSON.parse(viewOut.substring(viewOut.indexOf("{")));
        const evalData = computeEvalSummary(viewJson.data);
        evalCache.set(tileName, evalData);
        return evalData;
      } catch {
        evalCache.set(tileName, null);
        return null;
      }
    }
    function computeEvalSummary(evalRun) {
      if (!evalRun || !evalRun.attributes || !evalRun.attributes.scenarios) return null;
      let usageTotal = 0, usageMax = 0, baselineTotal = 0;
      let pass = 0, fail = 0;
      for (const scenario of evalRun.attributes.scenarios) {
        if (!scenario.solutions) continue;
        const usageSpec = scenario.solutions.find((s) => s.variant === "usage-spec");
        const baseline = scenario.solutions.find((s) => s.variant === "baseline");
        if (usageSpec && usageSpec.assessmentResults) {
          for (const r of usageSpec.assessmentResults) {
            usageTotal += r.score;
            usageMax += r.max_score;
            if (r.score === r.max_score) pass++;
            else fail++;
          }
        }
        if (baseline && baseline.assessmentResults) {
          for (const r of baseline.assessmentResults) {
            baselineTotal += r.score;
          }
        }
      }
      if (usageMax === 0) return null;
      const score = Math.round(usageTotal / usageMax * 100);
      const multiplier = baselineTotal > 0 ? Math.round(usageTotal / baselineTotal * 100) / 100 : null;
      return { score, multiplier, chartData: { pass, fail } };
    }
    function invalidateEvalCache() {
      evalCache.clear();
    }
    module2.exports.invalidateEvalCache = invalidateEvalCache;
    function invalidateCache(featureId) {
      for (const key of classificationCache.keys()) {
        if (key.startsWith(`${featureId}:`)) {
          classificationCache.delete(key);
        }
      }
    }
    module2.exports.invalidateCache = invalidateCache;
  }
});

// src/checklist.js
var require_checklist = __commonJS({
  "src/checklist.js"(exports2, module2) {
    "use strict";
    var path2 = require("path");
    var { parseChecklistsDetailed } = require_parser();
    function percentageToColor(percentage) {
      if (percentage <= 33) return "red";
      if (percentage <= 66) return "yellow";
      return "green";
    }
    function computeGateStatus(files) {
      if (files.length === 0) {
        return { status: "blocked", level: "red", label: "GATE: BLOCKED" };
      }
      const anyAtZero = files.some((f) => f.percentage === 0);
      if (anyAtZero) {
        return { status: "blocked", level: "red", label: "GATE: BLOCKED" };
      }
      const allComplete = files.every((f) => f.percentage === 100);
      if (allComplete) {
        return { status: "open", level: "green", label: "GATE: OPEN" };
      }
      return { status: "blocked", level: "yellow", label: "GATE: BLOCKED" };
    }
    function computeChecklistViewState2(projectPath, featureId) {
      const checklistDir = path2.join(projectPath, "specs", featureId, "checklists");
      const parsed = parseChecklistsDetailed(checklistDir);
      const files = parsed.map((file) => {
        const percentage = file.total > 0 ? Math.round(file.checked / file.total * 100) : 0;
        return {
          ...file,
          percentage,
          color: percentageToColor(percentage)
        };
      });
      const gate = computeGateStatus(files);
      return { files, gate };
    }
    module2.exports = { computeChecklistViewState: computeChecklistViewState2 };
  }
});

// src/testify.js
var require_testify = __commonJS({
  "src/testify.js"(exports2, module2) {
    "use strict";
    var path2 = require("path");
    var fs2 = require("fs");
    var { parseRequirements, parseSuccessCriteria, parseTestSpecs, parseTasks: parseTasks2, parseTaskTestRefs } = require_parser();
    var { computeAssertionHash: computeAssertionHash2, checkIntegrity: checkIntegrity2 } = require_integrity();
    function buildEdges(requirements, testSpecs, taskTestRefs) {
      const edges = [];
      const reqIds = new Set(requirements.map((r) => r.id));
      const tsIds = new Set(testSpecs.map((t) => t.id));
      for (const ts of testSpecs) {
        for (const reqId of ts.traceability) {
          if (reqIds.has(reqId)) {
            edges.push({ from: reqId, to: ts.id, type: "requirement-to-test" });
          }
        }
      }
      for (const [taskId, tsRefs] of Object.entries(taskTestRefs)) {
        for (const tsId of tsRefs) {
          if (tsIds.has(tsId)) {
            edges.push({ from: tsId, to: taskId, type: "test-to-task" });
          }
        }
      }
      return edges;
    }
    function findGaps(requirements, testSpecs, edges) {
      const reqWithOutgoing = new Set(
        edges.filter((e) => e.type === "requirement-to-test").map((e) => e.from)
      );
      const tsWithOutgoing = new Set(
        edges.filter((e) => e.type === "test-to-task").map((e) => e.from)
      );
      return {
        untestedRequirements: requirements.map((r) => r.id).filter((id) => !reqWithOutgoing.has(id)),
        unimplementedTests: testSpecs.map((t) => t.id).filter((id) => !tsWithOutgoing.has(id))
      };
    }
    function buildPyramid(testSpecs) {
      const groups = { acceptance: [], contract: [], validation: [] };
      for (const ts of testSpecs) {
        if (groups[ts.type]) {
          groups[ts.type].push(ts.id);
        }
      }
      return {
        acceptance: { count: groups.acceptance.length, ids: groups.acceptance },
        contract: { count: groups.contract.length, ids: groups.contract },
        validation: { count: groups.validation.length, ids: groups.validation }
      };
    }
    function computeTestifyState2(projectPath, featureId) {
      const featureDir = path2.join(projectPath, "specs", featureId);
      const specPath = path2.join(featureDir, "spec.md");
      const testSpecsPath = path2.join(featureDir, "tests", "test-specs.md");
      const tasksPath = path2.join(featureDir, "tasks.md");
      const contextPath = path2.join(featureDir, "context.json");
      const emptyState = {
        requirements: [],
        testSpecs: [],
        tasks: [],
        edges: [],
        gaps: { untestedRequirements: [], unimplementedTests: [] },
        pyramid: {
          acceptance: { count: 0, ids: [] },
          contract: { count: 0, ids: [] },
          validation: { count: 0, ids: [] }
        },
        integrity: { status: "missing", currentHash: null, storedHash: null },
        exists: false
      };
      if (!fs2.existsSync(featureDir)) return emptyState;
      const specContent = fs2.existsSync(specPath) ? fs2.readFileSync(specPath, "utf-8") : "";
      const frReqs = parseRequirements(specContent);
      const scReqs = parseSuccessCriteria(specContent);
      const requirements = [...frReqs, ...scReqs];
      const testSpecsExist = fs2.existsSync(testSpecsPath);
      const testSpecsContent = testSpecsExist ? fs2.readFileSync(testSpecsPath, "utf-8") : "";
      const testSpecs = testSpecsExist ? parseTestSpecs(testSpecsContent) : [];
      const tasksContent = fs2.existsSync(tasksPath) ? fs2.readFileSync(tasksPath, "utf-8") : "";
      const rawTasks = parseTasks2(tasksContent);
      const taskTestRefs = parseTaskTestRefs(rawTasks);
      const tasks = rawTasks.map((t) => ({
        id: t.id,
        description: t.description,
        testSpecRefs: taskTestRefs[t.id] || []
      }));
      const edges = buildEdges(requirements, testSpecs, taskTestRefs);
      const gaps = findGaps(requirements, testSpecs, edges);
      const pyramid = buildPyramid(testSpecs);
      let integrity = { status: "missing", currentHash: null, storedHash: null };
      if (testSpecsExist) {
        const currentHash = computeAssertionHash2(testSpecsContent);
        let storedHash = null;
        if (fs2.existsSync(contextPath)) {
          try {
            const context = JSON.parse(fs2.readFileSync(contextPath, "utf-8"));
            storedHash = context?.testify?.assertion_hash || null;
          } catch {
          }
        }
        integrity = checkIntegrity2(currentHash, storedHash);
      }
      return {
        requirements,
        testSpecs,
        tasks,
        edges,
        gaps,
        pyramid,
        integrity,
        exists: testSpecsExist
      };
    }
    module2.exports = { buildEdges, findGaps, buildPyramid, computeTestifyState: computeTestifyState2 };
  }
});

// src/analyze.js
var require_analyze = __commonJS({
  "src/analyze.js"(exports2, module2) {
    "use strict";
    var fs2 = require("fs");
    var path2 = require("path");
    var {
      parseAnalysisFindings,
      parseAnalysisCoverage,
      parseAnalysisMetrics,
      parseConstitutionAlignment,
      parsePhaseSeparation,
      parseRequirements,
      parseSuccessCriteria
    } = require_parser();
    var SEVERITY_PENALTIES = { CRITICAL: 25, HIGH: 15, MEDIUM: 5, LOW: 2 };
    function computePhaseSeparationScore(violations) {
      if (!violations || violations.length === 0) return 100;
      const penalty = violations.reduce((sum, v) => {
        return sum + (SEVERITY_PENALTIES[v.severity] || 0);
      }, 0);
      return Math.max(0, 100 - penalty);
    }
    function computeConstitutionCompliance(entries) {
      if (!entries || entries.length === 0) return 100;
      const aligned = entries.filter((e) => e.status === "ALIGNED").length;
      return Math.round(aligned / entries.length * 100);
    }
    function computeHealthScore(factors) {
      const { requirementsCoverage, constitutionCompliance, phaseSeparation, testCoverage } = factors;
      const score = Math.round(
        (requirementsCoverage + constitutionCompliance + phaseSeparation + testCoverage) / 4
      );
      let zone;
      if (score <= 40) zone = "red";
      else if (score <= 70) zone = "yellow";
      else zone = "green";
      return {
        score,
        zone,
        factors: {
          requirementsCoverage: { value: requirementsCoverage, label: "Requirements Coverage" },
          constitutionCompliance: { value: constitutionCompliance, label: "Constitution Compliance" },
          phaseSeparation: { value: phaseSeparation, label: "Phase Separation" },
          testCoverage: { value: testCoverage, label: "Test Coverage" }
        }
      };
    }
    function mapCellStatus(hasArtifact, ids, statusStr) {
      if (statusStr && /partial/i.test(statusStr)) {
        return { status: "partial", refs: ids || [] };
      }
      if (hasArtifact && ids && ids.length > 0) {
        return { status: "covered", refs: ids };
      }
      if (!hasArtifact || !ids || ids.length === 0) {
        return { status: "missing", refs: [] };
      }
      return { status: "covered", refs: ids };
    }
    function buildHeatmapRows(requirements, coverageEntries) {
      if (!requirements || requirements.length === 0) return [];
      const coverageMap = {};
      for (const entry of coverageEntries || []) {
        coverageMap[entry.id] = entry;
      }
      return requirements.map((req) => {
        const coverage = coverageMap[req.id];
        if (!coverage) {
          return {
            id: req.id,
            text: req.text,
            cells: {
              tasks: { status: "missing", refs: [] },
              tests: { status: "missing", refs: [] },
              plan: { status: "na", refs: [] }
            }
          };
        }
        return {
          id: req.id,
          text: req.text,
          cells: {
            tasks: mapCellStatus(coverage.hasTask, coverage.taskIds, coverage.status === "Partial" && !coverage.hasTask ? "Partial" : null),
            tests: mapCellStatus(coverage.hasTest, coverage.testIds, null),
            plan: coverage.hasPlan !== void 0 ? mapCellStatus(coverage.hasPlan, coverage.planRefs, null) : { status: "na", refs: [] }
          }
        };
      });
    }
    function computeAnalyzeState2(projectPath, featureId) {
      const featureDir = path2.join(projectPath, "specs", featureId);
      const analysisPath = path2.join(featureDir, "analysis.md");
      const specPath = path2.join(featureDir, "spec.md");
      if (!fs2.existsSync(analysisPath)) {
        return {
          healthScore: null,
          heatmap: { columns: [], rows: [] },
          issues: [],
          metrics: null,
          constitutionAlignment: [],
          exists: false
        };
      }
      const analysisContent = fs2.readFileSync(analysisPath, "utf-8");
      const specContent = fs2.existsSync(specPath) ? fs2.readFileSync(specPath, "utf-8") : "";
      const findings = parseAnalysisFindings(analysisContent);
      const coverage = parseAnalysisCoverage(analysisContent);
      const metrics = parseAnalysisMetrics(analysisContent);
      const constitutionAlignment = parseConstitutionAlignment(analysisContent);
      const phaseSeparationViolations = parsePhaseSeparation(analysisContent);
      const requirements = [
        ...parseRequirements(specContent),
        ...parseSuccessCriteria(specContent)
      ];
      const heatmapRows = buildHeatmapRows(requirements, coverage);
      const reqCovPct = metrics.requirementCoveragePct || 0;
      const testCovPct = metrics.testCoveragePct || 100;
      const constitutionCompliancePct = computeConstitutionCompliance(constitutionAlignment);
      const phaseSepScore = computePhaseSeparationScore(
        phaseSeparationViolations.filter((v) => v.severity)
      );
      const healthScore = computeHealthScore({
        requirementsCoverage: reqCovPct,
        constitutionCompliance: constitutionCompliancePct,
        phaseSeparation: phaseSepScore,
        testCoverage: testCovPct
      });
      const issues = findings.map((f) => ({
        id: f.id,
        category: f.category,
        severity: f.severity.toLowerCase(),
        location: f.location,
        summary: f.summary,
        recommendation: f.recommendation,
        resolved: f.resolved
      }));
      return {
        healthScore: {
          ...healthScore,
          trend: null
        },
        heatmap: {
          columns: ["tasks", "tests", "plan"],
          rows: heatmapRows
        },
        issues,
        metrics: {
          totalRequirements: metrics.totalRequirements,
          totalTasks: metrics.totalTasks,
          totalTestSpecs: metrics.totalTestSpecs,
          requirementCoverage: metrics.requirementCoverage,
          criticalIssues: metrics.criticalIssues,
          highIssues: metrics.highIssues,
          mediumIssues: metrics.mediumIssues,
          lowIssues: metrics.lowIssues
        },
        constitutionAlignment: constitutionAlignment.map((a) => ({
          principle: a.principle,
          status: a.status,
          evidence: a.evidence
        })),
        exists: true
      };
    }
    module2.exports = {
      computeHealthScore,
      computeAnalyzeState: computeAnalyzeState2,
      buildHeatmapRows,
      mapCellStatus,
      computePhaseSeparationScore,
      computeConstitutionCompliance
    };
  }
});

// src/bugs.js
var require_bugs = __commonJS({
  "src/bugs.js"(exports2, module2) {
    "use strict";
    var fs2 = require("fs");
    var path2 = require("path");
    var { parseBugs, parseTasks: parseTasks2 } = require_parser();
    var SEVERITY_ORDER = { critical: 0, high: 1, medium: 2, low: 3 };
    function resolveGitHubIssueUrl(issueRef, repoUrl) {
      if (!issueRef || !repoUrl) return null;
      if (/^_\(/.test(issueRef)) return null;
      const numMatch = issueRef.match(/#(\d+)/);
      if (!numMatch) return null;
      const issueNumber = numMatch[1];
      let baseUrl = repoUrl;
      const sshMatch = baseUrl.match(/^git@([^:]+):(.+?)(?:\.git)?$/);
      if (sshMatch) {
        baseUrl = `https://${sshMatch[1]}/${sshMatch[2]}`;
      }
      baseUrl = baseUrl.replace(/\.git$/, "");
      return `${baseUrl}/issues/${issueNumber}`;
    }
    function computeBugsState2(projectPath, featureId) {
      const featureDir = path2.join(projectPath, "specs", featureId);
      const bugsPath = path2.join(featureDir, "bugs.md");
      const tasksPath = path2.join(featureDir, "tasks.md");
      const emptySummary = {
        total: 0,
        open: 0,
        fixed: 0,
        highestOpenSeverity: null,
        bySeverity: { critical: 0, high: 0, medium: 0, low: 0 }
      };
      if (!fs2.existsSync(bugsPath)) {
        return { exists: false, bugs: [], orphanedTasks: [], summary: emptySummary, repoUrl: null };
      }
      const bugsContent = fs2.readFileSync(bugsPath, "utf-8");
      const bugs = parseBugs(bugsContent);
      const tasksContent = fs2.existsSync(tasksPath) ? fs2.readFileSync(tasksPath, "utf-8") : "";
      const allTasks = parseTasks2(tasksContent);
      const bugFixTasks = allTasks.filter((t) => t.isBugFix && t.bugTag);
      const tasksByBug = {};
      for (const task of bugFixTasks) {
        if (!tasksByBug[task.bugTag]) tasksByBug[task.bugTag] = [];
        tasksByBug[task.bugTag].push(task);
      }
      const bugIds = new Set(bugs.map((b) => b.id));
      for (const bug of bugs) {
        const tasks = tasksByBug[bug.id] || [];
        bug.fixTasks = {
          total: tasks.length,
          checked: tasks.filter((t) => t.checked).length,
          tasks: tasks.map((t) => ({
            id: t.id,
            description: t.description,
            checked: t.checked
          }))
        };
      }
      bugs.sort((a, b) => {
        const sevA = SEVERITY_ORDER[a.severity] !== void 0 ? SEVERITY_ORDER[a.severity] : 3;
        const sevB = SEVERITY_ORDER[b.severity] !== void 0 ? SEVERITY_ORDER[b.severity] : 3;
        const sevDiff = sevA - sevB;
        if (sevDiff !== 0) return sevDiff;
        return a.id.localeCompare(b.id);
      });
      const orphanedTasks = bugFixTasks.filter((t) => !bugIds.has(t.bugTag)).map((t) => ({ id: t.id, bugTag: t.bugTag, description: t.description, checked: t.checked }));
      const openBugs = bugs.filter((b) => b.status !== "fixed");
      const fixedBugs = bugs.filter((b) => b.status === "fixed");
      const bySeverity = { critical: 0, high: 0, medium: 0, low: 0 };
      for (const bug of openBugs) {
        if (bySeverity.hasOwnProperty(bug.severity)) {
          bySeverity[bug.severity]++;
        }
      }
      let highestOpenSeverity = null;
      for (const sev of ["critical", "high", "medium", "low"]) {
        if (bySeverity[sev] > 0) {
          highestOpenSeverity = sev;
          break;
        }
      }
      let repoUrl = null;
      try {
        const { execSync } = require("child_process");
        repoUrl = execSync("git remote get-url origin", {
          cwd: projectPath,
          encoding: "utf-8",
          stdio: ["pipe", "pipe", "pipe"]
        }).trim();
        repoUrl = repoUrl.replace(/\.git$/, "");
        const sshMatch = repoUrl.match(/^git@([^:]+):(.+)$/);
        if (sshMatch) {
          repoUrl = `https://${sshMatch[1]}/${sshMatch[2]}`;
        }
      } catch {
      }
      return {
        exists: true,
        bugs,
        orphanedTasks,
        summary: {
          total: bugs.length,
          open: openBugs.length,
          fixed: fixedBugs.length,
          highestOpenSeverity,
          bySeverity
        },
        repoUrl
      };
    }
    module2.exports = { computeBugsState: computeBugsState2, resolveGitHubIssueUrl };
  }
});

// src/generate-dashboard.js
var path = require("path");
var fs = require("fs");
var { parseSpecStories, parseTasks, parseConstitutionPrinciples, parsePremise } = require_parser();
var { computeBoardState } = require_board();
var { computeAssertionHash, checkIntegrity } = require_integrity();
var { computePipelineState } = require_pipeline();
var { computeStoryMapState } = require_storymap();
var { computePlanViewState } = require_planview();
var { computeChecklistViewState } = require_checklist();
var { computeTestifyState } = require_testify();
var { computeAnalyzeState } = require_analyze();
var { computeBugsState } = require_bugs();
function listFeatures(projectPath) {
  const specsDir = path.join(projectPath, "specs");
  if (!fs.existsSync(specsDir)) return [];
  const entries = fs.readdirSync(specsDir, { withFileTypes: true });
  const features = [];
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const featureDir = path.join(specsDir, entry.name);
    const specPath = path.join(featureDir, "spec.md");
    if (!fs.existsSync(specPath)) continue;
    const tasksPath = path.join(featureDir, "tasks.md");
    const specContent = fs.readFileSync(specPath, "utf-8");
    const tasksContent = fs.existsSync(tasksPath) ? fs.readFileSync(tasksPath, "utf-8") : "";
    const stories = parseSpecStories(specContent);
    const tasks = parseTasks(tasksContent);
    const checkedCount = tasks.filter((t) => t.checked).length;
    const totalCount = tasks.length;
    const namePart = entry.name.replace(/^\d+-/, "");
    const name = namePart.split("-").map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
    features.push({
      id: entry.name,
      name,
      stories: stories.length,
      progress: `${checkedCount}/${totalCount}`
    });
  }
  return features.reverse();
}
function getBoardState(projectPath, featureId) {
  const featureDir = path.join(projectPath, "specs", featureId);
  const specPath = path.join(featureDir, "spec.md");
  const tasksPath = path.join(featureDir, "tasks.md");
  const testSpecsPath = path.join(featureDir, "tests", "test-specs.md");
  const contextPath = path.join(featureDir, "context.json");
  const specContent = fs.existsSync(specPath) ? fs.readFileSync(specPath, "utf-8") : "";
  const tasksContent = fs.existsSync(tasksPath) ? fs.readFileSync(tasksPath, "utf-8") : "";
  const stories = parseSpecStories(specContent);
  const tasks = parseTasks(tasksContent);
  const board = computeBoardState(stories, tasks);
  let integrity = { status: "missing", currentHash: null, storedHash: null };
  if (fs.existsSync(testSpecsPath)) {
    const testSpecsContent = fs.readFileSync(testSpecsPath, "utf-8");
    const currentHash = computeAssertionHash(testSpecsContent);
    let storedHash = null;
    if (fs.existsSync(contextPath)) {
      try {
        const context = JSON.parse(fs.readFileSync(contextPath, "utf-8"));
        storedHash = context?.testify?.assertion_hash || null;
      } catch {
      }
    }
    integrity = checkIntegrity(currentHash, storedHash);
  }
  return { ...board, integrity };
}
async function assembleDashboardData(projectPath) {
  const resolvedPath = path.resolve(projectPath);
  const features = listFeatures(resolvedPath);
  const constitution = parseConstitutionPrinciples(resolvedPath);
  const premise = parsePremise(resolvedPath);
  const featureData = {};
  for (const feature of features) {
    const fid = feature.id;
    try {
      featureData[fid] = {
        board: getBoardState(resolvedPath, fid),
        pipeline: computePipelineState(resolvedPath, fid),
        storyMap: computeStoryMapState(resolvedPath, fid),
        planView: await computePlanViewState(resolvedPath, fid),
        checklist: computeChecklistViewState(resolvedPath, fid),
        testify: computeTestifyState(resolvedPath, fid),
        analyze: computeAnalyzeState(resolvedPath, fid),
        bugs: computeBugsState(resolvedPath, fid)
      };
    } catch (err) {
      process.stderr.write(`Error: Parser failed on specs/${fid}/spec.md: ${err.message}. Check artifact syntax.
`);
      process.exit(5);
    }
  }
  return {
    meta: {
      projectPath: resolvedPath,
      generatedAt: (/* @__PURE__ */ new Date()).toISOString()
    },
    features,
    constitution,
    premise,
    featureData
  };
}
function buildHtml(templateHtml, dashboardData) {
  let html = templateHtml;
  const headInject = `  <meta http-equiv="refresh" content="2">
  <script>window.DASHBOARD_DATA = ${JSON.stringify(dashboardData)};</script>
`;
  html = html.replace("</head>", headInject + "</head>");
  html = html.replace("</body>", `<script>setInterval(() => location.reload(), 2000);</script>
</body>`);
  return html;
}
function writeAtomic(outputPath, content) {
  const dir = path.dirname(outputPath);
  fs.mkdirSync(dir, { recursive: true });
  const tmpPath = outputPath + ".tmp";
  fs.writeFileSync(tmpPath, content, "utf-8");
  fs.renameSync(tmpPath, outputPath);
}
var _cachedTemplate = null;
function loadTemplate() {
  if (_cachedTemplate) return _cachedTemplate;
  // Try template.js first (embedded HTML for published tiles where .html files are stripped)
  const templateJsCandidates = [
    path.join(__dirname, "template.js"),
    path.join(__dirname, "..", "dashboard", "template.js")
  ];
  for (const p of templateJsCandidates) {
    if (fs.existsSync(p)) {
      _cachedTemplate = require(p);
      return _cachedTemplate;
    }
  }
  // Fall back to public/index.html (dev layout)
  const htmlCandidates = [
    path.join(__dirname, "public", "index.html"),
    path.join(__dirname, "src", "public", "index.html")
  ];
  for (const p of htmlCandidates) {
    if (fs.existsSync(p)) {
      _cachedTemplate = fs.readFileSync(p, "utf-8");
      return _cachedTemplate;
    }
  }
  throw new Error("Dashboard template not found");
}
async function generate(projectPath) {
  const resolvedPath = path.resolve(projectPath);
  const templateHtml = loadTemplate();
  const dashboardData = await assembleDashboardData(resolvedPath);
  const jsonStr = JSON.stringify(dashboardData);
  for (const feature of dashboardData.features) {
    const featureJson = JSON.stringify(dashboardData.featureData[feature.id] || {});
    if (featureJson.length > 500 * 1024) {
      const sizeMB = (featureJson.length / (1024 * 1024)).toFixed(1);
      process.stderr.write(`Warning: Feature ${feature.id}: large artifacts detected (${sizeMB} MB). Dashboard may load slowly.
`);
    }
  }
  const html = buildHtml(templateHtml, dashboardData);
  const outputPath = path.join(resolvedPath, ".specify", "dashboard.html");
  writeAtomic(outputPath, html);
  const now = (/* @__PURE__ */ new Date()).toISOString().slice(0, 19).replace("T", " ");
  process.stdout.write(`[${now}] Generated dashboard.html (${(html.length / 1024).toFixed(0)} KB)
`);
}
async function main() {
  const args = process.argv.slice(2);
  if (args.length === 0) {
    process.stderr.write("Error: Project path is required. Usage: generate-dashboard.js <projectPath>\n");
    process.exit(1);
  }
  const projectPath = path.resolve(args[0]);
  if (!fs.existsSync(projectPath) || !fs.statSync(projectPath).isDirectory()) {
    process.stderr.write(`Error: Project directory not found: ${projectPath}. Verify the path is correct.
`);
    process.exit(1);
  }
  const constitutionPath = path.join(projectPath, "CONSTITUTION.md");
  if (!fs.existsSync(constitutionPath)) {
    process.stderr.write("Error: CONSTITUTION.md not found in project root. Create one using /iikit-00-constitution.\n");
    process.exit(3);
  }
  const specifyDir = path.join(projectPath, ".specify");
  try {
    fs.mkdirSync(specifyDir, { recursive: true });
    const testFile = path.join(specifyDir, ".write-test-" + process.pid);
    fs.writeFileSync(testFile, "");
    fs.unlinkSync(testFile);
  } catch (err) {
    process.stderr.write(`Error: Permission denied writing to .specify/dashboard.html. Check directory permissions.
`);
    process.exit(4);
  }
  try {
    await generate(projectPath);
  } catch (err) {
    process.stderr.write(`Error: ${err.message}
`);
    process.exit(5);
  }
}
if (require.main === module) {
  main();
}
module.exports = { generate, assembleDashboardData, buildHtml, listFeatures, getBoardState };
