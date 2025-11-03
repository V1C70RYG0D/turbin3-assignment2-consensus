# TLA+ Specification Design Document

## Overview

This document explains the key design choices and assumptions made in the ConsensusSystem.tla specification.

## Protocol Design

### Core Concept
I implemented a simplified Byzantine Fault-Tolerant (BFT) consensus protocol inspired by PBFT (Practical Byzantine Fault Tolerance), adapted for educational clarity while maintaining correctness guarantees.

### Key Design Choices

**1. State Machine Architecture**
- **Node States**: follower → candidate → leader → decided
- Nodes start as followers, propose values to become candidates, achieve quorum to become leaders, and broadcast commits to trigger decisions
- This progression mirrors Raft's elegance while incorporating BFT quorum requirements

**2. Three-Phase Protocol**
- **Phase 1 (Propose)**: Candidate broadcasts proposal to all nodes
- **Phase 2 (Vote)**: Nodes vote if they accept the proposal
- **Phase 3 (Commit)**: Leader broadcasts commit after achieving quorum

This simplification from PBFT's view-change mechanism makes the protocol more tractable for model checking while preserving core safety properties.

**3. Quorum Size**
- QuorumSize = ⌊n/2⌋ + 1 (majority quorum)
- For Byzantine tolerance with f failures: requires 3f+1 nodes
- With 3 nodes: tolerates 0 Byzantine failures, 1 crash failure
- Trade-off: simpler quorums vs. full Byzantine resilience

### Assumptions

**Network Model**
- Asynchronous: messages can be arbitrarily delayed
- Messages can be lost (via LoseMessage action)
- No message duplication in this model (can be extended)
- Point-to-point communication between nodes

**Failure Model**
- Crash failures: nodes can stop permanently (NodeCrash action)
- MaxFailures constraint limits simultaneous failures
- No Byzantine (malicious) behavior in initial model
- Failed nodes never recover (fail-stop model)

**System Assumptions**
- Finite set of nodes known a priori
- Values are predetermined (no dynamic value generation)
- Single consensus instance (no multi-paxos style log)
- Nodes have unique identifiers

### Safety vs. Liveness Trade-offs

**Safety Guarantees (Always Enforced)**
- **Agreement**: No two non-faulty nodes decide different values
- **Validity**: Decided values must be from the valid set
- **Integrity**: Nodes decide at most once

**Liveness Properties (Best-Effort)**
- **EventualDecision**: All non-faulty nodes eventually decide
- **EventualLeader**: Eventually some node becomes leader
- These may not hold under adversarial message loss or excessive failures (FLP impossibility)

### Simplifications from Full PBFT

1. **No View Changes**: Omitted leader replacement mechanism for state space reduction
2. **Single Consensus Round**: No sequence numbers or multi-decree support
3. **Simplified Crypto**: No digital signatures or MAC authentication
4. **No Checkpointing**: Single-shot consensus vs. replicated state machine
5. **Homogeneous Nodes**: All nodes have equal weight (no stake-based voting)

### Verification Strategy

The specification is designed for TLC model checking with:
- **Small constants**: 3 nodes, 2 values keeps state space manageable
- **Symmetry reduction**: Node and value permutations are equivalent
- **Invariant checking**: Focus on safety (Agreement, Validity, Integrity)
- **Temporal properties**: CanDecide ensures non-triviality

### Expected Behaviors

**Normal Case**
1. Node proposes value → becomes candidate
2. Others vote → candidate collects quorum
3. Candidate becomes leader → broadcasts commit
4. All nodes receive commit → decide

**Failure Scenarios**
- Message loss: May prevent quorum formation, liveness impact
- Node crash: Reduces quorum availability if too many fail
- Concurrent proposals: Multiple candidates, potential for no progress

### Extensions for Future Work

1. Add Byzantine behavior modeling (malicious votes)
2. Implement view-change for leader fault tolerance
3. Model network partitions explicitly
4. Add fairness constraints to ensure liveness
5. Support multi-shot consensus (replicated log)

## Conclusion

This specification prioritizes **clarity and verifiability** over full Byzantine resilience. The simplified protocol captures essential consensus properties while remaining tractable for formal verification. The design makes the trade-off explicit: we sacrifice some practical features (view changes, full BFT) to gain deeper understanding of core consensus mechanics through model checking.
