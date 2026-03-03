# ClawResearch (CRL)
## Autonomous Research Layer for OpenClaw
### Product Requirements Document — Final

**Version:** 3.2 Final  
**Status:** Implementation-Ready. All architectural decisions resolved.  
**Classification:** Architect-Level  
**Base Platform:** OpenClaw  
**System Type:** Bounded Closed-Loop Research Optimizer  
**Expected reader outputs:** Phased implementation roadmap, architectural critique, risk and failure mode analysis

---

## Table of Contents

1. Foundational Doctrine
2. System Scope
3. Pre-Implementation Audit (Phase 0)
4. Objective & Success Criteria
5. System Architecture
6. Module Specifications
   - R1: Goal Decomposition Engine
   - R2: Multi-Agent Hypothesis Engine
   - R3: Structured Debate Protocol
   - R4: Experiment Execution Layer
   - R5: Structured Research Memory
   - R6: Meta-Evaluator
7. Data Contracts Between Modules
8. Complete Database Schema (Production DDL)
9. Cost Model
10. Ranking Formula
11. Risk & Failure Mode Analysis
12. Implementation Roadmap
13. Stretch Goals

---

## 1. Foundational Doctrine

These are non-negotiable invariants. When any design decision is ambiguous, resolve it by returning to these principles. They are not guidelines — they are architectural constraints.

### 1.1 Structure Over Intelligence

LLMs generate hypotheses. CRL enforces structure, memory, determinism, safety, and loop control. These responsibilities must never blur.

LLMs do not:
- Terminate loops
- Validate metrics
- Modify objectives
- Control budget
- Alter system configuration
- Decide when to stop iterating

### 1.2 Deterministic Control Plane

All decisions affecting termination, budget, loop continuation, and resource consumption must be deterministic, reproducible, and non-LLM. Reasoning is expensive and non-reproducible. Control is cheap and must be exact.

### 1.3 Immutable Objective

ObjectiveSpec is created once (R1), stored once, and never modified or reinterpreted. Objective drift is a system failure, not a feature. Every agent prompt includes the original ObjectiveSpec verbatim. No agent has write access to it.

### 1.4 Fail Loudly

Silent failures are forbidden. If any of the following occur, the system halts with an explicit error — it does not degrade gracefully:

- Metric unverified (`metric_verified == false`)
- Sandbox integrity compromised
- JSON output malformed on second attempt
- Objective ambiguous or underspecified
- Deduplication conflict unresolvable
- Registry mutation detected at runtime

Graceful degradation without human awareness is the most dangerous failure mode in a system claiming autonomy.

### 1.5 Structural Novelty, Not Parameter Novelty

A system that runs 10 cycles of parameter tweaks is not a research engine — it is a looped prompt system with audit logs. Every hypothesis must be evaluated for structural difference at three levels: parameter, strategy, and mechanism. Illusory autonomy is a failure mode, not a partial success.

---

## 2. System Scope

CRL converts OpenClaw from a task-executing agent into a bounded autonomous research optimizer. It does not replace or fork OpenClaw. It extends it via the existing skill and plugin interface.

> **Core thesis:** Autonomy bottlenecks in LLM-based systems are not intelligence bottlenecks. They are state management, metric validation, objective precision, long-horizon consistency, and exploration robustness problems. CRL is an engineering solution to those five problems specifically.

**CRL does not:**
- Enable recursive self-improvement
- Enable model modification
- Enable runtime skill registry modification
- Enable uncontrolled network access
- Enable financial transactions
- Enable self-referential objective optimization

---

## 3. Pre-Implementation Audit (Phase 0)

**This phase is mandatory. It is a hard gate. Do not write a single line of CRL code without completing it.**

Assumptions that turn out to be wrong here are 10× cheaper to resolve in Phase 0 than mid-implementation. Every item below has a downstream architectural dependency.

| Audit Item | Requirement | Risk if Skipped |
|---|---|---|
| Skill execution isolation | Skills cannot read or write each other's internal state | Cross-contamination between research loop and general agent state |
| Plugin registry immutability | Registry cannot be modified at runtime by a running skill | Self-modification vector via skill injection |
| LLM JSON output reliability | ≥98% structured JSON compliance on target prompt format | Entire hypothesis pipeline breaks on prose leakage |
| Network restriction | Skill execution cannot make calls outside allowlisted tool set | Sandbox escape via network during experiment execution |
| Tool execution latency baseline | Measured and recorded per skill call under representative load | Cycle time estimates are unreliable without this |
| Memory boundary | OpenClaw conversational memory is cleanly separable from CRL's Postgres DB | Hypothesis state bleeds into conversational context |

**Phase 0 also includes the Ranking Consistency Test** — the empirical measurement that determines whether exponential or linear normalization is used in the ranking formula. This test is fully specified in the companion document: *CRL Ranking Prompt Specification v1.1 Final*.

**Deliverable:** Technical feasibility document + known integration risks list + `ranking_consistency_report.json`.  
**Gate:** Do not begin Phase 1 without this document, all risks accepted or mitigated, and `ranking_consistency_report.json` produced.

---

## 4. Objective & Success Criteria

### Primary Goal

Enable OpenClaw to accept a high-level, underspecified objective and autonomously run a structured research loop — decomposing goals, generating hypotheses, executing experiments, measuring outcomes, and iterating — for 10–20 cycles without human intervention.

### MVP Success Criteria

| Criterion | Threshold |
|---|---|
| Autonomous cycles without human intervention | ≥ 10 |
| Competing hypotheses per cycle | ≥ 3 |
| Structural novelty gate | ≥ 1 mechanism-level hypothesis per iteration (hard gate) |
| Experiments executed per iteration | ≥ 1 sandboxed run per selected hypothesis |
| Metric extraction method | 100% programmatic — no LLM parsing fallback under any condition |
| Failed hypothesis re-exploration rate | 0% (enforced by dual-hash deduplication) |
| Convergence or termination decision | Automated, deterministic, no human trigger |
| Final output | Ranked solution set + full experiment history + convergence summary + novelty distribution report |

### Hard Architectural Boundaries

These are enforced at the system level, not by convention or instruction.

| Boundary | Enforcement Mechanism |
|---|---|
| No model self-modification | No write access to agent config at runtime |
| No uncontrolled internet access | All outbound calls go through allowlisted tool set only |
| No financial transactions | No payment or billing tools in skill registry |
| No system-level self-rewriting | Skill registry is read-only during all research loops |
| No unbounded iteration | Hard cap enforced by Meta-Evaluator — not LLM judgment |
| No self-referential objectives | Objective classifier in R1 rejects objectives targeting agent, system, model, or runtime performance |

---

## 5. System Architecture

```
[ User: High-Level Objective String ]
                │
                ▼
┌──────────────────────────────────────────┐
│  PHASE 0: Pre-Implementation Audit       │ ← Hard gate. Do not pass without completion.
│  + Ranking Consistency Test              │   Produces: ranking_consistency_report.json
└──────────────────────────────────────────┘
                │
                ▼
┌──────────────────────────────────────────┐
│  R1: Goal Decomposition Engine           │ → ObjectiveSpec (JSON, immutable post-write)
│  (OpenClaw Skill)                        │ → Constraint + ambiguity validation
│                                          │ → Self-modification classifier gate
│                                          │ → Metric definition + validation script lock
│                                          │ → Vector weights validated (sum = 1.0)
└──────────────────────────────────────────┘
                │
                ▼
┌──────────────────────────────────────────┐
│  R5: Structured Research Memory (Postgres)│ ← Single source of truth.
│                                          │   All state below this line persists here.
│  • objectives (immutable)                │
│  • hypotheses (with dual hashes)         │
│  • experiments (with metric vectors)     │
│  • metric_history (convergence tracking) │
│  • rejected_hypotheses (dedup archive)   │
│  • iteration_state (loop control)        │
│  • embedding_models (version tracking)   │
│  • ranking_consistency_results (Phase 0) │
└──────────────────────────────────────────┘
                │
                ▼
┌──────────────────────────────────────────────────────────────────┐
│  R2: Multi-Agent Hypothesis Engine                               │
│                                                                  │
│  ┌──────────────────┐   ┌──────────────────┐                   │
│  │  Optimizer       │   │  Explorer         │                   │
│  │  temp: 0.2–0.3   │   │  temp: 0.8–1.0   │                   │
│  │  incremental     │   │  mechanism-level  │                   │
│  └──────────────────┘   └──────────────────┘                   │
│  ┌──────────────────┐   ┌──────────────────┐                   │
│  │  Domain Expert   │   │  Critic           │                   │
│  │  temp: 0.5       │   │  temp: 0.5        │                   │
│  │  feasibility     │   │  adversarial      │                   │
│  └──────────────────┘   └──────────────────┘                   │
│                                                                  │
│  Dual-hash dedup check against rejected_hypotheses              │
│  Structural novelty scoring (parameter / strategy / mechanism)  │
│  Hard gate: ≥1 mechanism-level hypothesis required              │
│  Diversity threshold adaptive check                             │
│  Output: HypothesisSet[] — structured JSON only, no prose       │
└──────────────────────────────────────────────────────────────────┘
                │
                ▼
┌──────────────────────────────────────────┐
│  R3: Structured Debate Protocol          │ → Hard-coded 5-round state machine
│                                          │ → Normalized ranking formula applied
│                                          │ → Output: RankedHypothesisList (top 3)
└──────────────────────────────────────────┘
                │
                ▼
┌──────────────────────────────────────────┐
│  R4: Docker Sandbox Execution Layer      │ → Container per experiment
│                                          │ → --network none, --read-only FS
│                                          │ → CPU + memory caps, hard timeout
│                                          │ → Container destroyed post-execution
│                                          │ → Programmatic metric extraction only
│                                          │ → metric_verified == false → LOG + SKIP
│                                          │ → No LLM fallback. Ever.
└──────────────────────────────────────────┘
                │
                ▼
┌──────────────────────────────────────────┐
│  R5: Metric Collector & Logger           │ → Writes ExperimentResult to DB
│                                          │ → Vector metric stored (JSONB)
│                                          │ → Weighted scalar computed for evaluator
└──────────────────────────────────────────┘
                │
                ▼
┌──────────────────────────────────────────┐
│  R6: Deterministic Meta-Evaluator        │ → No LLM. No exceptions.
│                                          │ → 8-branch decision logic
│                                          │ → Budget-aware: ROI = delta / cost_units
│                                          │ → Oscillation detection (4-iter pattern)
│                                          │ → Forced Explorer before termination
│                                          │ → Decision: CONTINUE / REFINE /
│                                          │             PIVOT / TERMINATE
│                                          │
│                ├── CONTINUE ─────────────┤
│                ├── REFINE ───────────────┤→ back to R2 with context
│                ├── PIVOT ────────────────┤→ back to R2 with Explorer injection
│                └── TERMINATE ────────────→ Final report generation
└──────────────────────────────────────────┘
```

---

## 6. Module Specifications

### R1 — Goal Decomposition Engine

**Type:** OpenClaw Skill  
**Trigger:** User submits high-level objective string  
**Output:** Immutable `ObjectiveSpec`

**Responsibilities:**
- Parse natural language goal into structured spec
- Identify optimization direction (minimize / maximize / satisfy)
- Extract measurable constraints and validate they are verifiable
- Detect and halt on underspecified objectives (no measurable target)
- Detect and halt on conflicting constraints (surface to user — do not silently resolve)
- Run self-modification classifier gate
- Define metric with validation script and vector components
- Validate vector weights sum to 1.0

**Self-Modification Classifier Gate:**

Reject any objective containing references to: `agent`, `system`, `runtime`, `model`, `performance`, `execution speed`, `memory usage`, `skill`, `plugin`, `OpenClaw`, `self`, `throughput`, `latency`. Classifier must be conservative. False positives are acceptable. False negatives are not. Rejection is logged and surfaced to user with explanation.

**ObjectiveSpec Schema:**

```json
{
  "objective_id": "uuid",
  "objective_type": "minimize | maximize | satisfy",
  "objective_target": "string",
  "constraints": [
    {
      "variable": "string",
      "operator": ">= | <= | ==",
      "value": "any",
      "verifiable": "boolean"
    }
  ],
  "optimization_variables": ["string"],
  "metric_definition": {
    "name": "string",
    "vector_components": ["string"],
    "weighted_formula": "string",
    "vector_weights": { "component_name": "float" },
    "validation_script_path": "string",
    "extraction_method": "programmatic_script | api_call"
  },
  "budget_cap": "int",
  "iteration_cap": "int",
  "ranking_mode": "linear | exponential",
  "embedding_model_id": "uuid",
  "self_modification_screened": true,
  "created_at": "ISO8601"
}
```

**Critical constraints:**
- `vector_weights` values must sum to 1.0 — validated at R1, not assumed
- `validation_script_path` must resolve to an existing, executable script before ObjectiveSpec is written
- `ranking_mode` is written from `ranking_consistency_report.json` produced in Phase 0
- `embedding_model_id` references the local embedding model to be used for deduplication — immutable per objective
- ObjectiveSpec is immutable after write. No downstream module has write access to this record.

---

### R2 — Multi-Agent Hypothesis Engine

**Type:** Orchestrated OpenClaw sub-agents  
**Input:** ObjectiveSpec (read-only) + prior ExperimentResults + RejectedHypothesisArchive (from R5)

**Agent Roles:**

| Agent | Reasoning Bias | Temperature | Primary Responsibility |
|---|---|---|---|
| Optimizer | Conservative, incremental | 0.2–0.3 | Improve best-so-far by smallest safe delta |
| Explorer | High-variance, lateral | 0.8–1.0 | Generate mechanism-level alternatives — different causal pathway, not different parameters |
| Domain Expert | Prompt-conditioned specialization | 0.5 | Validate domain feasibility and real-world transferability |
| Critic | Adversarial | 0.5 | Find failure modes, metric gaming vectors, feasibility gaps, and metric gaming opportunities |

**Structural Novelty Classification:**

Each hypothesis is classified at one of three levels before any other scoring:

- **Parameter-level:** Same strategy, same mechanism, different parameter values — lowest novelty
- **Strategy-level:** Different approach within the same causal mechanism — medium novelty
- **Mechanism-level:** Fundamentally different causal pathway to the objective — highest novelty

**Hard gate:** If the HypothesisSet contains zero mechanism-level hypotheses, the Explorer agent is re-prompted with explicit instruction to generate a mechanism-level alternative. This re-prompt is attempted once. If the second attempt still produces no mechanism-level hypothesis, this is logged as an `explorer_failure` event and the iteration proceeds with the best available hypotheses — but the failure is prominently surfaced in the convergence report.

**Novelty score formula:**

```
novelty_score =
    (embedding_distance_weight × embedding_distance_to_nearest_prior)
  + (structural_difference_weight × structural_diff_score)
  + (method_class_change_bonus if method_class differs from all prior experiments)
```

Weights are configurable at deployment time. Parameter-level similarity penalty applied: if embedding distance < 0.15 to any prior tested hypothesis (not rejected — tested), apply a 0.2 penalty to novelty_score.

**Dual-hash deduplication against RejectedHypothesisArchive:**

Two independent checks before surfacing any hypothesis:

1. **Semantic hash** — embedding cosine similarity against all entries in `rejected_hypotheses`. Threshold: 0.92 (adaptive — see diversity threshold policy below).
2. **Structural hash** — fingerprint of `(method_class, parameter_keys, objective_variable_set)`.

A hypothesis is blocked only if **both** hashes match. Semantic match alone does not block — the underlying experiment may be genuinely different. Structural match alone does not block — the framing may differ enough to warrant re-evaluation. Both matching means the hypothesis is structurally identical to a previously rejected one.

**Embedding model:** Local deployment required. Recommended: `all-MiniLM-L6-v2` via sentence-transformers. Do not use API-based embedding for deduplication — this introduces latency, a non-local dependency, and a potential failure point in an otherwise local-capable system. Model version is stored in `embedding_models` table and bound to the objective via `embedding_model_id`.

**Diversity threshold adaptive policy:**

| Trigger | Action |
|---|---|
| < 1 mechanism-level hypothesis in last 3 iterations | `threshold -= 0.02` |
| > 5 near-duplicate hypotheses in last 3 iterations | `threshold += 0.02` |
| Threshold bounds | 0.85 ≤ threshold ≤ 0.97 |

Threshold updates only between iterations, never during. Changes are logged in `iteration_state`. If the threshold reaches 0.85 and mechanism-level hypothesis rate is still < 1 per 3 iterations, flag as `exploration_collapse` in the convergence report.

**Output Schema (per hypothesis):**

```json
{
  "hypothesis_id": "uuid",
  "iteration": "int",
  "author_agent": "optimizer | explorer | domain_expert",
  "description": "string",
  "novelty_level": "parameter | strategy | mechanism",
  "novelty_score": "0.0–1.0",
  "ordinal_delta_rank": "1–5 (1=highest predicted impact)",
  "normalized_delta": "float (computed from ordinal_delta_rank)",
  "confidence": "0.0–1.0",
  "domain_feasibility_score": "0.0–1.0",
  "real_world_transferability_score": "0.0–1.0",
  "experiment_proposal": {
    "method_class": "string",
    "parameters": {},
    "estimated_cost_units": "int",
    "noise_injection_config": {}
  },
  "weaknesses_flagged_by_critic": ["string"],
  "metric_gaming_vectors_flagged": ["string"],
  "dedup_cleared": true,
  "semantic_hash": "string",
  "structural_hash": "string"
}
```

**Output enforcement:** All agent outputs must be structured JSON. Any agent response containing prose without a valid JSON wrapper is discarded and re-prompted once. If the second attempt fails, that agent's slot is skipped for this iteration and the failure is logged in `iteration_state`. If all four agents fail JSON compliance in the same iteration, halt with `json_compliance_failure`.

---

### R3 — Structured Debate Protocol

**Type:** Deterministic orchestration state machine — not an LLM call  
**Input:** `HypothesisSet[]` from R2

**Round structure — hard-coded, non-negotiable:**

```
Round 1: Each agent submits hypothesis independently (from R2 output)

Round 2: Critic evaluates ALL hypotheses
         Output per hypothesis:
           - weakness_list: ["string"]
           - metric_gaming_vectors: ["string"]
           - feasibility_flags: ["string"]

Round 3: Optimizer submits ONE revision incorporating Critic feedback
         Explorer submits ONE revision incorporating Critic feedback
         (One revision each, maximum. No further rounds.)

Round 4: Domain Expert scores ALL revised hypotheses on two dimensions:
           - domain_feasibility_score: 0.0–1.0
           - real_world_transferability_score: 0.0–1.0

Round 5: Ranker selects top 3 hypotheses using normalized rank formula.
         Hypotheses ranked 4th and 5th are archived in rejected_hypotheses.
```

**Termination:** Fixed at 5 rounds. No LLM may extend, request additional rounds, or skip rounds. Enforced in code, not by instruction. This is what prevents consensus collapse and infinite deliberation.

**Ranking formula:**

```
rank_score =
    normalized_delta
  × confidence
  × domain_feasibility_score
  × real_world_transferability_score
  × novelty_multiplier
```

Where:

```
normalized_delta:
  IF ranking_mode == 'linear':
      normalized_delta = (6 - ordinal_delta_rank) / 5
      → rank 1: 1.0, rank 2: 0.8, rank 3: 0.6, rank 4: 0.4, rank 5: 0.2

  IF ranking_mode == 'exponential':
      normalized_delta = exp(5 - ordinal_delta_rank) / exp(4)
      → rank 1: 1.00, rank 2: 0.37, rank 3: 0.14, rank 4: 0.05, rank 5: 0.02
      Floor applied: max(normalized_delta, 0.05)
      (Prevents complete starvation of rank-5 hypotheses in low-quality iteration cycles)

novelty_multiplier:
  mechanism-level: 1.12
  strategy-level:  1.05
  parameter-level: 1.00
  (Cap at 1.12 — novelty cannot override feasibility)
```

`ranking_mode` is read from `ObjectiveSpec.ranking_mode`, set from Phase 0 results.

**Output Schema:**

```json
{
  "debate_id": "uuid",
  "iteration": "int",
  "ranked_hypotheses": [
    {
      "rank": "int",
      "hypothesis_id": "uuid",
      "rank_score": "float",
      "proceeding_to_experiment": "boolean"
    }
  ],
  "archived_hypothesis_ids": ["uuid"],
  "debate_completed_at": "ISO8601"
}
```

---

### R4 — Experiment Execution Layer

**Type:** OpenClaw tool execution + Docker-per-experiment sandbox  
**Input:** `RankedHypothesisList` (top 3 from R3)

**Sandbox specification — non-negotiable:**

- Docker container per experiment (subprocess isolation is insufficient)
- `--network none` — no outbound or inbound network access
- `--read-only` root filesystem — writes only to designated output mount
- Hard CPU cap: configurable, default `--cpus 2`
- Hard memory cap: configurable, default `--memory 2g`
- Hard timeout: configurable per objective, default 300 seconds
- Container destroyed after metric extraction, regardless of outcome

**Metric extraction — non-negotiable:**

- Extraction script is `ObjectiveSpec.metric_definition.validation_script_path`
- Script runs against container output directory after execution completes
- Output must be numeric vector (or single numeric) — if not, `metric_verified = false`
- **If `metric_verified == false`:** experiment is unconditionally invalid. Log it. Move to next hypothesis. Never fall back to LLM parsing. Never attempt to infer metric from output text. This rule has no exceptions.
- Budget decrement: `cost_units` are charged for every experiment execution regardless of outcome (failed experiments consume resources). This is explicit — the system cannot cycle on failed experiments to avoid budget consumption.

**Noise injection:** `experiment_proposal.noise_injection_config` defines perturbation applied to parameters before execution. Required for all experiments. Prevents simulation overfitting.

**Output Schema:**

```json
{
  "experiment_id": "uuid",
  "hypothesis_id": "uuid",
  "iteration": "int",
  "parameters_used": {},
  "noise_applied": {},
  "estimated_cost_units": "int",
  "actual_cost_units": "float",
  "raw_output_path": "string",
  "metric_value": {
    "components": { "component_name": "float" },
    "weighted_scalar": "float"
  },
  "metric_verified": "boolean",
  "execution_time_ms": "int",
  "container_exit_code": "int",
  "error": "string | null"
}
```

---

### R5 — Structured Research Memory

**Type:** Postgres database  
**Purpose:** Single source of truth for all CRL research state. Queryable, persistent, independent of OpenClaw's conversational memory.

See Section 8 for complete production DDL including all indexes.

**Critical design requirements:**

- `metric_value` and `metric_vector` columns are JSONB — vector-capable from day one, not requiring migration for multi-objective support
- `rejected_hypotheses` stores both `semantic_hash` and `structural_hash` — dual-hash deduplication requires both
- `embedding_model_id` is stored on each objective and queried during dedup — dedup uses the same model for the full objective run, no mid-run drift
- `iteration_state.diversity_threshold` is mutable between iterations only, and every change is logged

---

### R6 — Deterministic Meta-Evaluator

**Type:** Deterministic evaluation logic — zero LLM involvement  
**Invoked:** After every experiment batch  
**Inputs:** `metric_history`, `iteration_state`, budget state, experiment cost log

**Decision logic (applied in strict priority order):**

```
1. EXECUTION FAILURE CHECK
   IF no valid experiments this iteration (all metric_verified == false):
   → HALT with execution_failure error report.
   Do not silently continue to next iteration.

2. HARD CAP CHECK
   IF current_iteration >= iteration_cap:
   → TERMINATE

3. BUDGET CHECK
   IF budget_remaining <= 0:
   → TERMINATE

4. OSCILLATION CHECK
   IF metric_history shows alternating improvement/regression
   over last 4 consecutive iterations:
   → oscillation_flag = true → REFINE (tighten hypothesis constraints)
   Note: Oscillation is distinct from plateau. Requires different response.

5. PLATEAU CHECK
   IF abs(delta) < convergence_threshold for last 3 iterations
   AND oscillation_flag == false:
     IF forced_explore_triggered == false:
       → Set forced_explore_triggered = true → PIVOT
       (Explorer agent runs with maximum variance, one cycle)
     ELSE (forced explore already ran and plateau persists):
       → TERMINATE

6. VARIANCE INSTABILITY CHECK
   IF variance(metric_history.delta, last 5) > instability_threshold:
   → REFINE: Narrow hypothesis search space, reduce Explorer temperature for one cycle

7. BUDGET-AWARE ROI CHECK
   Compute: ROI = metric_delta / cost_units for last iteration
   IF ROI < minimum_roi_threshold:
   → PIVOT: Deprioritize current method_class, promote Explorer with
     instruction to change method_class

8. NORMAL IMPROVEMENT
   IF delta > improvement_threshold AND none of above triggered:
   → CONTINUE
```

**Output Schema:**

```json
{
  "evaluator_id": "uuid",
  "iteration": "int",
  "decision": "CONTINUE | REFINE | PIVOT | TERMINATE",
  "decision_reason": "string",
  "decision_branch": "1_execution_failure | 2_hard_cap | 3_budget | 4_oscillation | 5_plateau | 6_variance | 7_roi | 8_normal",
  "plateau_detected": "boolean",
  "oscillation_detected": "boolean",
  "forced_explore_triggered": "boolean",
  "budget_remaining": "float",
  "current_roi": "float",
  "convergence_score": "float",
  "evaluated_at": "ISO8601"
}
```

**Constraint:** Fully deterministic. Every decision branch is unit-testable with synthetic `metric_history` inputs. No LLM call is made here under any circumstance.

---

## 7. Data Contracts Between Modules

No natural language is passed between modules. Every interface is typed JSON. This is an architectural requirement — it is what makes the system testable, auditable, and debuggable.

| From | To | Contract Object | Failure Behavior |
|---|---|---|---|
| User | R1 | Raw objective string | R1 validates or halts with explicit error |
| R1 | R5 | `ObjectiveSpec` | Write fails → halt |
| R1 → R2 | (read-only ref) | `ObjectiveSpec` | — |
| R2 | R3 | `HypothesisSet[]` | Prose leakage → discard + re-prompt once; second failure → skip agent slot |
| R3 | R4 | `RankedHypothesisList` | Empty list → halt |
| R4 | R5 | `ExperimentResult` | `metric_verified=false` → log, skip, charge budget |
| R5 | R6 | `MetricHistory + IterationState` | DB read failure → halt |
| R6 | R2 | `LoopDecision + ContextUpdate` | `TERMINATE` → exit loop, generate final report |

---

## 8. Complete Database Schema (Production DDL)

```sql
-- Embedding model registry
CREATE TABLE embedding_models (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  model_name TEXT NOT NULL,
  version TEXT NOT NULL,
  local_path TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Core research objectives (immutable after creation)
CREATE TABLE objectives (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  spec JSONB NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('active', 'completed', 'halted')),
  ranking_mode TEXT NOT NULL CHECK (ranking_mode IN ('linear', 'exponential')),
  embedding_model_id UUID NOT NULL REFERENCES embedding_models(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- All hypotheses ever generated
CREATE TABLE hypotheses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  objective_id UUID NOT NULL REFERENCES objectives(id),
  iteration INT NOT NULL,
  author_agent TEXT NOT NULL CHECK (
    author_agent IN ('optimizer', 'explorer', 'domain_expert')
  ),
  description TEXT NOT NULL,
  novelty_level TEXT NOT NULL CHECK (
    novelty_level IN ('parameter', 'strategy', 'mechanism')
  ),
  novelty_score FLOAT NOT NULL,
  ordinal_delta_rank INT NOT NULL CHECK (ordinal_delta_rank BETWEEN 1 AND 5),
  normalized_delta FLOAT NOT NULL,
  confidence FLOAT NOT NULL CHECK (confidence BETWEEN 0 AND 1),
  domain_feasibility_score FLOAT CHECK (domain_feasibility_score BETWEEN 0 AND 1),
  real_world_transferability_score FLOAT CHECK (
    real_world_transferability_score BETWEEN 0 AND 1
  ),
  rank_score FLOAT,
  semantic_hash TEXT NOT NULL,
  structural_hash TEXT NOT NULL,
  status TEXT NOT NULL CHECK (
    status IN ('proposed', 'tested', 'rejected', 'archived')
  ),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- All experiment executions
CREATE TABLE experiments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hypothesis_id UUID NOT NULL REFERENCES hypotheses(id),
  iteration INT NOT NULL,
  parameters JSONB NOT NULL,
  noise_applied JSONB,
  metric_value JSONB,          -- {"components": {"name": float}, "weighted_scalar": float}
  metric_verified BOOLEAN NOT NULL DEFAULT FALSE,
  estimated_cost_units INT,
  actual_cost_units FLOAT,
  execution_time_ms INT,
  container_exit_code INT,
  error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Convergence tracking (one record per iteration)
CREATE TABLE metric_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  objective_id UUID NOT NULL REFERENCES objectives(id),
  iteration INT NOT NULL,
  best_metric_scalar FLOAT,
  metric_vector JSONB,         -- Full vector for audit and multi-objective support
  delta FLOAT,
  variance FLOAT,
  oscillation_flag BOOLEAN NOT NULL DEFAULT FALSE,
  novelty_level_distribution JSONB, -- {"parameter": int, "strategy": int, "mechanism": int}
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Rejected hypothesis archive for deduplication
CREATE TABLE rejected_hypotheses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  objective_id UUID NOT NULL REFERENCES objectives(id),
  description TEXT NOT NULL,
  semantic_hash TEXT NOT NULL,
  structural_hash TEXT NOT NULL,
  rejection_reason TEXT NOT NULL,
  iteration_rejected INT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Loop control state (one active record per objective)
CREATE TABLE iteration_state (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  objective_id UUID NOT NULL REFERENCES objectives(id),
  current_iteration INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL CHECK (
    status IN ('running', 'paused', 'terminated', 'completed')
  ),
  last_evaluator_decision TEXT CHECK (
    last_evaluator_decision IN ('CONTINUE', 'REFINE', 'PIVOT', 'TERMINATE')
  ),
  forced_explore_triggered BOOLEAN NOT NULL DEFAULT FALSE,
  budget_remaining FLOAT NOT NULL,
  diversity_threshold FLOAT NOT NULL DEFAULT 0.92,
  diversity_threshold_history JSONB NOT NULL DEFAULT '[]',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Phase 0 ranking consistency test results
CREATE TABLE ranking_consistency_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  objective_type TEXT NOT NULL,
  objective_id UUID REFERENCES objectives(id),
  llm_model_version TEXT NOT NULL,
  prompt_template_hash TEXT NOT NULL,
  embedding_model_id UUID REFERENCES embedding_models(id),
  temperature_settings JSONB NOT NULL,
  run_count INT NOT NULL DEFAULT 20,
  mean_tau FLOAT NOT NULL,
  std_tau FLOAT NOT NULL,
  min_tau FLOAT NOT NULL,
  tau_production_mean FLOAT,
  tau_greedy_mean FLOAT,
  temperature_delta_interpretation TEXT,
  mapping_decision TEXT NOT NULL CHECK (
    mapping_decision IN ('exponential', 'linear', 'unstable')
  ),
  rank_compression_detected BOOLEAN NOT NULL DEFAULT FALSE,
  rank_dominance_profile JSONB,
  positional_bias_detected BOOLEAN NOT NULL DEFAULT FALSE,
  positional_bias_profile JSONB,
  mean_resolution_depth FLOAT,
  deep_resolution_rate FLOAT,
  invalid_run_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Individual ranking run outputs for full audit trail
CREATE TABLE ranking_run_outputs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  consistency_result_id UUID NOT NULL REFERENCES ranking_consistency_results(id),
  run_index INT NOT NULL,
  temperature_mode TEXT NOT NULL CHECK (temperature_mode IN ('production', 'greedy')),
  hypothesis_injection_order JSONB NOT NULL,
  raw_llm_output JSONB NOT NULL,
  validated BOOLEAN NOT NULL,
  canonical_ranking_vector JSONB NOT NULL,
  ranking_resolution_path JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Performance indexes (all required before first research loop)
CREATE INDEX idx_hypotheses_objective ON hypotheses(objective_id);
CREATE INDEX idx_hypotheses_semantic_hash ON hypotheses(semantic_hash);
CREATE INDEX idx_hypotheses_structural_hash ON hypotheses(structural_hash);
CREATE INDEX idx_hypotheses_iteration ON hypotheses(objective_id, iteration);

CREATE INDEX idx_rejected_objective ON rejected_hypotheses(objective_id);
CREATE INDEX idx_rejected_semantic_hash ON rejected_hypotheses(semantic_hash);
CREATE INDEX idx_rejected_structural_hash ON rejected_hypotheses(structural_hash);

CREATE INDEX idx_experiments_hypothesis ON experiments(hypothesis_id);
CREATE INDEX idx_experiments_iteration ON experiments(objective_id, iteration);

CREATE INDEX idx_metric_history_objective ON metric_history(objective_id);
CREATE INDEX idx_metric_history_iteration ON metric_history(objective_id, iteration);

CREATE INDEX idx_iteration_state_objective ON iteration_state(objective_id);
CREATE INDEX idx_ranking_results_objective ON ranking_consistency_results(objective_id);
```

---

## 9. Cost Model

**Unified cost metric:**

```
cost_units = α(tokens_used) + β(container_runtime_ms) + γ(cpu_seconds)
```

**Calibration procedure (deployment-level, not per-objective):**

1. Select 3 benchmark experiment types: CPU-heavy local computation, LLM-token-heavy reasoning, I/O-heavy short-runtime
2. Run 20 experiments per type (60 total)
3. Record `tokens_used`, `runtime_ms`, `cpu_seconds`, and actual monetary cost for each
4. Normalize each component to z-score within the deployment environment
5. Fit α, β, γ via ridge regression: `actual_cost ≈ α(tokens) + β(runtime_ms) + γ(cpu_seconds)`
6. Store α, β, γ in system configuration
7. Lock for all objectives in that deployment — no per-objective recalibration, no adaptive mid-run tuning

This prevents Meta-Evaluator feedback instability that would arise from dynamically adjusting the cost model it uses for termination decisions.

**Budget decrement rule:** `budget_remaining -= actual_cost_units` after every experiment execution, regardless of `metric_verified` status. Failed experiments consume resources. The system cannot exploit verification failures to avoid budget consumption.

---

## 10. Ranking Formula (Complete Reference)

**Ordinal delta rank normalization:**

```python
def normalize_delta(ordinal_rank: int, ranking_mode: str) -> float:
    if ranking_mode == 'linear':
        return (6 - ordinal_rank) / 5
        # rank 1 → 1.0, rank 2 → 0.8, rank 3 → 0.6, rank 4 → 0.4, rank 5 → 0.2

    elif ranking_mode == 'exponential':
        import math
        raw = math.exp(5 - ordinal_rank) / math.exp(4)
        return max(raw, 0.05)  # Floor prevents complete starvation of rank-5 hypotheses
        # rank 1 → 1.000, rank 2 → 0.368, rank 3 → 0.135, rank 4 → 0.050, rank 5 → 0.050
```

**Novelty multiplier:**

```python
NOVELTY_MULTIPLIERS = {
    'mechanism': 1.12,
    'strategy': 1.05,
    'parameter': 1.00
}
# Cap at 1.12. Novelty cannot override feasibility.
```

**Final rank score:**

```python
def compute_rank_score(hypothesis: dict, ranking_mode: str) -> float:
    normalized_delta = normalize_delta(
        hypothesis['ordinal_delta_rank'], ranking_mode
    )
    return (
        normalized_delta
        * hypothesis['confidence']
        * hypothesis['domain_feasibility_score']
        * hypothesis['real_world_transferability_score']
        * NOVELTY_MULTIPLIERS[hypothesis['novelty_level']]
    )
```

**Ranking mode selection:** Determined by Phase 0 Ranking Consistency Test. Written to `ObjectiveSpec.ranking_mode`. Immutable per objective. Full specification in companion document: *CRL Ranking Prompt Specification v1.1 Final*.

---

## 11. Risk & Failure Mode Analysis

### Tier 1 — Catastrophic (System Halt Required)

**Illusory Autonomy**  
The system runs 10+ cycles and appears autonomous, but all hypotheses are parameter-level tweaks. The system is a looped prompt engine, not a research engine. This is the primary existential failure mode of the project.  
*Mitigation:* Mechanism-level hypothesis gate in R2. `novelty_level_distribution` tracked in `metric_history` per iteration. If mechanism-level hypotheses never appear across 5+ iterations, `exploration_collapse` is flagged in the convergence report. The report surfaces this as a primary finding, not a footnote.

**Objective Drift**  
Agents gradually reinterpret the objective over iterations, shifting the optimization target.  
*Mitigation:* ObjectiveSpec written once, immutable, included verbatim in every agent prompt. No agent has write access. Mid-loop reinterpretation is architecturally impossible, not just discouraged.

**Metric Gaming**  
The system optimizes the proxy metric rather than the true intent. If the metric is gameable, the system will find the exploit.  
*Mitigation:* Metric definition and validation script locked at R1. Critic is explicitly tasked in Round 2 with identifying metric gaming vectors (stored in `metric_gaming_vectors_flagged`). If Critic flags a metric as gameable, R1 must be re-run with a more precise definition before the loop continues. Noise injection in all experiments disrupts exploitation of deterministic gaming strategies.

**Metric Leakage**  
Validation script fails partially. LLM infers metric from partial text output.  
*Mitigation:* `metric_verified == false` → experiment is unconditionally invalid. No fallback. No LLM parsing. No inference. This rule has no exceptions and no override path.

**Sandbox Escape**  
Malformed or adversarially crafted experiment code escapes isolation.  
*Mitigation:* Docker-per-experiment is non-negotiable. Container spec: `--network none`, `--read-only`, explicit CPU and memory caps, destroyed after metric extraction. Subprocess-level isolation is insufficient.

### Tier 2 — Quality Degradation

**Diversity Collapse**  
After several iterations, Optimizer consistently produces higher deltas. Explorer's proposals are deprioritized. The search space narrows to incremental improvement.  
*Mitigation:* Adaptive diversity threshold lowers automatically. Budget-aware ROI check in R6 triggers PIVOT when current method_class has low ROI. Explorer temperature is never reduced, regardless of performance history. Forced Explorer round before any plateau-triggered termination.

**Hypothesis Deduplication Over-Blocking**  
Tight semantic threshold blocks genuinely novel hypotheses adjacent to failed ones. Exploration collapses.  
*Mitigation:* Dual-hash system. Semantic match alone does not block. Adaptive threshold responds to exploration rate. Threshold floor at 0.85.

**False Convergence**  
Plateau detection triggers termination on a local optimum.  
*Mitigation:* Forced Explorer round before any plateau termination. Oscillation detection distinguishes true plateau (terminate) from oscillating search space (refine). These require different responses — treating oscillation as plateau causes premature termination.

**Simulation Overfitting**  
Experiments are optimized for the simulation environment, not real-world performance.  
*Mitigation:* Domain Expert scores `real_world_transferability_score` as a separate field from `domain_feasibility_score`, both factored into `rank_score`. Noise injection required in all experiment parameters.

### Tier 3 — Systemic / Safety

**Unintentional Self-Optimization**  
Objective is framed in a way that causes the system to optimize its own reasoning, skill selection, or prompt conditioning. Gradual drift toward recursive self-improvement.  
*Mitigation:* Self-modification classifier gate in R1 rejects at intake. Conservative classifier — false positives accepted. Skill registry is read-only during all research loops. Critic is explicitly prompted to flag any hypothesis targeting the research process or agent behavior.

**Emergent Goal Generalization**  
After many cycles, agents begin treating "improve research performance" as an implicit secondary objective. Proposals about the research process itself emerge.  
*Mitigation:* Critic flags any such proposal. These are rejected and logged. The convergence report surfaces any detection of this pattern as a safety finding.

**Embedding Model Drift**  
If embedding model changes mid-deployment, semantic hashes from prior hypotheses become incomparable to new ones. Deduplication breaks silently.  
*Mitigation:* `embedding_model_id` is bound to each objective at creation. Deduplication queries filter by the model version associated with the current objective. Model changes require a new deployment configuration — they do not affect in-flight objectives.

---

## 12. Implementation Roadmap

**Team assumption:** 1–2 engineers, full-time, familiar with OpenClaw internals.

| Phase | Module | Duration | Exit Criteria |
|---|---|---|---|
| 0 | Pre-Implementation Audit + Ranking Consistency Test | 1–2 weeks | Feasibility doc complete; `ranking_consistency_report.json` produced; `ranking_mode` determined; all audit items verified |
| 1 | R5: Research Memory DB + all indexes | 2 weeks | Schema live; all indexes created; dual-hash dedup pipeline passing; embedding versioning operational |
| 2 | R1: Goal Decomposition Engine | 1–2 weeks | ObjectiveSpec produced from 10 test inputs; self-modification gate rejecting correctly; ambiguous inputs halting; `vector_weights` validation enforced |
| 3 | R4: Docker Sandbox Execution Layer | 2–3 weeks | Container running with full security spec; metric extraction 100% programmatic; `metric_verified=false` halting correctly; budget decrement on failed experiments confirmed |
| 4 | R2: Hypothesis Engine (single agent) | 1 week | Optimizer producing valid structured JSON with zero prose leakage on 20 consecutive runs |
| 5 | R2: Full 4-agent + novelty scoring | 2–3 weeks | All four agents structured; structural novelty scoring operational; mechanism-level gate functioning; diversity threshold adaptive logic operational |
| 6 | R3: Structured Debate Protocol | 1 week | Full 5-round debate executing deterministically; ranking formula producing correct scores on synthetic inputs; both linear and exponential modes tested |
| 7 | R6: Meta-Evaluator | 1 week | All 8 decision branches unit-tested with synthetic metric_history; deterministic output confirmed; forced Explorer trigger verified |
| 8 | Integration + Stress Testing | 2–3 weeks | 10-cycle autonomous run complete on real objective; plateau scenario tested; metric-gaming scenario tested; diversity collapse scenario tested; convergence report produced |

**Total estimate:** 13–18 weeks for a non-brittle implementation.

**Critical sequencing notes:**
- Phase 0 is a hard gate. No other phase begins without it.
- Phase 1 (memory) before Phase 4 (hypothesis engine). Agents must have a write target before generating anything.
- Phase 3 (Docker sandbox) before Phase 8 (integration). Never attempt full loop integration with a mock sandbox.
- Phase 2 (`ranking_mode` from Phase 0 must be known before ObjectiveSpec schema is finalized) — `ranking_mode` column value comes from `ranking_consistency_report.json`.
- Phases 4 and 5 may partially overlap but novelty scoring must be complete before Phase 6.

---

## 13. Stretch Goals (Post-MVP, Still Bounded)

All stretch goals must remain within the non-goal boundaries defined in Section 4.

- **Adaptive agent weighting:** Agents whose hypotheses historically produce higher experiment ROI receive higher selection weight in future iterations, within defined bounds. No agent weight reaches zero.
- **Domain skill packs:** R1 loads domain-specific prompt conditioning (manufacturing, biology, finance, logistics) based on objective classification. Reduces time to first mechanism-level hypothesis.
- **Cross-run transfer:** Mechanism-level hypothesis patterns from past objectives inform Explorer priors for new runs with structurally similar objective types.
- **Cost-aware experiment batching:** Schedule cheap experiments first within an iteration; use early results to prune expensive experiments before they run.
- **Pareto frontier support (V4):** Replace scalar collapse with dominance-scored Pareto frontier for true multi-objective optimization. Meta-Evaluator convergence logic requires significant redesign.
- **Human review checkpoints (V4):** Optional pause-and-review gates at configurable iteration intervals, implemented as a `PAUSED` state in `iteration_state` without breaking autonomous loop logic.

---

*End of ClawResearch (CRL) PRD v3.2 Final.*  
*Companion document: CRL Ranking Prompt Specification v1.1 Final.*  
*All architectural decisions resolved. No TBD items. Implementation-ready.*
