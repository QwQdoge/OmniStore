#[cfg(not(test))]
use notify_rust::Notification;

#[cfg(test)]
use std::sync::Mutex;

#[cfg(test)]
pub static NOTIFICATIONS: Mutex<Vec<(String, String)>> = Mutex::new(Vec::new());

// We need a lock to prevent concurrent tests from conflicting over NOTIFICATIONS state.
#[cfg(test)]
pub static TEST_MUTEX: Mutex<()> = Mutex::new(());

pub fn send_notification(summary: &str, body: &str) {
    #[cfg(not(test))]
    {
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

    #[cfg(test)]
    {
        let mut notifications = NOTIFICATIONS.lock().unwrap();
        notifications.push((summary.to_string(), body.to_string()));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_send_notification() {
        let _guard = TEST_MUTEX.lock().unwrap();
        NOTIFICATIONS.lock().unwrap().clear();

        send_notification("Test Summary", "Test Body");

        let notifications = NOTIFICATIONS.lock().unwrap();
        assert_eq!(notifications.len(), 1);
        assert_eq!(notifications[0].0, "Test Summary");
        assert_eq!(notifications[0].1, "Test Body");
    }

    #[test]
    fn test_multiple_notifications() {
        let _guard = TEST_MUTEX.lock().unwrap();
        NOTIFICATIONS.lock().unwrap().clear();

        send_notification("Summary 1", "Body 1");
        send_notification("Summary 2", "Body 2");

        let notifications = NOTIFICATIONS.lock().unwrap();
        assert_eq!(notifications.len(), 2);
        assert_eq!(notifications[1].0, "Summary 2");
        assert_eq!(notifications[1].1, "Body 2");
    }
}
