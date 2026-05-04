# eShop Release Evidence Package Checklist

## 1. Change Authorization

- [ ] PR link(s) merged to `main` since last release tag
- [ ] Each PR has at least one human approval recorded in GitHub
- [ ] CODEOWNERS review satisfied (once branch protection is enabled)
- [ ] Release tag created by authorized team member (`git tag -s` with GPG signature)
- [ ] Any out-of-band hotfixes documented with justification

## 2. Code Review Records

### Human Review
- [ ] All PRs show "Approved" status from at least one human reviewer
- [ ] Non-trivial architectural changes have 2+ approvals
- [ ] Review comments resolved (no unresolved threads at merge time)

### AI-Assisted Review
- [ ] PRs containing AI-generated code are tagged (e.g., label: `ai-assisted`)
- [ ] `Co-Authored-By: Claude` trailers present in relevant commits
- [ ] Human reviewer confirmed they reviewed AI-generated sections (comment or checkbox in PR template)
- [ ] `/review` or `/security-review` output saved as PR comment where used

## 3. Quality Gates

### Build
- [ ] Clean build log captured locally:
  ```bash
  dotnet build eShop.slnx > build-$(git describe --tags).log 2>&1
  ```
- [ ] No warnings promoted to errors (check `.editorconfig` enforcement)
- [ ] Solution builds against target .NET 10 SDK version (record `dotnet --version`)

### Tests
- [ ] Unit test results exported:
  ```bash
  dotnet test --logger "trx;LogFileName=unit-tests.trx"
  ```
- [ ] Functional test results exported (Docker running):
  ```bash
  dotnet test tests/Catalog.FunctionalTests --logger "trx"
  dotnet test tests/Ordering.FunctionalTests --logger "trx"
  ```
- [ ] All tests passing (zero failures in `.trx` files)
- [ ] Test coverage report generated (if using `coverlet`):
  ```bash
  dotnet test --collect:"XPlat Code Coverage"
  ```

## 4. Security Scans (Local)

- [ ] Dependency vulnerability scan:
  ```bash
  dotnet list package --vulnerable --include-transitive > vuln-report.txt
  ```
- [ ] NuGet audit (built into `dotnet restore` with .NET 8+):
  ```bash
  dotnet restore --force > restore-audit.log 2>&1
  ```
- [ ] Secret scan (no credentials in committed code):
  ```bash
  git log --all --diff-filter=A -- "*.json" "*.config" "*.env" | head -50
  gitleaks detect --source . --report-path gitleaks-report.json
  ```
- [ ] Container base image versions recorded (from `eShop.AppHost` or Dockerfiles)
- [ ] OWASP/static analysis if available:
  ```bash
  dotnet tool run security-scan eShop.slnx  # or roslyn analyzers output
  ```
- [ ] No hardcoded connection strings (per project security rules)

## 5. Deployment Records

- [ ] Git tag + SHA for deployed commit:
  ```bash
  git log --oneline -1 HEAD
  git describe --tags --always
  ```
- [ ] Environment target documented (staging/production)
- [ ] Infrastructure versions recorded:
  - PostgreSQL version
  - Redis version
  - RabbitMQ version
  - .NET runtime version
  - Aspire version (from `Directory.Packages.props`)
- [ ] Deployment method and executor (who ran `dotnet publish` / pushed to registry)
- [ ] Rollback plan documented (previous known-good tag)
- [ ] Post-deployment smoke test results (health endpoints `/health`, `/alive`)

## 6. AI Attribution Trail

- [ ] List of commits with `Co-Authored-By: Claude` in this release:
  ```bash
  git log <prev-tag>..HEAD --grep="Co-Authored-By: Claude" --oneline > ai-commits.txt
  ```
- [ ] Percentage of changes that were AI-assisted (lines or commits)
- [ ] Any AI-generated code that touches security-sensitive areas flagged for extra human review:
  - Authentication/authorization changes
  - Database migrations
  - Event bus message contracts
  - Payment or PII-handling code
- [ ] Claude Code version used during development (record from `claude --version`)

---

## Release Package Assembly

```bash
# Run from repo root at the release commit
mkdir -p release-evidence/$(git describe --tags)
cd release-evidence/$(git describe --tags)

# Capture everything
dotnet --version > environment.txt
git log <prev-tag>..HEAD --oneline > changelog.txt
git log <prev-tag>..HEAD --grep="Co-Authored-By: Claude" --oneline > ai-commits.txt
dotnet build eShop.slnx > build.log 2>&1
dotnet test --logger "trx;LogFileName=tests.trx" > test-output.log 2>&1
dotnet list package --vulnerable --include-transitive > vulnerabilities.txt
```

Store the `release-evidence/` directory alongside the release tag or attach to the GitHub Release.

---

**Key principle:** Since Claude Code runs locally and not in CI, the burden of evidence collection falls on the developer performing the release. Consider scripting the assembly step above as a `release-evidence.sh` in the repo to make it repeatable.
