# Ignore File Patterns Reference

Common patterns for various ignore files by technology stack.

## Detection & Creation Logic

- Check if git repo: `git rev-parse --git-dir 2>/dev/null` → create/verify `.gitignore`
- Check if Dockerfile exists or Docker in plan.md → create/verify `.dockerignore`
- Check if .eslintrc* exists → create/verify `.eslintignore`
- Check if eslint.config.* exists → ensure config's `ignores` entries cover required patterns
- Check if .prettierrc* exists → create/verify `.prettierignore`
- Check if .npmrc or package.json exists → create/verify `.npmignore` (if publishing)
- Check if terraform files (*.tf) exist → create/verify `.terraformignore`
- Check if helm charts present → create/verify `.helmignore`

## Common Patterns by Technology

### Node.js/JavaScript/TypeScript
```
node_modules/
dist/
build/
*.log
.env*
```

### Python
```
__pycache__/
*.pyc
.venv/
venv/
dist/
*.egg-info/
```

### Java
```
target/
*.class
*.jar
.gradle/
build/
```

### C#/.NET
```
bin/
obj/
*.user
*.suo
packages/
```

### Go
```
*.exe
*.test
vendor/
*.out
```

### Rust
```
target/
debug/
release/
*.rs.bk
```

### Universal (all projects)
```
.DS_Store
Thumbs.db
*.tmp
*.swp
.vscode/
.idea/
```
