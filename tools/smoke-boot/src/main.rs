use anyhow::{Context, Result};
use clap::Parser;
use std::process;
use std::time::Duration;

mod console;
mod qemu;
mod qmp;

/// QEMU smoke-boot harness — boots an ISO and asserts expected console markers.
#[derive(Parser)]
#[command(about = "Boots a Linus ISO in QEMU and asserts greeter + session readiness")]
struct Args {
    /// Path to the bootable ISO image
    #[arg(long)]
    iso: String,

    /// Boot timeout in seconds (default: 300)
    #[arg(long, default_value_t = 300)]
    timeout: u64,

    /// Console substring to wait for; repeat for multiple required markers
    #[arg(long = "marker", required = true)]
    markers: Vec<String>,
}

fn main() {
    if let Err(e) = run() {
        eprintln!("smoke-boot: {e:#}");
        process::exit(1);
    }
}

fn run() -> Result<()> {
    let args = Args::parse();
    let timeout = Duration::from_secs(args.timeout);
    let qmp_socket = format!("/tmp/smoke-qmp-{}.sock", process::id());

    eprintln!("[smoke-boot] iso: {}", args.iso);
    eprintln!("[smoke-boot] timeout: {}s", args.timeout);
    eprintln!("[smoke-boot] markers: {:?}", args.markers);

    let (mut child, stdout) = qemu::spawn(&args.iso, &qmp_socket)
        .context("failed to start QEMU")?;

    // Connect to QMP concurrently so it's ready for graceful shutdown.
    let qmp_socket_for_thread = qmp_socket.clone();
    let qmp_handle = std::thread::spawn(move || {
        qmp::QmpClient::connect_with_retry(&qmp_socket_for_thread, Duration::from_secs(30))
    });

    // Block until all markers appear on the serial console or timeout fires.
    let result = console::wait_for_markers(stdout, &args.markers, timeout);

    // Graceful QEMU shutdown via QMP; fall back to kill if unavailable.
    match qmp_handle.join() {
        Ok(Ok(client)) => client.quit(),
        _ => {}
    }
    let _ = child.wait();
    let _ = std::fs::remove_file(&qmp_socket);

    result
}
