---------------------------- MODULE ConsensusSystem ----------------------------
(*
  A simplified Byzantine Fault-Tolerant Consensus Protocol
  Based on PBFT principles with 3-5 nodes
  
  This specification models a distributed consensus system where:
  - Nodes propose values and attempt to reach agreement
  - Messages can be lost or delayed (asynchronous network)
  - Some nodes may crash (fail-stop model)
  
  Safety: No two nodes decide on different values
  Liveness: All non-faulty nodes eventually decide
*)

EXTENDS Naturals, FiniteSets, Sequences, TLC

CONSTANTS 
    Nodes,          \* Set of all node IDs
    Values,         \* Set of possible values to agree on
    MaxFailures,    \* Maximum number of failures tolerated (f < n/3 for Byzantine)
    NULL            \* Represents no value (model value)

VARIABLES
    nodeState,      \* nodeState[n] = state of node n: "follower", "candidate", "leader", "decided"
    nodeValue,      \* nodeValue[n] = proposed/decided value for node n
    nodeVotes,      \* nodeVotes[n] = set of votes received by node n
    messages,       \* messages in transit (set of message records)
    decided,        \* decided[n] = TRUE if node n has decided
    faulty          \* faulty[n] = TRUE if node n is faulty/crashed

vars == <<nodeState, nodeValue, nodeVotes, messages, decided, faulty>>

-----------------------------------------------------------------------------

(* Message types *)
Message == [type: {"Propose", "Vote", "Commit"}, 
            src: Nodes, 
            dst: Nodes, 
            value: Values \cup {NULL},
            term: Nat]

(* Type invariant *)
TypeOK == 
    /\ nodeState \in [Nodes -> {"follower", "candidate", "leader", "decided"}]
    /\ nodeValue \in [Nodes -> Values \cup {NULL}]
    /\ nodeVotes \in [Nodes -> SUBSET Nodes]
    /\ messages \subseteq Message
    /\ decided \in [Nodes -> BOOLEAN]
    /\ faulty \in [Nodes -> BOOLEAN]

-----------------------------------------------------------------------------

(* Initial state *)
Init ==
    /\ nodeState = [n \in Nodes |-> "follower"]
    /\ nodeValue = [n \in Nodes |-> NULL]
    /\ nodeVotes = [n \in Nodes |-> {}]
    /\ messages = {}
    /\ decided = [n \in Nodes |-> FALSE]
    /\ faulty = [n \in Nodes |-> FALSE]

(* Helper: Count non-faulty nodes *)
NonFaultyNodes == {n \in Nodes : ~faulty[n]}

(* Helper: Quorum size (2f+1 for BFT) *)
QuorumSize == (Cardinality(Nodes) \div 2) + 1

(* Helper: Is this a valid quorum? *)
IsQuorum(S) == Cardinality(S) >= QuorumSize

-----------------------------------------------------------------------------

(* Actions *)

(* A node proposes a value and becomes a candidate *)
Propose(n) ==
    /\ ~faulty[n]
    /\ nodeState[n] = "follower"
    /\ nodeValue[n] = NULL
    /\ \E v \in Values:
        /\ nodeValue' = [nodeValue EXCEPT ![n] = v]
        /\ nodeState' = [nodeState EXCEPT ![n] = "candidate"]
        /\ messages' = messages \cup 
            {[type |-> "Propose", src |-> n, dst |-> m, value |-> v, term |-> 0] : m \in Nodes \ {n}}
    /\ UNCHANGED <<nodeVotes, decided, faulty>>

(* A node receives a proposal and votes *)
ReceiveProposal(m) ==
    /\ m \in messages
    /\ m.type = "Propose"
    /\ ~faulty[m.dst]
    /\ nodeState[m.dst] \in {"follower", "candidate"}
    /\ nodeValue[m.dst] = NULL \/ nodeValue[m.dst] = m.value
    /\ nodeValue' = [nodeValue EXCEPT ![m.dst] = m.value]
    /\ messages' = (messages \ {m}) \cup 
        {[type |-> "Vote", src |-> m.dst, dst |-> m.src, value |-> m.value, term |-> 0]}
    /\ UNCHANGED <<nodeState, nodeVotes, decided, faulty>>

(* A node collects votes *)
CollectVote(m) ==
    /\ m \in messages
    /\ m.type = "Vote"
    /\ ~faulty[m.dst]
    /\ nodeState[m.dst] = "candidate"
    /\ m.value = nodeValue[m.dst]
    /\ nodeVotes' = [nodeVotes EXCEPT ![m.dst] = @ \cup {m.src}]
    /\ messages' = messages \ {m}
    /\ IF IsQuorum(nodeVotes'[m.dst])
       THEN 
           /\ nodeState' = [nodeState EXCEPT ![m.dst] = "leader"]
           /\ messages' = (messages \ {m}) \cup 
               {[type |-> "Commit", src |-> m.dst, dst |-> n, value |-> nodeValue[m.dst], term |-> 0] : n \in Nodes \ {m.dst}}
       ELSE 
           /\ nodeState' = nodeState
    /\ UNCHANGED <<nodeValue, decided, faulty>>

(* A node receives commit and decides *)
ReceiveCommit(m) ==
    /\ m \in messages
    /\ m.type = "Commit"
    /\ ~faulty[m.dst]
    /\ ~decided[m.dst]
    /\ nodeValue' = [nodeValue EXCEPT ![m.dst] = m.value]
    /\ decided' = [decided EXCEPT ![m.dst] = TRUE]
    /\ nodeState' = [nodeState EXCEPT ![m.dst] = "decided"]
    /\ messages' = messages \ {m}
    /\ UNCHANGED <<nodeVotes, faulty>>

(* Message loss (network unreliability) *)
LoseMessage ==
    /\ messages # {}
    /\ \E m \in messages:
        /\ messages' = messages \ {m}
        /\ UNCHANGED <<nodeState, nodeValue, nodeVotes, decided, faulty>>

(* Node crash failure *)
NodeCrash ==
    /\ Cardinality({n \in Nodes : faulty[n]}) < MaxFailures
    /\ \E n \in Nodes:
        /\ ~faulty[n]
        /\ faulty' = [faulty EXCEPT ![n] = TRUE]
        /\ UNCHANGED <<nodeState, nodeValue, nodeVotes, messages, decided>>

-----------------------------------------------------------------------------

(* Next state transition *)
Next ==
    \/ \E n \in Nodes: Propose(n)
    \/ \E m \in messages: ReceiveProposal(m)
    \/ \E m \in messages: CollectVote(m)
    \/ \E m \in messages: ReceiveCommit(m)
    \/ LoseMessage
    \/ NodeCrash

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------

(* Safety Properties *)

(* Agreement: No two non-faulty nodes decide on different values *)
Agreement == 
    \A n1, n2 \in Nodes:
        (decided[n1] /\ decided[n2] /\ ~faulty[n1] /\ ~faulty[n2]) =>
            nodeValue[n1] = nodeValue[n2]

(* Validity: If a node decides, it must be a valid value *)
Validity ==
    \A n \in Nodes:
        decided[n] => nodeValue[n] \in Values

(* Integrity: A node decides at most once *)
Integrity ==
    \A n \in Nodes:
        decided[n] => nodeState[n] = "decided"

(* Non-triviality: It's possible for nodes to decide *)
CanDecide ==
    \E n \in Nodes: decided[n]

-----------------------------------------------------------------------------

(* Liveness Properties *)

(* Eventual Decision: All non-faulty nodes eventually decide *)
(* This is a temporal property that may not hold in all scenarios *)
EventualDecision ==
    <>(\A n \in NonFaultyNodes: decided[n])

(* Progress: If enough nodes are non-faulty, someone eventually becomes leader *)
EventualLeader ==
    Cardinality(NonFaultyNodes) >= QuorumSize =>
        <>(\E n \in NonFaultyNodes: nodeState[n] = "leader")

-----------------------------------------------------------------------------

(* Invariants to check *)
Inv == TypeOK /\ Agreement /\ Validity /\ Integrity

=============================================================================
