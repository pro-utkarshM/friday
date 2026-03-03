# CRL Ranking Prompt Specification — Final
## Phase 0 Ranking Consistency Test

**Version:** 1.1 Final  
**Status:** Implementation-Ready  
**Purpose:** Empirically determine ordinal ranking stability of CRL agents, and select the normalization strategy (`linear` or `exponential`) for use in the ranking formula across the full CRL research loop.  
**Output:** `ranking_consistency_report.json` — gates PRD Section 12, Phase 0 completion.  
**Companion document:** CRL PRD v3.2 Final

---

## Table of Contents

1. Why This Test Exists
2. What the Test Measures
3. Test Setup
4. Ranking Prompt Template
5. Positional Bias Mitigation
6. Output Validation
7. Statistical Analysis
8. Decision Logic
9. Dual-Temperature Protocol
10. Frozen Hypothesis Sets
11. Database Schema
12. Execution Checklist
13. Output Report Schema
14. Failure Response Protocol

---

## 1. Why This Test Exists

The CRL ranking formula applies either linear or exponential normalization to ordinal delta ranks. Exponential normalization creates strong selection pressure — rank-1 hypotheses receive dramatically more weight than rank-2. Linear normalization is conservative — the gradient is uniform.

The correct choice depends on a single empirical question: **are the agents' ordinal rankings stable enough to justify strong selection pressure?**

If agents rank the same hypothesis set consistently across repeated prompts (high Kendall τ), exponential mapping is safe — selection pressure tracks real quality differences. If rankings are noisy (low τ), exponential mapping amplifies noise — premature convergence on accidentally high-ranked hypotheses becomes likely.

This test answers that question before any CRL loop is built. The answer is stored in `ranking_consistency_report.json` and written to `ObjectiveSpec.ranking_mode`. It is immutable per objective.

**This is not a correctness test. It is a stability test.** We are not asking whether agents rank correctly. We are asking whether they rank consistently.

---

## 2. What the Test Measures

- **Kendall τ:** Pairwise concordance between ranking vectors across 20 runs. Measures stability.
- **Dual-temperature delta (τ_greedy − τ_production):** Separates sampling variance from reasoning instability. Determines the correct intervention if τ is low.
- **Rank compression / extremity utilization:** Detects whether agents avoid committing to extreme ranks (1 and 5), which would indicate low resolution regardless of τ.
- **Rank dominance profile:** Detects whether one hypothesis consistently receives the same rank, which is a positive signal when it occurs at rank 1.
- **Positional bias (Spearman ρ):** Detects whether injection order into the prompt correlates with assigned rank. If it does, the prompt has an ordering sensitivity problem that must be fixed before deployment.
- **Resolution depth:** Measures how deep into the tiebreaker priority chain the ranking required to resolve. Separates hypothesis-set ambiguity from prompt reasoning instability.

---

## 3. Test Setup

### 3.1 Objective Types

Run the full test protocol against three distinct objective types:

| Type | Description | Why Included |
|---|---|---|
| `numeric_optimization` | Single scalar metric, clear gradient | Baseline case — ranking should be most stable here |
| `multi_objective` | Two competing metrics, weighted scalar collapse | Tests stability under tradeoff tension |
| `constraint_heavy` | Feasibility constraints dominate, metric is secondary | Tests whether agents weight constraints consistently |

### 3.2 Frozen Hypothesis Sets

**One fixed set of 5 hypotheses per objective type.** These are frozen — identical across all 20 runs. Hypothesis generation variance must not contaminate ranking variance.

**Design requirements for each frozen set:**
- Exactly 5 hypotheses
- At least 1 mechanism-level hypothesis
- At least 1 parameter-level hypothesis
- At least 2 hypotheses that are genuinely ambiguous relative to each other in predicted impact (to exercise the tiebreaker chain — see Section 10)
- At least 1 hypothesis that the Critic would flag for a feasibility concern

**Critical:** If all 5 hypotheses have obviously different quality, any model will rank them consistently and τ will be artificially high. The test is only informative if ambiguous pairs exist that force the model to use criteria priority 2, 3, or 4.

### 3.3 Prompt and State Control

For each run:
- Only execute R3 Round 5 ranking logic (skip R2 generation entirely)
- Use the frozen HypothesisSet as direct input
- Reset conversation state between runs (no memory carryover)
- Disable all OpenClaw memory effects
- Temperature settings fixed per agent role (see Section 9 for dual-temperature protocol)
- Prompt template SHA256 hash recorded before first run and verified before each subsequent run

---

## 4. Ranking Prompt Template

```
You are ranking a set of hypotheses for a structured research optimizer.

## Your Task
Assign a unique ordinal rank from 1 to 5 to each hypothesis.
- Rank 1 = highest priority for experimentation
- Rank 5 = lowest priority for experimentation
- Each rank must be used exactly once. No ties permitted.

## Ranking Criterion (apply in strict priority order)

**Priority 1 — Predicted Impact**
Which hypothesis, if validated, would produce the largest improvement in the
objective metric within the allowed experiment budget?
Use the predicted_metric_delta_rank field as the primary signal.
Lower ordinal delta rank = higher predicted impact.

**Priority 2 — Feasibility**
If two hypotheses have equal predicted impact, rank higher the one with a
higher domain_feasibility_score.

**Priority 3 — Transferability**
If two hypotheses are still tied, rank higher the one with a higher
real_world_transferability_score.

**Priority 4 — Novelty (tiebreaker only)**
If two hypotheses are still tied, rank higher the one with a higher
novelty_level (mechanism > strategy > parameter).

Do NOT allow novelty to override feasibility or predicted impact.
Do NOT add reasoning beyond what the criteria specify.
Do NOT re-order criteria based on your judgment of the objective.

Read all five hypotheses completely before ranking any of them.

## Objective
{{ objective_target }}
Optimization direction: {{ objective_type }}

## Hypotheses

{% for h in hypotheses %}
---
Hypothesis ID: {{ h.hypothesis_id }}
Description: {{ h.description }}
Novelty Level: {{ h.novelty_level }}
Predicted Delta Rank: {{ h.ordinal_delta_rank }} (1=highest impact, 5=lowest)
Confidence: {{ h.confidence }}
Feasibility: {{ h.domain_feasibility_score }}
Transferability: {{ h.real_world_transferability_score }}
Critic Weaknesses: {{ h.weaknesses_flagged_by_critic | join(", ") }}
{% endfor %}

## Output Format
Return ONLY the following JSON. No explanation. No preamble. No markdown fences.

{
  "rankings": [
    { "hypothesis_id": "uuid", "rank": 1 },
    { "hypothesis_id": "uuid", "rank": 2 },
    { "hypothesis_id": "uuid", "rank": 3 },
    { "hypothesis_id": "uuid", "rank": 4 },
    { "hypothesis_id": "uuid", "rank": 5 }
  ],
  "ranking_resolution_path": ["impact"]
}

## ranking_resolution_path Instructions
List every criterion required to resolve at least one ranking decision, in the
order they were invoked. Use only: "impact", "feasibility",
"transferability", "novelty"

Examples:
- Impact alone decided all ranks: ["impact"]
- Impact decided most, feasibility broke one tie: ["impact", "feasibility"]
- All four criteria required: ["impact", "feasibility", "transferability", "novelty"]

This is a factual record of which criteria were invoked. It is not a summary
of your reasoning process.
```

---

## 5. Positional Bias Mitigation

The hypothesis list injected into the template must be shuffled before each run using the run index as a seed. This ensures different injection order per run (bias mitigation) while keeping each run reproducible (audit reproducibility).

```python
import random

def prepare_hypothesis_list(hypotheses: list, run_index: int) -> list:
    """
    Shuffle hypotheses using run_index as seed.
    - Different order per run: mitigates positional bias
    - Reproducible per run: enables full audit
    """
    rng = random.Random(run_index)
    shuffled = hypotheses.copy()
    rng.shuffle(shuffled)
    return shuffled
```

Store `run_index` and the resulting injection order in `ranking_run_outputs` alongside the raw output. Positional bias detection (Section 8.3) requires the injection order to be queryable.

---

## 6. Output Validation

Before logging any ranking result:

```python
def validate_ranking_output(output: dict, hypothesis_ids: list) -> bool:
    """
    Enforces: exactly one of each rank 1-5, all hypothesis IDs present.
    """
    if "rankings" not in output:
        return False
    rankings = output["rankings"]
    if len(rankings) != 5:
        return False
    ranks_assigned = sorted([r["rank"] for r in rankings])
    ids_assigned = sorted([r["hypothesis_id"] for r in rankings])
    if ranks_assigned != [1, 2, 3, 4, 5]:
        return False
    if ids_assigned != sorted(hypothesis_ids):
        return False
    return True
```

**On validation failure:** Re-prompt once with explicit correction: "Your previous response was invalid. Each rank (1–5) must appear exactly once and all hypothesis IDs must be present. Return only valid JSON."

**If second attempt fails:** Log as invalid run. Do not include in τ calculation. If `invalid_run_count ≥ 3` for any objective type, halt the test and flag as `json_compliance_failure`. Do not proceed to implementation.

---

## 7. Statistical Analysis

### 7.1 Kendall's τ Computation

```python
from scipy.stats import kendalltau
import numpy as np

def compute_tau_matrix(ranking_vectors: list[list[int]]) -> dict:
    """
    ranking_vectors: list of 20 lists, each of length 5.
    Each inner list contains ranks assigned to hypotheses H1-H5
    in CANONICAL ORDER (sorted by hypothesis_id, not injection order).
    Canonical order decouples tau computation from positional effects.
    """
    n = len(ranking_vectors)
    taus = []
    for i in range(n):
        for j in range(i + 1, n):
            tau, _ = kendalltau(ranking_vectors[i], ranking_vectors[j])
            taus.append(tau)
    return {
        "mean_tau": float(np.mean(taus)),
        "std_tau": float(np.std(taus)),
        "min_tau": float(np.min(taus)),
        "n_pairs": len(taus)  # Should be 190 for 20 runs
    }
```

### 7.2 Rank Compression and Dominance Detection

```python
from collections import Counter

def detect_rank_compression(
    all_rankings: list[dict],
    run_count: int,
    extremity_threshold: float = 0.25
) -> dict:
    """
    Detects low-extremity utilization: model avoids assigning rank 1 or rank 5.
    With unique ranks enforced, each rank appears exactly once per run.
    Compression manifests as middle-rank clustering across runs.
    """
    rank_counts = Counter(r["rank"] for r in all_rankings)
    rank1_rate = rank_counts.get(1, 0) / run_count
    rank5_rate = rank_counts.get(5, 0) / run_count

    compression_detected = (
        rank1_rate < extremity_threshold or rank5_rate < extremity_threshold
    )

    return {
        "rank_distribution": dict(rank_counts),
        "rank1_utilization_rate": rank1_rate,
        "rank5_utilization_rate": rank5_rate,
        "compression_detected": compression_detected,
        "compression_type": "low_extremity" if compression_detected else "none"
    }


def detect_rank_dominance(
    all_rankings: list[dict],
    run_count: int,
    dominance_threshold: float = 0.80
) -> dict:
    """
    Detects whether one hypothesis dominates a specific rank position.
    High dominance on rank 1 = good signal (stable best hypothesis).
    High dominance on middle ranks = instability in middle resolution.
    """
    from collections import defaultdict
    rank_to_hypothesis = defaultdict(Counter)
    for r in all_rankings:
        rank_to_hypothesis[r["rank"]][r["hypothesis_id"]] += 1

    dominance = {}
    for rank, hyp_counts in rank_to_hypothesis.items():
        top_hyp, top_count = hyp_counts.most_common(1)[0]
        dominance[rank] = {
            "dominant_hypothesis_id": top_hyp,
            "dominance_rate": top_count / run_count,
            "is_dominant": (top_count / run_count) >= dominance_threshold
        }
    return dominance
```

### 7.3 Positional Bias Detection (Spearman ρ)

```python
from scipy.stats import spearmanr

def detect_positional_bias(
    run_outputs: list[dict],
    bias_threshold: float = 0.30
) -> dict:
    """
    For each hypothesis, computes Spearman ρ between:
    - Its injection position across runs (0-4)
    - Its assigned rank across runs (1-5)

    If |ρ| > threshold for any hypothesis, positional bias is present.
    Threshold 0.30 is intentionally strict: even weak positional preference
    compounds across 10-20 cycle optimization loops.
    """
    hypothesis_data = {}

    for run in run_outputs:
        if not run.get("validated"):
            continue
        injection_order = run["hypothesis_injection_order"]
        rankings = run["canonical_ranking_vector"]

        for position, hyp_id in enumerate(injection_order):
            if hyp_id not in hypothesis_data:
                hypothesis_data[hyp_id] = {"positions": [], "ranks": []}
            hypothesis_data[hyp_id]["positions"].append(position)
            hypothesis_data[hyp_id]["ranks"].append(rankings[hyp_id])

    results = {}
    bias_detected = False

    for hyp_id, data in hypothesis_data.items():
        if len(data["positions"]) < 5:
            continue
        rho, p_value = spearmanr(data["positions"], data["ranks"])
        results[hyp_id] = {
            "spearman_rho": float(rho),
            "p_value": float(p_value),
            "bias_detected": abs(rho) > bias_threshold
        }
        if abs(rho) > bias_threshold:
            bias_detected = True

    return {
        "per_hypothesis": results,
        "positional_bias_detected": bias_detected,
        "bias_threshold_used": bias_threshold
    }
```

### 7.4 Resolution Depth Analysis

```python
def analyze_resolution_depth(run_outputs: list[dict]) -> dict:
    """
    Measures how deep into the priority chain ranking required to resolve.
    High deep_resolution_rate + low τ = hypothesis set too ambiguous.
    Low deep_resolution_rate + low τ = prompt reasoning instability.
    These require different interventions.
    """
    depth_counts = Counter()
    for run in run_outputs:
        if not run.get("validated"):
            continue
        path = run.get("ranking_resolution_path", [])
        depth_counts[len(path)] += 1

    total = sum(depth_counts.values())
    if total == 0:
        return {"error": "no valid runs"}

    deep_count = depth_counts.get(3, 0) + depth_counts.get(4, 0)

    return {
        "depth_distribution": dict(depth_counts),
        "mean_resolution_depth": sum(
            k * v for k, v in depth_counts.items()
        ) / total,
        "deep_resolution_rate": deep_count / total
    }
```

---

## 8. Decision Logic

```python
def select_mapping_mode(
    mean_tau: float,
    std_tau: float,
    min_tau: float,
    compression: dict,
    bias: dict,
    resolution: dict,
    temp_interpretation: str
) -> str:
    """
    Returns: 'exponential' | 'linear' | 'unstable'
    Applied in strict priority order.
    """

    # Positional bias blocks any deployment — must fix prompt first
    if bias["positional_bias_detected"]:
        return "unstable"

    # Rank compression means resolution is too low for exponential
    if compression["compression_detected"]:
        return "linear"

    # Greedy degradation is an unexpected result requiring investigation
    if temp_interpretation == "greedy_degraded":
        return "unstable"

    # Full requirements for exponential mapping
    if (mean_tau >= 0.80 and
        std_tau <= 0.10 and
        min_tau >= 0.60):
        return "exponential"

    # Acceptable linear range
    if mean_tau >= 0.65:
        return "linear"

    # Below threshold — do not proceed
    return "unstable"
```

**Decision thresholds (locked — no mid-project reinterpretation):**

| Mean τ | Additional Conditions | Decision |
|---|---|---|
| ≥ 0.80 | std ≤ 0.10 AND min ≥ 0.60 AND no bias AND no greedy_degraded | `exponential` |
| 0.65–0.79 | No positional bias | `linear` |
| < 0.65 | Any | `unstable` — do not proceed |

---

## 9. Dual-Temperature Protocol

**Purpose:** Separate sampling variance from reasoning instability. These require different interventions. Without this test, you cannot determine the correct fix for low τ.

Run the full 20-iteration consistency test **twice** per objective type:

| Run Set | Temperature Config | Label |
|---|---|---|
| Set A | Role-assigned: optimizer 0.2, explorer 0.9, domain_expert 0.5, critic 0.5 | `production` |
| Set B | All agents at 0.0 (greedy decoding) | `greedy` |

```python
def interpret_temperature_delta(
    tau_production: float,
    tau_greedy: float
) -> dict:
    delta = tau_greedy - tau_production

    if delta > 0.15:
        interpretation = "sampling_dominated"
        action = (
            "Instability is primarily sampling variance. Reasoning is more "
            "stable than tau_production suggests. Consider reducing Explorer "
            "temperature slightly, or accept instability as intentional "
            "exploration noise. Safe to proceed using tau_production for "
            "mapping decision."
        )
    elif delta < -0.05:
        interpretation = "greedy_degraded"
        action = (
            "Greedy decoding produces LESS stable rankings than sampled "
            "decoding. Unusual result — investigate prompt for sensitivity "
            "to deterministic mode. May indicate prompt relies on generation "
            "diversity to resolve ambiguous criteria. Do not deploy until "
            "root cause is identified."
        )
    else:
        interpretation = "reasoning_dominated"
        action = (
            "tau gap is small. Instability is in the model's reasoning about "
            "the criteria, not in sampling randomness. Temperature reduction "
            "will not fix this. Prompt redesign is the correct intervention."
        )

    return {
        "tau_production": tau_production,
        "tau_greedy": tau_greedy,
        "delta": delta,
        "interpretation": interpretation,
        "recommended_action": action
    }
```

---

## 10. Frozen Hypothesis Sets

Each set is used identically across all 20 runs. Ambiguous pairs are required — without them, τ is artificially high and the test does not exercise the tiebreaker chain.

### Set A — Numeric Optimization
**Objective:** Minimize average API response latency under 99th-percentile SLA constraint

| ID | Description | Novelty | Delta Rank | Confidence | Feasibility | Transferability |
|---|---|---|---|---|---|---|
| H-A1 | Reduce connection pool size by 40% to lower contention | parameter | 2 | 0.82 | 0.90 | 0.85 |
| H-A2 | Replace synchronous retry logic with circuit breaker pattern | strategy | 1 | 0.75 | 0.80 | 0.90 |
| H-A3 | Switch from thread-per-request to async event loop architecture | mechanism | 1 | 0.60 | 0.55 | 0.80 |
| H-A4 | Add response caching layer with 5-minute TTL | strategy | 3 | 0.85 | 0.95 | 0.70 |
| H-A5 | Reduce logging verbosity in hot path | parameter | 4 | 0.90 | 0.98 | 0.75 |

**Deliberate ambiguity:** H-A1 and H-A4 have similar predicted impact (delta ranks 2 and 3) but different feasibility and transferability scores. This forces the model to use criteria 2 and 3. H-A2 and H-A3 both have delta rank 1 but differ on confidence, feasibility, and novelty — a three-way tiebreaker scenario.

**Critic flags:** H-A3 should be flagged for high implementation risk (architecture change). H-A4 should be flagged for cache invalidation complexity.

### Set B — Multi-Objective
**Objective:** Maximize throughput while minimizing infrastructure cost (weighted 0.6 / 0.4)

| ID | Description | Novelty | Delta Rank | Confidence | Feasibility | Transferability |
|---|---|---|---|---|---|---|
| H-B1 | Horizontal scaling with auto-scaling rules | strategy | 2 | 0.80 | 0.85 | 0.90 |
| H-B2 | Vertical scaling to larger instance type | parameter | 3 | 0.88 | 0.92 | 0.80 |
| H-B3 | Introduce request batching at ingress layer | mechanism | 1 | 0.65 | 0.60 | 0.75 |
| H-B4 | Spot instance migration for non-critical workloads | strategy | 2 | 0.70 | 0.65 | 0.70 |
| H-B5 | Reduce queue polling frequency by 50% | parameter | 4 | 0.92 | 0.95 | 0.65 |

**Deliberate ambiguity:** H-B1 and H-B4 have identical delta ranks (2) but different confidence and feasibility scores. This forces a feasibility tiebreak. H-B3 has the best delta rank but low confidence and feasibility, creating genuine tension between impact and risk.

**Critic flags:** H-B4 should be flagged for SLA risk on spot instances. H-B3 should be flagged for latency increase at ingress.

### Set C — Constraint-Heavy Satisfaction
**Objective:** Reduce manufacturing defect rate below 0.5% while maintaining output volume

| ID | Description | Novelty | Delta Rank | Confidence | Feasibility | Transferability |
|---|---|---|---|---|---|---|
| H-C1 | Increase QA inspection frequency from hourly to per-batch | parameter | 2 | 0.85 | 0.88 | 0.82 |
| H-C2 | Add in-line sensor array for real-time defect detection | mechanism | 1 | 0.60 | 0.50 | 0.85 |
| H-C3 | Recalibrate temperature tolerances in forming stage | parameter | 2 | 0.78 | 0.90 | 0.80 |
| H-C4 | Introduce statistical process control (SPC) monitoring | strategy | 1 | 0.72 | 0.75 | 0.90 |
| H-C5 | Reduce batch size by 20% to lower defect propagation | strategy | 3 | 0.82 | 0.85 | 0.75 |

**Deliberate ambiguity:** H-C1 and H-C3 both have delta rank 2 with similar confidence and feasibility — only transferability and novelty differ. This forces criteria 3 and 4. H-C2 and H-C4 both have delta rank 1 but differ substantially on confidence and feasibility.

**Critic flags:** H-C2 should be flagged for capital expenditure and integration risk. H-C5 should be flagged for potential volume constraint violation.

---

## 11. Database Schema

```sql
-- Phase 0 aggregate results per objective type
CREATE TABLE ranking_consistency_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  objective_type TEXT NOT NULL,
  objective_id UUID REFERENCES objectives(id),
  llm_model_version TEXT NOT NULL,
  prompt_template_hash TEXT NOT NULL,
  embedding_model_id UUID REFERENCES embedding_models(id),
  temperature_settings JSONB NOT NULL,
  run_count INT NOT NULL DEFAULT 20,

  -- Core τ metrics
  mean_tau FLOAT NOT NULL,
  std_tau FLOAT NOT NULL,
  min_tau FLOAT NOT NULL,

  -- Dual-temperature results
  tau_production_mean FLOAT,
  tau_greedy_mean FLOAT,
  temperature_delta_interpretation TEXT CHECK (
    temperature_delta_interpretation IN (
      'sampling_dominated', 'reasoning_dominated', 'greedy_degraded'
    )
  ),

  -- Compression and dominance
  rank_compression_detected BOOLEAN NOT NULL DEFAULT FALSE,
  rank_dominance_profile JSONB,

  -- Positional bias
  positional_bias_detected BOOLEAN NOT NULL DEFAULT FALSE,
  positional_bias_profile JSONB,

  -- Resolution depth
  mean_resolution_depth FLOAT,
  deep_resolution_rate FLOAT,

  -- Decision
  mapping_decision TEXT NOT NULL CHECK (
    mapping_decision IN ('exponential', 'linear', 'unstable')
  ),
  invalid_run_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Individual run outputs for full audit trail
CREATE TABLE ranking_run_outputs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  consistency_result_id UUID NOT NULL
    REFERENCES ranking_consistency_results(id),
  run_index INT NOT NULL,
  temperature_mode TEXT NOT NULL
    CHECK (temperature_mode IN ('production', 'greedy')),
  hypothesis_injection_order JSONB NOT NULL,
  raw_llm_output JSONB NOT NULL,
  validated BOOLEAN NOT NULL,
  canonical_ranking_vector JSONB NOT NULL,
  ranking_resolution_path JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_rco_objective ON ranking_consistency_results(objective_id);
CREATE INDEX idx_rro_result ON ranking_run_outputs(consistency_result_id);
```

---

## 12. Execution Checklist

**Before running:**
- [ ] Three objective types confirmed and documented
- [ ] Frozen hypothesis sets confirmed (Sets A, B, C from Section 10, or custom sets meeting design requirements)
- [ ] Ambiguous pairs verified in each set (≥2 per set)
- [ ] Mechanism-level hypothesis present in each set
- [ ] LLM model version recorded
- [ ] Prompt template hashed (SHA256) and stored
- [ ] Conversation state reset mechanism confirmed and tested
- [ ] Memory effects disabled and confirmed
- [ ] Shuffle seed strategy confirmed (`run_index` as seed)
- [ ] Production temperature settings locked per agent role
- [ ] Greedy (0.0) temperature configuration ready for Set B runs
- [ ] Output validation function deployed and tested on known-valid and known-invalid outputs

**After running:**
- [ ] τ computed for all three objective types (production and greedy)
- [ ] Temperature delta interpreted per objective type
- [ ] Positional bias Spearman ρ computed, threshold applied
- [ ] Rank compression and dominance profile computed
- [ ] Resolution depth distribution computed
- [ ] Invalid run count within threshold (< 3 per objective type)
- [ ] `mapping_decision` written to `ranking_consistency_results` for all three types
- [ ] Global mapping decision computed (most conservative across types)
- [ ] `ranking_mode` column written to `objectives` table configuration
- [ ] `ranking_consistency_report.json` exported and verified
- [ ] Phase 0 gate confirmed: proceed or halt

---

## 13. Output Report Schema

```json
{
  "report_version": "1.1",
  "executed_at": "ISO8601",
  "llm_model_version": "string",
  "prompt_template_hash": "string",
  "objectives_tested": [
    {
      "objective_type": "numeric_optimization | multi_objective | constraint_heavy",
      "mean_tau_production": "float",
      "mean_tau_greedy": "float",
      "std_tau": "float",
      "min_tau": "float",
      "temperature_delta_interpretation": "sampling_dominated | reasoning_dominated | greedy_degraded",
      "rank_compression_detected": "boolean",
      "positional_bias_detected": "boolean",
      "mean_resolution_depth": "float",
      "deep_resolution_rate": "float",
      "invalid_run_count": "int",
      "mapping_decision": "exponential | linear | unstable"
    }
  ],
  "global_mapping_decision": "exponential | linear | unstable",
  "proceed_to_implementation": "boolean",
  "blocking_issues": ["string"],
  "notes": "string"
}
```

`global_mapping_decision` is the most conservative individual decision across all three objective types. If any objective type returns `linear`, the global decision is `linear`. If any returns `unstable`, halt.

`blocking_issues` contains specific failure descriptions for any result that produced `unstable` or requires intervention (e.g., `"positional_bias_detected on constraint_heavy"`, `"greedy_degraded on all objective types"`).

---

## 14. Failure Response Protocol

| Failure Mode | Root Cause | Required Action Before Re-Run |
|---|---|---|
| τ < 0.65, `reasoning_dominated` | Prompt criteria are ambiguous or conflicting | Redesign priority chain; make tiebreaker criteria more specific |
| τ < 0.65, `sampling_dominated` | Explorer temperature too high for stable ranking | Reduce Explorer ranking temperature to 0.6–0.7; re-run |
| `positional_bias_detected` | Prompt has ordering sensitivity | Strengthen "read all before ranking" instruction; add explicit instruction to evaluate hypotheses independently of their order |
| `rank_compression_detected` | Hypothesis set too homogeneous OR model avoids extremes | If homogeneous set: redesign to include clearly dominant and clearly weak hypotheses; if model-induced: add explicit instruction that rank 1 and rank 5 must be used without hesitation |
| `deep_resolution_rate > 0.4` AND low τ | Hypothesis set too ambiguous — tiebreaker chain noise dominates | Redesign frozen hypothesis set with clearer quality differentiation between ambiguous pairs |
| `deep_resolution_rate > 0.4` AND acceptable τ | Expected — ambiguous set is working as intended | No action required |
| `greedy_degraded` | Prompt relies on sampling diversity to resolve criteria | Investigate root cause; prompt likely has underspecified criteria that benefit from token diversity; make criteria more explicit |
| `invalid_run_count ≥ 3` | JSON output unreliable | Add more explicit formatting instruction; reduce all temperatures for ranking calls; verify model supports JSON-only output mode |

**Do not proceed to CRL implementation if any objective type returns `unstable`.**  
Re-run after applying the indicated intervention. Log all re-run attempts with the prior τ scores and the specific change made.

---

*End of CRL Ranking Prompt Specification v1.1 Final.*  
*Companion document: CRL PRD v3.2 Final.*  
*This document is complete. No open decisions remain.*
