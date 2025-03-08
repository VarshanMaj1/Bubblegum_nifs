use solana_client::rpc_client::RpcClient;
use solana_sdk::{
    commitment_config::CommitmentConfig,
    signature::{Keypair, Signature},
    signer::Signer,
    transaction::Transaction,
    pubkey::Pubkey,
};
use crate::error::BubblegumError;
use tracing::{info, warn};

pub struct TransactionManager {
    client: RpcClient,
    simulation_enabled: bool,
    retry_config: RetryConfig,
}

#[derive(Debug, Clone)]
pub struct RetryConfig {
    pub max_attempts: u32,
    pub base_delay_ms: u64,
    pub max_delay_ms: u64,
}

impl Default for RetryConfig {
    fn default() -> Self {
        Self {
            max_attempts: 3,
            base_delay_ms: 1000,
            max_delay_ms: 10000,
        }
    }
}

impl TransactionManager {
    pub fn new(rpc_url: &str, commitment: CommitmentConfig) -> Self {
        Self {
            client: RpcClient::new_with_commitment(rpc_url.to_string(), commitment),
            simulation_enabled: true,
            retry_config: RetryConfig::default(),
        }
    }

    pub fn disable_simulation(&mut self) {
        self.simulation_enabled = false;
    }

    pub async fn simulate_and_send(
        &self,
        tx: &Transaction,
        signers: &[&Keypair],
    ) -> Result<Signature, BubblegumError> {
        if self.simulation_enabled {
            info!("Simulating transaction...");
            let simulation = self.client
                .simulate_transaction(tx)
                .map_err(|e| BubblegumError::RpcError(e.to_string()))?;

            if let Some(err) = simulation.value.err {
                return Err(BubblegumError::TransactionError(
                    format!("Simulation failed: {:?}", err)
                ));
            }

            // Log simulation results
            if let Some(logs) = simulation.value.logs {
                for log in logs {
                    info!("Simulation log: {}", log);
                }
            }
        }

        self.send_with_retry(tx, signers).await
    }

    async fn send_with_retry(
        &self,
        tx: &Transaction,
        signers: &[&Keypair],
    ) -> Result<Signature, BubblegumError> {
        let mut attempt = 0;
        let mut delay_ms = self.retry_config.base_delay_ms;

        loop {
            attempt += 1;
            match self.client.send_and_confirm_transaction_with_spinner(tx) {
                Ok(signature) => {
                    info!("Transaction successful: {}", signature);
                    return Ok(signature);
                }
                Err(err) => {
                    if attempt >= self.retry_config.max_attempts {
                        return Err(BubblegumError::TransactionError(
                            format!("Transaction failed after {} attempts: {}", attempt, err)
                        ));
                    }

                    warn!(
                        "Transaction attempt {} failed: {}. Retrying in {}ms...",
                        attempt, err, delay_ms
                    );

                    tokio::time::sleep(std::time::Duration::from_millis(delay_ms)).await;
                    delay_ms = (delay_ms * 2).min(self.retry_config.max_delay_ms);
                }
            }
        }
    }

    pub async fn mint_to_collection(
        &self,
        tree_authority: &Pubkey,
        leaf_owner: &Pubkey,
        leaf_delegate: &Pubkey,
        metadata: &MetadataArgs,
        collection_mint: &Pubkey,
        collection_authority: &Pubkey,
        payer: &Keypair,
    ) -> Result<Signature, BubblegumError> {
        let ix = mpl_bubblegum::instructions::mint_to_collection_v1(
            tree_authority,
            leaf_owner,
            leaf_delegate,
            collection_mint,
            collection_authority,
            payer.pubkey(),
            metadata,
        ).map_err(|e| BubblegumError::TransactionError(e.to_string()))?;

        let recent_blockhash = self.client
            .get_latest_blockhash()
            .map_err(|e| BubblegumError::RpcError(e.to_string()))?;

        let tx = Transaction::new_signed_with_payer(
            &[ix],
            Some(&payer.pubkey()),
            &[payer],
            recent_blockhash,
        );

        self.simulate_and_send(&tx, &[payer]).await
    }
} 