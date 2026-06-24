use anyhow::{Context, Result};
use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::UnixStream;
use std::path::Path;
use std::thread;
use std::time::{Duration, Instant};

/// Minimal QMP client used only to negotiate capabilities and send a clean
/// shutdown command after the smoke-boot test completes.
pub struct QmpClient {
    reader: BufReader<UnixStream>,
    writer: UnixStream,
}

impl QmpClient {
    /// Polls `socket_path` until QEMU creates it, then performs the QMP
    /// handshake.  Returns an error if `timeout` elapses first.
    pub fn connect_with_retry(socket_path: &str, timeout: Duration) -> Result<Self> {
        let deadline = Instant::now() + timeout;

        loop {
            if Path::new(socket_path).exists() {
                match UnixStream::connect(socket_path) {
                    Ok(stream) => return Self::handshake(stream),
                    Err(_) => {}
                }
            }
            if Instant::now() >= deadline {
                anyhow::bail!("QMP socket not ready after {:?}", timeout);
            }
            thread::sleep(Duration::from_millis(200));
        }
    }

    fn handshake(stream: UnixStream) -> Result<Self> {
        let writer = stream.try_clone().context("clone QMP stream")?;
        let mut reader = BufReader::new(stream);

        // Consume the QMP greeting banner.
        let mut greeting = String::new();
        reader
            .read_line(&mut greeting)
            .context("read QMP greeting")?;

        let mut client = Self { reader, writer };

        // Negotiate capabilities (required before any other command).
        client
            .execute("qmp_capabilities")
            .context("qmp_capabilities")?;

        Ok(client)
    }

    fn execute(&mut self, command: &str) -> Result<String> {
        let msg = format!("{{\"execute\":\"{command}\"}}\n");
        self.writer
            .write_all(msg.as_bytes())
            .context("send QMP command")?;

        let mut response = String::new();
        self.reader
            .read_line(&mut response)
            .context("read QMP response")?;

        Ok(response)
    }

    /// Sends a graceful QEMU shutdown.  Consumes the client.
    pub fn quit(mut self) {
        let _ = self.execute("quit");
    }
}
