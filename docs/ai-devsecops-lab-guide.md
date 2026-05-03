# AI-Assisted DevSecOps Lab Guide

> Hands-on labs using the eShop .NET Aspire reference application. Practice every concept from the AI-Assisted DevSecOps maturity roadmap, progressing from the simplest (L0/L1) to the most complex (L3+). All exercises run locally with Claude Code CLI — no CI/CD pipeline integration required.

**Prerequisites:**
- eShop repo cloned to `C:\Projects\eShop`
- Docker Desktop installed and running
- .NET 10 SDK installed
- Claude Code CLI installed and authenticated
- Solution builds: `dotnet build eShop.Web.slnf`

**How to use this guide:**
- Labs are sequential — each builds on the previous
- Estimated time is per lab, not cumulative
- "Verify" steps confirm you completed the exercise correctly
- Discussion prompts are for team walkthroughs

---

## Phase 1: Foundation (L0 Baseline)

### Lab 1.1: Understand the Codebase Without AI (15 min)

**Objective:** Establish a manual baseline. Experience what it's like to understand unfamiliar code without AI assistance.

**Task:** Answer these questions by reading the code manually:

1. How many microservices does eShop have? List them.
2. What database does Catalog.API use? Where is the connection string configured?
3. How does Basket.API store data? (Hint: not a relational database)
4. What messaging system connects the services?
5. Where are the health check endpoints defined?

**Steps:**
1. Open `src/eShop.AppHost/Program.cs` — this is the Aspire orchestrator that wires everything together
2. Read through each `AddProject<>` call and note the service names
3. Find the database references (`AddDatabase`)
4. Find the Redis and RabbitMQ references
5. Open `src/eShop.ServiceDefaults/Extensions.cs` and find the health check setup

**Verify:** You should be able to name: 7 services (Identity.API, Basket.API, Catalog.API, Ordering.API, OrderProcessor, PaymentProcessor, Webhooks.API), 4 databases (catalogdb, identitydb, orderingdb, webhooksdb), Redis for basket, RabbitMQ for events.

**Discussion:** How long did this take? What was hard to find? Remember this feeling — it's your baseline.

---

### Lab 1.2: Run the Existing Tests Manually (10 min)

**Objective:** Understand the existing test landscape before adding AI.

**Steps:**
```bash
# Run unit tests (no Docker needed)
dotnet test tests/Basket.UnitTests/Basket.UnitTests.csproj
dotnet test tests/Ordering.UnitTests/Ordering.UnitTests.csproj

# Run functional tests (Docker required — Aspire spins up PostgreSQL)
dotnet test tests/Catalog.FunctionalTests/Catalog.FunctionalTests.csproj
dotnet test tests/Ordering.FunctionalTests/Ordering.FunctionalTests.csproj
```

**Verify:** Note which tests pass, which fail (if any), and how long each suite takes.

**Record your baseline:**
| Suite | Tests | Pass | Fail | Duration |
|---|---|---|---|---|
| Basket.UnitTests | | | | |
| Ordering.UnitTests | | | | |
| Catalog.FunctionalTests | | | | |
| Ordering.FunctionalTests | | | | |

---

## Phase 2: CLAUDE.md and Rules (L1 — AI-Assisted Individual)

### Lab 2.1: Explore with Claude Code — Your First AI Conversation (10 min)

**Objective:** Use Claude Code as a pair programmer to understand code you didn't write.

**Steps:**
1. Open a terminal in `C:\Projects\eShop`
2. Start Claude Code: `claude`
3. Ask these questions:

```
Explain how the Ordering service uses DDD patterns. 
What are the aggregate roots, entities, and value objects?
```

```
How does the EventBus work? Trace the flow of an integration event 
from when an order is placed to when the payment processor handles it.
```

```
What is the purpose of eShop.ServiceDefaults? 
What does every service get automatically by calling AddServiceDefaults()?
```

**Verify:** Compare Claude's answers to what you found manually in Lab 1.1. Was the AI faster? More accurate? Did it miss anything?

**Discussion:** This is Level 1 usage — ad-hoc prompts, no structure. The quality of answers depends entirely on how you phrase the question.

---

### Lab 2.2: Review the Existing CLAUDE.md (10 min)

**Objective:** Understand how CLAUDE.md shapes AI behavior.

**Steps:**
1. Read `C:\Projects\eShop\CLAUDE.md`
2. Notice what it covers: build commands, test commands, architecture overview, API patterns, code style
3. In Claude Code, ask:

```
Based on the CLAUDE.md in this repo, what coding conventions should you follow 
when generating C# code for this project?
```

**Verify:** Claude should mention: 4-space indentation, `var` everywhere, no `this.`, Allman braces, PascalCase constants, MSTest framework, NSubstitute for mocking.

**Discussion:** CLAUDE.md is loaded into every session automatically. It's the single most important artifact for AI quality. If it's wrong, every AI interaction is wrong.

---

### Lab 2.3: Write Your First Rule File (20 min)

**Objective:** Create a `.claude/rules/` directory and write a security rule specific to eShop.

**Steps:**
1. Create the directory structure:
```bash
mkdir -p .claude/rules
```

2. Ask Claude Code to help you draft a security rule:
```
Help me write a .claude/rules/security.md file for this eShop project. 
It should cover:
- Never hardcode connection strings (Aspire injects them)
- Never log PII (customer names, emails, addresses, card numbers)
- All API endpoints require authentication except health checks
- Never use raw SQL — use EF Core or Dapper with parameterized queries
- Never expose internal service URLs to external clients

Base it on what you see in the actual codebase.
```

3. Review what Claude generates. Does it match the actual codebase patterns?
4. Save the file to `.claude/rules/security.md`

**Verify:** Start a new Claude Code session and ask: "What security rules apply to this project?" It should reference your new file.

---

### Lab 2.4: Write a Testing Rule (15 min)

**Objective:** Create a testing rule that reflects eShop's actual test patterns.

**Steps:**
1. Examine existing tests:
   - `tests/Basket.UnitTests/BasketServiceTests.cs` — MSTest + NSubstitute
   - `tests/Ordering.UnitTests/` — domain and application layer tests
   - `tests/Catalog.FunctionalTests/` — WebApplicationFactory + Aspire
2. Ask Claude Code:
```
Help me write a .claude/rules/testing.md for this project. Look at the existing 
test projects and document the patterns I should follow:
- Test framework and naming conventions
- Mocking approach
- How functional tests use Aspire test hosting
- What should be unit tested vs. functional tested
```

3. Save to `.claude/rules/testing.md`

**Verify:** The rule should reference MSTest (`[TestClass]`, `[TestMethod]`), NSubstitute (`Substitute.For<>`), and the Aspire `DistributedApplicationTestingBuilder` pattern.

---

## Phase 3: Skills — Standardized Workflows (L2)

### Lab 3.1: Use Claude Code to Explain Code (Code Review Assist) (15 min)

**Objective:** Practice using Claude Code as a reviewer — understand code before changing it.

**Steps:**
1. In Claude Code, ask it to review a specific file for quality and patterns:
```
Review src/Catalog.API/Apis/CatalogApi.cs for:
- API design quality (REST conventions, status codes, versioning)
- Missing error handling
- Missing input validation
- Any security concerns

Be specific — reference line numbers and suggest concrete improvements.
```

2. Do the same for the Ordering domain:
```
Review src/Ordering.Domain/AggregatesModel/OrderAggregate/Order.cs for:
- DDD pattern correctness
- Encapsulation (are invariants protected?)
- Any business rules that should have tests but might not
```

**Verify:** Note down the findings. Are they accurate? Would you have caught them manually?

---

### Lab 3.2: Generate a Unit Test with Claude Code (20 min)

**Objective:** Use Claude Code to write a unit test following the existing patterns.

**Steps:**
1. Look at an untested or under-tested area. The Ordering domain has complex business logic:
```
Look at src/Ordering.Domain/AggregatesModel/OrderAggregate/Order.cs.
What methods or behaviors don't have corresponding tests in 
tests/Ordering.UnitTests/Domain/?
```

2. Ask Claude to generate a test:
```
Write a unit test for the Order.AddOrderItem method in 
src/Ordering.Domain/AggregatesModel/OrderAggregate/Order.cs.

Follow the exact patterns from the existing tests in tests/Ordering.UnitTests/Domain/.
Use MSTest attributes and the naming convention from the existing tests.
Test both the happy path and edge cases (duplicate items, invalid quantities).
```

3. Review the generated test. Check:
   - Does it follow MSTest conventions (`[TestClass]`, `[TestMethod]`)?
   - Does it use the right assertion methods?
   - Are the assertions meaningful (not just `Assert.IsNotNull`)?
   - Does it compile and pass?

```bash
dotnet test tests/Ordering.UnitTests/Ordering.UnitTests.csproj
```

**Verify:** Tests compile, run, and pass. Assertions verify actual behavior, not just execution.

---

### Lab 3.3: Implement a Small Feature with AI Assistance (30 min)

**Objective:** Experience the full cycle: understand requirements, implement, test, verify.

**Scenario:** Add a `GET /api/catalog/items/count` endpoint to Catalog.API that returns the total number of items in the catalog.

**Steps:**
1. Ask Claude to plan the implementation:
```
I want to add a GET /api/catalog/items/count endpoint to Catalog.API 
that returns the total count of catalog items.

Plan the implementation:
- Which file(s) need to change?
- What's the return type?
- How should it follow the existing endpoint patterns in CatalogApi.cs?
- Should it be versioned?
```

2. Review the plan. Does it make sense?
3. Ask Claude to implement it:
```
Implement the /api/catalog/items/count endpoint following the plan.
Follow the existing patterns in CatalogApi.cs exactly.
```

4. Build and verify:
```bash
dotnet build src/Catalog.API/Catalog.API.csproj
```

5. Ask Claude to write a test:
```
Write a functional test for the new /api/catalog/items/count endpoint.
Follow the patterns in tests/Catalog.FunctionalTests/CatalogApiTests.cs.
```

6. Run the test:
```bash
dotnet test tests/Catalog.FunctionalTests/Catalog.FunctionalTests.csproj
```

**Verify:** Endpoint works, test passes, code follows existing patterns. Check the diff — is it what you'd write manually?

**Discussion:** This is what `/implement-feature` skill automates: plan, implement, test, verify. At L2, you'd invoke a skill instead of writing these prompts manually.

---

### Lab 3.4: AI-Assisted Debugging (15 min)

**Objective:** Use Claude Code to diagnose and fix an issue.

**Steps:**
1. Introduce a deliberate bug. In `src/Ordering.Domain/AggregatesModel/OrderAggregate/Order.cs`, temporarily change the `AddOrderItem` method to not check for existing items with the same product ID (or make another small logic error).

2. Run the tests:
```bash
dotnet test tests/Ordering.UnitTests/Ordering.UnitTests.csproj
```

3. Give Claude the failing test output:
```
These tests are failing: [paste the output]

Diagnose the root cause and suggest a fix. 
Don't just fix the symptom — explain what went wrong and why.
```

4. Evaluate: Did Claude find the actual bug? Did it explain the root cause?
5. Revert your change.

---

## Phase 4: Multi-Agent Review Concepts (L3 — Locally Simulated)

> Since you can't run Claude in the CI pipeline, these labs simulate what the AI review agents would do by running them locally.

### Lab 4.1: Architecture Review (20 min)

**Objective:** Simulate the `architecture-reviewer` agent by asking Claude to review architectural decisions.

**Steps:**
1. In Claude Code, run an architecture review:
```
Act as an architecture reviewer. Review the eShop solution for:

1. Dependency direction: Do any services depend on each other's internals?
   Check the .csproj references.
2. Module isolation: Does any service directly reference another service's 
   domain model? (They should communicate via events only)
3. Shared kernel: Is eShop.ServiceDefaults properly limited to 
   cross-cutting concerns?
4. Database isolation: Does each service own its own database? 
   Check the AppHost configuration.

Report findings with severity (Critical/High/Medium/Low).
```

2. Review the findings. Are they accurate?

**Verify:** The review should confirm: services communicate via RabbitMQ events (good), each service has its own database (good), ServiceDefaults is shared kernel (good). It might flag the `IntegrationEventLogEF` shared library as a coupling point.

---

### Lab 4.2: Security Review (20 min)

**Objective:** Simulate the `security-reviewer` agent.

**Steps:**
1. Ask Claude to perform a security review:
```
Act as a security reviewer following OWASP Top 10. Review these files:

- src/Ordering.API/Apis/OrdersApi.cs (input validation, auth, error handling)
- src/Basket.API/Grpc/BasketService.cs (auth, data validation)
- src/Identity.API/ (auth configuration, token handling)

For each finding:
- Severity: Critical / High / Medium / Low
- OWASP category
- Specific file and line
- Recommended fix with code example
```

2. Evaluate each finding:
   - Is it a real issue or a false positive?
   - Would you have caught it in a manual review?
   - How would you triage it? (fix now / fix later / won't fix)

**Discussion:** At L3, this runs automatically on every PR. At L1-L2, you run it manually when you want a second opinion.

---

### Lab 4.3: SRE/Observability Review (15 min)

**Objective:** Simulate the `sre-reviewer` agent.

**Steps:**
1. Ask Claude to review observability:
```
Act as an SRE reviewer. Review the eShop solution for operational readiness:

1. Health checks: Does every service have /health and /alive endpoints?
2. Logging: Is structured logging used consistently? Any console.writeline?
3. Metrics: Is OpenTelemetry configured for all services?
4. Resilience: Are HTTP clients configured with retry/circuit breaker?
5. Resource limits: Are there any unbounded queries or missing pagination?

Check src/eShop.ServiceDefaults/Extensions.cs and at least 2 service projects.
```

**Verify:** ServiceDefaults already configures OpenTelemetry and health checks. Claude should confirm these as strengths and flag any gaps.

---

### Lab 4.4: Combined Multi-Agent Review on a Change (30 min)

**Objective:** Experience what a full L3 pipeline review feels like by running multiple review perspectives on a single change.

**Steps:**
1. Make a small change — add a new endpoint to one of the APIs (or use the endpoint from Lab 3.3).
2. Run three separate review prompts in sequence:

```
Review my recent changes as an ARCHITECTURE reviewer. 
Focus on dependency direction, API design, and module boundaries.
```

```
Review my recent changes as a SECURITY reviewer.
Focus on input validation, authentication, error exposure, and data handling.
```

```
Review my recent changes as an SRE reviewer.
Focus on health checks, logging, error handling, and performance.
```

3. Compile all findings into a single list. Categorize by severity.
4. For each finding, decide: fix / acknowledge / dismiss (false positive).

**Discussion:** At L3, these three reviews run in parallel on every PR in < 5 minutes. You'd see them as comments on your GitHub PR. Your job shifts from "find issues" to "triage findings."

---

## Phase 5: Advanced Patterns (L3+)

### Lab 5.1: Domain Event Tracing (20 min)

**Objective:** Use Claude Code to trace a complex cross-service flow.

**Steps:**
1. Ask Claude to trace the complete order lifecycle:
```
Trace the full lifecycle of an order in the eShop system:
1. Start from when a user submits an order (WebApp)
2. Through the Ordering.API (command handling)
3. Through the domain events within Order aggregate
4. Through integration events to OrderProcessor
5. Through the PaymentProcessor
6. Back to OrderProcessor for confirmation

For each step, name the exact file, class, and method.
Show the integration event names and which service publishes/subscribes.
```

2. Verify the trace by reading the actual code. Is it accurate?

**Verify:** The flow should be: WebApp > Ordering.API (CreateOrderCommand via MediatR) > Order domain events > IntegrationEventLogEF outbox > RabbitMQ > OrderProcessor > PaymentProcessor > RabbitMQ > OrderProcessor (status update).

---

### Lab 5.2: Threat Modeling (25 min)

**Objective:** Practice STRIDE threat modeling with AI assistance.

**Steps:**
1. Ask Claude to perform a STRIDE analysis:
```
Perform a STRIDE threat model for the eShop checkout flow:
- User adds items to basket (Basket.API, Redis)
- User submits order (Ordering.API, PostgreSQL)
- Payment is processed (PaymentProcessor via RabbitMQ)
- Order status is updated (OrderProcessor)

For each STRIDE category (Spoofing, Tampering, Repudiation, 
Information Disclosure, Denial of Service, Elevation of Privilege):
- Identify at least one threat
- Assess likelihood and impact
- Recommend a mitigation
- Note which mitigations already exist in the codebase
```

**Discussion:** At L2+, you'd invoke `/threat-model` skill for this. The skill ensures consistent output format and covers all STRIDE categories systematically.

---

### Lab 5.3: Database Migration Safety Review (20 min)

**Objective:** Practice evaluating migration safety — a key skill for any DevSecOps practice.

**Steps:**
1. Examine the existing migrations:
```
Find all EF Core migrations in the eShop solution.
For each migration, tell me:
- Which service owns it
- What schema changes it makes
- Whether it's backwards-compatible with the previous version
- Whether it would lock tables on a large dataset
```

2. Ask Claude to generate a safe migration:
```
I want to add a "Notes" column (nullable varchar(500)) to the Orders table 
in the Ordering service. 

Generate the migration following safe migration practices:
- Must be backwards-compatible with currently running code
- Must not lock tables
- Include a rollback strategy

Show me the exact commands and generated files.
```

**Verify:** The migration should add a nullable column (safe, no lock). Claude should NOT generate a NOT NULL column without a default.

---

### Lab 5.4: Integration Event Design (25 min)

**Objective:** Design a new cross-service integration event following existing patterns.

**Scenario:** Add a "order shipped" notification that triggers an email.

**Steps:**
1. Study the existing pattern:
```
Show me the complete integration event pattern in eShop:
- How events are defined (which base class, naming convention)
- How events are published (outbox pattern via IntegrationEventLogEF)
- How events are subscribed to (registration pattern)
- Show a concrete example end-to-end
```

2. Ask Claude to implement:
```
Design and implement an OrderShippedIntegrationEvent that:
1. Is published by the OrderProcessor when an order status changes to Shipped
2. Could be consumed by a (hypothetical) Notification service

Follow the exact patterns from the existing integration events.
Show me all files that need to change and the new files needed.
Don't implement the Notification service — just the event and publisher.
```

3. Review: Does it follow the outbox pattern? Is the event name consistent with existing events?

---

## Phase 6: Governance and Process (L3 Operational)

### Lab 6.1: Co-Authored-By Attribution (5 min)

**Objective:** Practice the attribution requirement from the AI coding standards.

**Steps:**
1. Make a small change with Claude Code's help (e.g., add a comment or a small refactor)
2. Commit with the attribution trailer:
```bash
git add -A
git commit -m "feat: add catalog item count endpoint

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

3. Verify: `git log --grep="Co-Authored-By: Claude Code"` should find your commit.

**Discussion:** This is non-negotiable at every maturity level. It creates the audit trail for compliance.

---

### Lab 6.2: Measure AI Rework Rate (15 min)

**Objective:** Practice measuring the key quality metric for AI-generated code.

**Steps:**
1. Pick one of the features or tests Claude generated in earlier labs
2. Review it critically. Count:
   - Lines Claude generated
   - Lines you changed during review (added, modified, or deleted)
3. Calculate: `rework_rate = lines_changed / lines_generated * 100`

| Lab | Lines Generated | Lines Reworked | Rework Rate |
|---|---|---|---|
| Lab 3.2 (unit test) | | | |
| Lab 3.3 (feature) | | | |
| Lab 5.4 (event) | | | |

**Discussion:** The target is < 15% at L2+. If your rate is higher, what would you add to CLAUDE.md or rules to improve it?

---

### Lab 6.3: Write a CODEOWNERS File (10 min)

**Objective:** Create review routing that matches the eShop domain boundaries.

**Steps:**
1. Ask Claude:
```
Generate a CODEOWNERS file for the eShop repo that routes reviews based on 
service ownership:

- Ordering service (API, Domain, Infrastructure) -> @ordering-team
- Catalog service -> @catalog-team
- Basket service -> @basket-team
- Identity service -> @identity-team @security-team
- Infrastructure (AppHost, ServiceDefaults) -> @platform-team
- Event bus -> @platform-team
- Tests -> ownership follows the service they test
- Root config files -> @engineering-leads
```

2. Save to `CODEOWNERS` in the repo root.

**Verify:** The file should map paths like `src/Ordering.*` to `@ordering-team`, etc.

---

### Lab 6.4: Create a Release Evidence Package (15 min)

**Objective:** Understand what audit evidence looks like for an AI-assisted release.

**Steps:**
1. Ask Claude to generate a release evidence checklist for the eShop project:
```
Generate a release evidence package checklist for eShop, adapted for a team 
that uses Claude Code locally but NOT in CI/CD.

What evidence should we collect for each release? Consider:
- Change authorization (who approved what)
- Code review records (human + AI review)
- Quality gates (test results, build logs)
- Security scans (what we can run locally)
- Deployment records
- AI attribution trail

Format as a markdown checklist.
```

**Discussion:** Even without CI/CD pipeline integration, you can still collect most evidence manually. The pipeline just automates the collection.

---

## Phase 7: Putting It All Together

### Lab 7.1: Full Feature Lifecycle (45-60 min)

**Objective:** Experience the complete L2 workflow end-to-end on a real feature.

**Scenario:** Add a "frequently bought together" feature to the Catalog API.

**Steps:**
1. **Requirements** — Ask Claude to structure the requirement:
```
I want to add a "frequently bought together" endpoint to the Catalog API.
When a user views a product, we want to suggest other products that are 
commonly purchased alongside it.

Structure this as a requirements document:
- Acceptance criteria
- Edge cases
- API contract (request/response)
- Data requirements
- What's in scope vs. out of scope for v1
```

2. **Design** — Ask Claude to create a technical design:
```
Design the technical approach for the "frequently bought together" feature.
Consider:
- Where does the co-purchase data come from? (For v1, use a simple 
  lookup table rather than ML)
- Database schema changes needed
- API endpoint design following existing Catalog.API patterns
- How it fits into the existing architecture
```

3. **Implement** — Work with Claude to implement the feature step by step
4. **Test** — Generate and run unit and functional tests
5. **Review** — Run architecture, security, and SRE reviews (Labs 4.1-4.3 approach)
6. **Commit** — With proper attribution

**Verify:**
- Code compiles: `dotnet build src/Catalog.API/Catalog.API.csproj`
- Tests pass: `dotnet test`
- No security findings above Medium severity
- Rework rate < 25%

---

### Lab 7.2: Retrospective (15 min)

**Objective:** Reflect on what you learned and identify improvement areas.

**Questions for self-reflection or team discussion:**

1. **Speed:** Which labs were faster with AI? Which were the same speed or slower?
2. **Quality:** Where did AI-generated code surprise you (good or bad)?
3. **Trust:** What do you trust AI to do well? What do you always want to double-check?
4. **Rules:** What would you add to CLAUDE.md or `.claude/rules/` based on your experience?
5. **Skills:** Which recurring tasks would benefit from a standardized skill?
6. **Concern:** What's your biggest concern about adopting this workflow?
7. **Excitement:** What are you most excited about?

**Action items to capture:**
- Rules to add based on real mistakes you observed
- CLAUDE.md updates for patterns Claude didn't know about
- Tasks where AI helped the most (candidates for skills)
- Tasks where AI didn't help (keep manual)

---

## Lab Progress Tracker

| Lab | Status | Time Taken | Notes |
|---|---|---|---|
| 1.1 Understand codebase manually | | | |
| 1.2 Run existing tests | | | |
| 2.1 First AI conversation | | | |
| 2.2 Review CLAUDE.md | | | |
| 2.3 Write security rule | | | |
| 2.4 Write testing rule | | | |
| 3.1 AI code review | | | |
| 3.2 Generate unit test | | | |
| 3.3 Implement small feature | | | |
| 3.4 AI debugging | | | |
| 4.1 Architecture review | | | |
| 4.2 Security review | | | |
| 4.3 SRE review | | | |
| 4.4 Combined multi-agent review | | | |
| 5.1 Domain event tracing | | | |
| 5.2 Threat modeling | | | |
| 5.3 Migration safety review | | | |
| 5.4 Integration event design | | | |
| 6.1 Attribution practice | | | |
| 6.2 Measure rework rate | | | |
| 6.3 CODEOWNERS | | | |
| 6.4 Release evidence package | | | |
| 7.1 Full feature lifecycle | | | |
| 7.2 Retrospective | | | |

---

## Mapping Labs to Maturity Levels

| Maturity Level | Labs | Concepts Practiced |
|---|---|---|
| **L0 Baseline** | 1.1, 1.2 | Manual code reading, manual testing — establish what "before AI" feels like |
| **L1 AI-Assisted Individual** | 2.1, 2.2, 2.3, 2.4 | CLAUDE.md, rules files, ad-hoc AI conversations, basic code understanding |
| **L2 Team-Standardized** | 3.1, 3.2, 3.3, 3.4 | AI-assisted code review, test generation, feature implementation, debugging |
| **L3 Pipeline-Enforced (local sim)** | 4.1, 4.2, 4.3, 4.4 | Multi-agent review simulation (architecture, security, SRE), finding triage |
| **L3+ Advanced Patterns** | 5.1, 5.2, 5.3, 5.4 | Cross-service tracing, STRIDE threat model, migration safety, event design |
| **L3 Governance** | 6.1, 6.2, 6.3, 6.4 | Attribution, rework metrics, CODEOWNERS, release evidence |
| **Full Workflow** | 7.1, 7.2 | End-to-end feature lifecycle, retrospective |

---

## Adapting for Your Own Codebase

After completing these labs with eShop, apply the same pattern to your production codebase:

1. **Start with CLAUDE.md** — Document your project's architecture, conventions, build commands, and test commands
2. **Add rules incrementally** — One rule file per domain concern (security, testing, API design). Add rules based on actual AI mistakes, not theory.
3. **Measure rework rate** — Track how much AI-generated code you change during review. If > 20%, update your rules.
4. **Run manual agent reviews** — Until you have CI integration, run architecture/security/SRE reviews manually on each PR.
5. **Attribution from day one** — Every AI-assisted commit gets the `Co-Authored-By` trailer.

The maturity roadmap (L0-L5) applies regardless of whether AI runs in CI. The difference is automation of enforcement — the concepts and practices are the same.
