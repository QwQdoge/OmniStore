use notify_rust::Notification;

pub fn send_notification(summary: &str, body: &str) {
    if let Err(e) = Notification::new()
        .summary(summary)
        .body(body)
        .appname("OmniStore")
        .timeout(5000)
        .show()
    {
        eprintln!("[Daemon] Failed to trigger notification: {}", e);
    }
}
