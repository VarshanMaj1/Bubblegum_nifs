use std::{
    collections::VecDeque,
    sync::Arc,
    time::{Duration, Instant},
};
use tokio::sync::Mutex;

#[derive(Debug)]
pub struct RateLimiter {
    window_size: Duration,
    max_requests: usize,
    requests: VecDeque<Instant>,
}

impl RateLimiter {
    pub fn new(window_size: Duration, max_requests: usize) -> Self {
        Self {
            window_size,
            max_requests,
            requests: VecDeque::with_capacity(max_requests),
        }
    }

    pub fn check_rate_limit(&mut self) -> bool {
        let now = Instant::now();
        
        // Remove old requests
        while let Some(request_time) = self.requests.front() {
            if now.duration_since(*request_time) > self.window_size {
                self.requests.pop_front();
            } else {
                break;
            }
        }

        // Check if we can make a new request
        if self.requests.len() < self.max_requests {
            self.requests.push_back(now);
            true
        } else {
            false
        }
    }
}

#[derive(Debug)]
pub struct RetryConfig {
    pub max_retries: u32,
    pub base_delay: Duration,
    pub max_delay: Duration,
}

impl Default for RetryConfig {
    fn default() -> Self {
        Self {
            max_retries: 3,
            base_delay: Duration::from_millis(1000),
            max_delay: Duration::from_secs(10),
        }
    }
}

pub async fn with_retry<F, Fut, T, E>(
    operation: F,
    config: RetryConfig,
) -> Result<T, E>
where
    F: Fn() -> Fut,
    Fut: std::future::Future<Output = Result<T, E>>,
    E: std::fmt::Debug,
{
    let mut retries = 0;
    let mut delay = config.base_delay;

    loop {
        match operation().await {
            Ok(value) => return Ok(value),
            Err(error) => {
                if retries >= config.max_retries {
                    return Err(error);
                }

                log::warn!(
                    "Operation failed with error: {:?}. Retrying in {:?}...",
                    error,
                    delay
                );

                tokio::time::sleep(delay).await;
                delay = std::cmp::min(delay * 2, config.max_delay);
                retries += 1;
            }
        }
    }
} 