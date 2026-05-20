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
