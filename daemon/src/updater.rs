use std::fs;
use std::path::PathBuf;
use std::process::Command;
use chrono::Utc;
use serde::{Deserialize, Serialize};
use crate::config::AppConfig;
use crate::notifier::send_notification;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct UpdateItem {
    pub name: String,
    pub source: String,
    pub current_version: String,
    pub new_version: String,
    pub description: Option<String>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct UpdateStatus {
    pub last_checked: String,
    pub updates_count: usize,
    pub updates: Vec<UpdateItem>,
}

fn get_python_paths() -> (PathBuf, PathBuf) {
    // Find python project root relative to daemon directory
    // In our directory layout, project root is /Users/29mingyue.chen/projects/OmniStore
    // Python backend is at /Users/29mingyue.chen/projects/OmniStore/python
    let home = std::env::var("HOME").unwrap_or_else(|_| "".to_string());
    let default_root = PathBuf::from(home).join("projects/OmniStore/python");
    
    let working_dir = if default_root.exists() {
        default_root
    } else {
        // Fallback to current directory logic
        let current = std::env::current_dir().unwrap_or_default();
        if current.join("python").exists() {
            current.join("python")
        } else if current.ends_with("daemon") {
            current.parent().unwrap().join("python")
        } else {
            current
        }
    };

    let python_bin = working_dir.join(".venv/bin/python");
    let python_bin = if python_bin.exists() {
        python_bin
    } else {
        PathBuf::from("python") // Fallback to system python
    };

    (python_bin, working_dir)
}

pub fn get_status_path() -> PathBuf {
    let mut path = dirs::home_dir().unwrap_or_else(|| PathBuf::from("/"));
    path.push(".config");
    path.push("omnistore");
    path.push("update_status.json");
    path
}

pub async fn run_update_check(config: &AppConfig) {
    println!("[Daemon] Running update check...");
    let (python_bin, working_dir) = get_python_paths();
    let script_path = working_dir.join("main.py");

    if !script_path.exists() {
        eprintln!("[Daemon] Python script not found at {:?}", script_path);
        return;
    }

    // Execute python main.py -C --json
    let output = Command::new(&python_bin)
        .arg(&script_path)
        .arg("-C")
        .arg("--json")
        .current_dir(&working_dir)
        .output();

    match output {
        Ok(out) => {
            if out.status.success() {
                let stdout_str = String::from_utf8_lossy(&out.stdout).to_string();
                match serde_json::from_str::<Vec<UpdateItem>>(&stdout_str.trim()) {
                    Ok(updates) => {
                        let count = updates.len();
                        println!("[Daemon] Found {} updates", count);

                        let status = UpdateStatus {
                            last_checked: Utc::now().to_rfc3339(),
                            updates_count: count,
                            updates: updates.clone(),
                        };

                        // Write to update_status.json
                        let status_path = get_status_path();
                        if let Some(parent) = status_path.parent() {
                            let _ = fs::create_dir_all(parent);
                        }
                        if let Ok(json_str) = serde_json::to_string_pretty(&status) {
                            let _ = fs::write(&status_path, json_str);
                        }

                        // Trigger notifications
                        if count > 0 && config.daemon.notifications {
                            let msg = format!("您有 {} 个可用的软件更新项目，点击进入商店查看并更新。", count);
                            send_notification("OmniStore 软件更新提示", &msg);
                        }

                        // Run auto-updates if enabled
                        if config.daemon.auto_update && count > 0 {
                            run_auto_updates(&updates).await;
                        }
                    }
                    Err(e) => {
                        eprintln!("[Daemon] Failed to parse JSON output: {}", e);
                    }
                }
            } else {
                let stderr = String::from_utf8_lossy(&out.stderr);
                eprintln!("[Daemon] Python check updates process failed: {}", stderr);
            }
        }
        Err(e) => {
            eprintln!("[Daemon] Failed to execute python script: {}", e);
        }
    }
}

pub async fn run_auto_updates(updates: &[UpdateItem]) {
    println!("[Daemon] Auto-update is enabled. Starting updates...");
    
    // Flatpaks are safe to update in user space without prompts
    let has_flatpaks = updates.iter().any(|u| u.source == "Flatpak");
    if has_flatpaks {
        println!("[Daemon] Auto-updating Flatpak applications...");
        let _ = Command::new("flatpak")
            .args(["update", "-y", "--user"])
            .status();
    }

    // Native packages require sudo, if daemon runs as root it can update pacman,
    // otherwise it won't be able to without UI askpass.
    // For safety, we only auto-update user space Flatpak or AppImage, or native if run as root
    let is_root = unsafe { libc::getuid() == 0 };
    if is_root {
        let has_natives = updates.iter().any(|u| u.source == "Native" || u.source == "AUR");
        if has_natives {
            println!("[Daemon] Running as root. Auto-updating native packages...");
            let _ = Command::new("pacman")
                .args(["-Syu", "--noconfirm"])
                .status();
        }
    } else {
        println!("[Daemon] Daemon is not running as root. Skipping native pacman/aur auto-updates.");
    }
}

mod dirs {
    use std::path::PathBuf;
    pub fn home_dir() -> Option<PathBuf> {
        std::env::var_os("HOME").map(PathBuf::from)
    }
}

// Bind libc for getuid checking on Unix
mod libc {
    extern "C" {
        pub fn getuid() -> u32;
    }
}
