use anyhow::{Context, Result};
use std::process::{Child, ChildStdout, Command, Stdio};

pub struct QemuChild {
    child: Child,
}

impl QemuChild {
    pub fn wait(&mut self) {
        let _ = self.child.wait();
    }

    fn kill_inner(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

impl Drop for QemuChild {
    fn drop(&mut self) {
        self.kill_inner();
    }
}

/// Spawns QEMU with the ISO attached, serial console on stdout, and a QMP socket.
/// Returns the child process handle and its stdout (serial console).
pub fn spawn(iso: &str, qmp_socket: &str) -> Result<(QemuChild, ChildStdout)> {
    let mut args: Vec<String> = vec![
        "-cdrom".into(), iso.into(),
        "-m".into(), "2048".into(),
        "-smp".into(), "2".into(),
        "-display".into(), "none".into(),
        "-serial".into(), "stdio".into(),
        "-no-reboot".into(),
        "-boot".into(), "d".into(),
    ];

    // KVM accelerates the boot dramatically; fall back to TCG when unavailable.
    if std::path::Path::new("/dev/kvm").exists() {
        args.push("-enable-kvm".into());
        args.push("-cpu".into());
        args.push("host".into());
    }

    args.push("-qmp".into());
    args.push(format!("unix:{qmp_socket},server,nowait"));

    let mut child = Command::new("qemu-system-x86_64")
        .args(&args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .context("failed to spawn qemu-system-x86_64 — is it installed?")?;

    let stdout = child
        .stdout
        .take()
        .context("failed to capture QEMU stdout")?;

    Ok((QemuChild { child }, stdout))
}
