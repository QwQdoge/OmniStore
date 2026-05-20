mod config;
mod notifier;
mod updater;

use std::time::Duration;
use tokio::time;

#[tokio::main]
async fn main() {
    println!("====================================================");
    println!("       OmniStore Background Daemon Starting         ");
    println!("====================================================");

    let config = config::load_config();
    if !config.daemon.enabled {
        println!("[Daemon] Daemon is disabled in configuration. Exiting.");
        return;
    }

    println!("[Daemon] Running initial update check...");
    updater::run_update_check(&config).await;

    let interval_hours = config.daemon.check_interval_hours;
    println!(
        "[Daemon] Starting background loop. Checking every {} hour(s).",
        interval_hours
    );

    let mut interval = time::interval(Duration::from_secs(interval_hours * 3600));
    
    // The first tick of tokio::time::interval fires immediately, so skip it to avoid double-run
    interval.tick().await;

    loop {
        tokio::select! {
            _ = interval.tick() => {
                // Reload configuration in case it changed
                let current_config = config::load_config();
                if !current_config.daemon.enabled {
                    println!("[Daemon] Daemon was disabled in configuration. Stopping.");
                    break;
                }
                updater::run_update_check(&current_config).await;
            }
            _ = tokio::signal::ctrl_c() => {
                println!("[Daemon] Received shutdown signal. Exiting.");
                break;
            }
        }
    }
}
