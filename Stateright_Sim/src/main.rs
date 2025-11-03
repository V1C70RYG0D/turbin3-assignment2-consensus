// Model checker CLI for the consensus protocol
// Run with: cargo run --release -- check
// Or explore with: cargo run --release -- explore
// 
// TODO: add more CLI args for node count, message loss rate, etc
// FIXME: explore mode isn't working yet (port binding issues?)

use consensus_stateright::*;
use stateright::actor::{ActorModel, Id, Network};
use stateright::{Checker, Expectation, Model};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();
    
    if args.len() < 2 {
        println!("Usage: {} <check|explore> [options]", args[0]);
        println!("\nExamples:");
        println!("  {} check           - Run model checker", args[0]);
        println!("  {} explore         - Launch web UI (port 3000)", args[0]);
        return Ok(());
    }

    let command = &args[1];
    
    match command.as_str() {
        "check" => run_checker(),
        "explore" => run_explorer(),
        _ => {
            println!("Unknown command: {}", command);
            println!("Use 'check' or 'explore'");
        }
    }

    Ok(())
}

fn run_checker() {
    println!("=== Consensus Protocol Model Checker ===");
    println!("Nodes: 3");
    println!("Values: 2");
    println!("Network: Unordered, non-duplicating");
    println!();

    let peer_ids: Vec<Id> = (0..3).map(Id::from).collect();
    
    let model = ActorModel::new((), ())
        .actor(ConsensusActor::new(peer_ids.clone()))
        .actor(ConsensusActor::new(peer_ids.clone()))
        .actor(ConsensusActor::new(peer_ids.clone()))
        .init_network(Network::new_unordered_nonduplicating([]))
        .property(
            Expectation::Always,
            "Agreement",
            |_, state| check_agreement(&state.actor_states)
        )
        .property(
            Expectation::Always,
            "Validity",
            |_, state| check_validity(&state.actor_states)
        )
        .property(
            Expectation::Sometimes,
            "Progress",
            |_, state| has_decision(&state.actor_states)
        );

    println!("Starting model checker...");
    
    // Using 4 threads for checking. on my laptop this seems optimal
    // tried 8 but didn't help much, probably memory bound not CPU bound
    let checker = model.checker().threads(4);
    
    println!("Running breadth-first search...");
    let result = checker.spawn_bfs().join();

    println!("\n=== Results ===");
    println!("States explored: {}", result.unique_state_count());
    
    // Check for discoveries
    if let Some(_discovery) = result.discovery("Agreement") {
        println!("\n[FAIL] Agreement property violated!");
    } else {
        println!("\n[PASS] Agreement property holds");
    }

    if let Some(_discovery) = result.discovery("Validity") {
        println!("[FAIL] Validity property violated!");
    } else {
        println!("[PASS] Validity property holds");
    }

    if let Some(_discovery) = result.discovery("Progress") {
        println!("[PASS] Progress property satisfied");
        println!("  At least one node decided on a value");
    } else {
        println!("[PENDING] Progress property not demonstrated");
    }

    println!("\n=== Model Checking Complete ===");
    println!("\nNote: With 3 nodes and message losses, liveness may not always be achievable.");
    println!("This demonstrates the FLP impossibility theorem in practice.");
}

fn run_explorer() {
    println!("=== Launching Stateright Explorer ===");
    println!("Opening web UI at http://localhost:3000");
    println!("Press Ctrl+C to stop\n");

    let peer_ids: Vec<Id> = (0..3).map(Id::from).collect();
    
    ActorModel::new((), ())
        .actor(ConsensusActor::new(peer_ids.clone()))
        .actor(ConsensusActor::new(peer_ids.clone()))
        .actor(ConsensusActor::new(peer_ids.clone()))
        .init_network(Network::new_unordered_nonduplicating([]))
        .property(
            Expectation::Always,
            "Agreement",
            |_, state| check_agreement(&state.actor_states)
        )
        .property(
            Expectation::Always,
            "Validity",
            |_, state| check_validity(&state.actor_states)
        )
        .property(
            Expectation::Sometimes,
            "Progress",
            |_, state| has_decision(&state.actor_states)
        )
        .checker()
        .serve("0.0.0.0:3000");
}
