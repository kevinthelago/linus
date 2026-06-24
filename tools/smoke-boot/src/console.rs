use anyhow::Result;
use std::collections::HashSet;
use std::io::{BufRead, BufReader};
use std::process::ChildStdout;
use std::sync::mpsc;
use std::thread;
use std::time::{Duration, Instant};

/// Reads QEMU serial console lines from `stdout` and waits until every string
/// in `markers` has appeared at least once.  Returns an error if the timeout
/// elapses before all markers are seen.
pub fn wait_for_markers(
    stdout: ChildStdout,
    markers: &[String],
    timeout: Duration,
) -> Result<()> {
    let (tx, rx) = mpsc::channel::<String>();

    // Offload blocking I/O to a dedicated thread so the main thread can apply
    // a wall-clock deadline without blocking forever on a stuck read.
    thread::spawn(move || {
        let reader = BufReader::new(stdout);
        for line in reader.lines() {
            match line {
                Ok(l) => {
                    if tx.send(l).is_err() {
                        break; // receiver dropped — timeout fired
                    }
                }
                Err(_) => break, // QEMU stdout closed
            }
        }
    });

    let deadline = Instant::now() + timeout;
    let mut remaining_markers: HashSet<&str> = markers.iter().map(String::as_str).collect();

    loop {
        let now = Instant::now();
        if now >= deadline {
            anyhow::bail!(
                "timeout after {}s — still waiting for: {:?}",
                timeout.as_secs(),
                remaining_markers
            );
        }

        let budget = deadline - now;
        match rx.recv_timeout(budget) {
            Ok(line) => {
                eprintln!("{line}");
                remaining_markers.retain(|marker| {
                    if line.contains(*marker) {
                        eprintln!("[smoke-boot] found marker: {marker}");
                        false // remove from set
                    } else {
                        true
                    }
                });
                if remaining_markers.is_empty() {
                    eprintln!("[smoke-boot] all markers found — boot verified");
                    return Ok(());
                }
            }
            Err(mpsc::RecvTimeoutError::Timeout) => {
                anyhow::bail!(
                    "timeout after {}s — still waiting for: {:?}",
                    timeout.as_secs(),
                    remaining_markers
                );
            }
            Err(mpsc::RecvTimeoutError::Disconnected) => {
                anyhow::bail!(
                    "QEMU exited unexpectedly — still waiting for: {:?}",
                    remaining_markers
                );
            }
        }
    }
}
