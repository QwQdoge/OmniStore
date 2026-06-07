use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

#[derive(Default, Debug, Serialize, Deserialize, Clone)]
pub struct DaemonConfig {
    #[serde(default = "default_enabled")]
    pub enabled: bool,
    #[serde(default = "default_check_interval")]
    pub check_interval_hours: u64,
    #[serde(default = "default_auto_update")]
    pub auto_update: bool,
    #[serde(default = "default_notifications")]
    pub notifications: bool,
}

fn default_enabled() -> bool { true }
fn default_check_interval() -> u64 { 4 }
fn default_auto_update() -> bool { false }
fn default_notifications() -> bool { true }

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AppConfig {
    #[serde(default)]
    pub daemon: DaemonConfig,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            daemon: DaemonConfig {
                enabled: true,
                check_interval_hours: 4,
                auto_update: false,
                notifications: true,
            },
        }
    }
}

pub fn get_config_path() -> PathBuf {
    let mut path = dirs::home_dir().unwrap_or_else(|| PathBuf::from("/"));
    path.push(".config");
    path.push("omnistore");
    path.push("config.yaml");
    path
}

pub fn load_config() -> AppConfig {
    let path = get_config_path();
    if !path.exists() {
        return AppConfig::default();
    }

    match fs::read_to_string(&path) {
        Ok(content) => match serde_yaml::from_str::<AppConfig>(&content) {
            Ok(cfg) => cfg,
            Err(e) => {
                eprintln!("[Daemon] YAML parse error: {}, falling back to defaults", e);
                AppConfig::default()
            }
        },
        Err(e) => {
            eprintln!("[Daemon] Read config error: {}, falling back to defaults", e);
            AppConfig::default()
        }
    }
}

// Minimal dirs implementation to avoid adding extra crate dependency
mod dirs {
    use std::path::PathBuf;
    pub fn home_dir() -> Option<PathBuf> {
        std::env::var_os("HOME").map(PathBuf::from)
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    use std::env;
    use std::fs;
    use std::sync::Mutex;

    static ENV_LOCK: Mutex<()> = Mutex::new(());

    struct EnvGuard {
        original_home: Option<std::ffi::OsString>,
    }

    impl EnvGuard {
        fn new() -> Self {
            Self {
                original_home: env::var_os("HOME"),
            }
        }
    }

    impl Drop for EnvGuard {
        fn drop(&mut self) {
            match &self.original_home {
                Some(val) => env::set_var("HOME", val),
                None => env::remove_var("HOME"),
            }
        }
    }

    fn setup_test_home(test_name: &str) -> PathBuf {
        let mut path = env::temp_dir();
        path.push(format!("omnistore_test_{}", test_name));
        let _ = fs::remove_dir_all(&path);
        fs::create_dir_all(&path).unwrap();
        path
    }

    #[test]
    fn test_load_config_missing_file() {
        let _guard = ENV_LOCK.lock().unwrap();
        let _env_guard = EnvGuard::new();
        let home = setup_test_home("missing");
        env::set_var("HOME", &home);

        let config = load_config();
        assert_eq!(config.daemon.enabled, true); // default
        assert_eq!(config.daemon.check_interval_hours, 4); // default
    }

    #[test]
    fn test_load_config_valid_yaml() {
        let _guard = ENV_LOCK.lock().unwrap();
        let _env_guard = EnvGuard::new();
        let home = setup_test_home("valid");
        env::set_var("HOME", &home);

        let config_dir = home.join(".config").join("omnistore");
        fs::create_dir_all(&config_dir).unwrap();
        let config_path = config_dir.join("config.yaml");

        fs::write(&config_path, "
daemon:
  enabled: false
  check_interval_hours: 12
  auto_update: true
  notifications: false
").unwrap();

        let config = load_config();
        assert_eq!(config.daemon.enabled, false);
        assert_eq!(config.daemon.check_interval_hours, 12);
        assert_eq!(config.daemon.auto_update, true);
        assert_eq!(config.daemon.notifications, false);
    }

    #[test]
    fn test_load_config_invalid_yaml() {
        let _guard = ENV_LOCK.lock().unwrap();
        let _env_guard = EnvGuard::new();
        let home = setup_test_home("invalid");
        env::set_var("HOME", &home);

        let config_dir = home.join(".config").join("omnistore");
        fs::create_dir_all(&config_dir).unwrap();
        let config_path = config_dir.join("config.yaml");

        fs::write(&config_path, "invalid_yaml: { [").unwrap();

        let config = load_config();
        // Should fall back to default
        assert_eq!(config.daemon.enabled, true);
        assert_eq!(config.daemon.check_interval_hours, 4);
    }
}
