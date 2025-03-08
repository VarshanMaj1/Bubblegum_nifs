use rustler::{Encoder, Env, Error, NifResult, Term, NifStruct};
use solana_sdk::{
    pubkey::Pubkey,
    signature::{Keypair, Signature},
    transaction::Transaction,
    signer::Signer,
    commitment_config::CommitmentConfig,
};
use solana_client::rpc_client::RpcClient;
use mpl_bubblegum::{
    instructions as bubblegum_ix,
    state::{metaplex_adapter::MetadataArgs, TreeConfig, Creator},
};
use anyhow::Result;
use thiserror::Error;
use std::{str::FromStr, sync::Arc};
use serde::{Serialize, Deserialize};
use tokio::sync::Mutex;
use log::{info, error, warn};
use bs58;

// Global state management
lazy_static::lazy_static! {
    static ref SOLANA_CLIENT: Arc<Mutex<Option<RpcClient>>> = Arc::new(Mutex::new(None));
    static ref CURRENT_KEYPAIR: Arc<Mutex<Option<Keypair>>> = Arc::new(Mutex::new(None));
}

#[derive(Error, Debug)]
pub enum BubblegumError {
    #[error("Invalid public key: {0}")]
    InvalidPublicKey(String),
    #[error("Transaction error: {0}")]
    TransactionError(String),
    #[error("RPC error: {0}")]
    RpcError(String),
    #[error("Keypair error: {0}")]
    KeypairError(String),
    #[error("Configuration error: {0}")]
    ConfigError(String),
    #[error("Network error: {0}")]
    NetworkError(String),
    #[error("Metadata error: {0}")]
    MetadataError(String),
    #[error("Decoding error: {0}")]
    DecodingError(String),
    #[error("Instruction error: {0}")]
    InstructionError(String),
}

#[derive(NifStruct)]
#[module = "BubblegumNif.Config"]
pub struct Config {
    pub network: String,
    pub rpc_url: String,
    pub commitment: String,
}

#[derive(NifStruct, Serialize, Deserialize)]
#[module = "BubblegumNif.Creator"]
pub struct NifCreator {
    pub address: String,
    pub verified: bool,
    pub share: u8,
}

#[derive(NifStruct, Serialize, Deserialize)]
#[module = "BubblegumNif.MetadataArgs"]
pub struct NifMetadataArgs {
    pub name: String,
    pub symbol: String,
    pub uri: String,
    pub creators: Vec<NifCreator>,
    pub seller_fee_basis_points: u16,
    pub primary_sale_happened: bool,
    pub is_mutable: bool,
    pub collection: Option<String>,
}

fn decode_pubkey(encoded: &str) -> Result<Pubkey, BubblegumError> {
    Pubkey::from_str(encoded).map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))
}

fn get_client() -> Result<RpcClient, BubblegumError> {
    let client = SOLANA_CLIENT.try_lock()
        .map_err(|e| BubblegumError::ConfigError(format!("Failed to acquire client lock: {}", e)))?
        .clone();
    
    client.ok_or_else(|| BubblegumError::ConfigError("Solana client not initialized".to_string()))
}

#[rustler::nif]
fn initialize_client(config: Config) -> NifResult<(Term, Term)> {
    let commitment = CommitmentConfig::from_str(&config.commitment)
        .map_err(|e| Error::Term(Box::new(format!("Invalid commitment: {}", e))))?;

    let client = RpcClient::new_with_commitment(config.rpc_url, commitment);

    let mut client_lock = SOLANA_CLIENT.try_lock()
        .map_err(|e| Error::Term(Box::new(format!("Failed to acquire lock: {}", e))))?;
    *client_lock = Some(client);

    Ok((atoms::ok(), "Client initialized successfully".encode(env)))
}

#[rustler::nif]
fn load_keypair(keypair_json: String) -> NifResult<(Term, Term)> {
    let keypair_bytes = serde_json::from_str::<Vec<u8>>(&keypair_json)
        .map_err(|e| Error::Term(Box::new(format!("Invalid keypair JSON: {}", e))))?;

    let keypair = Keypair::from_bytes(&keypair_bytes)
        .map_err(|e| Error::Term(Box::new(format!("Invalid keypair bytes: {}", e))))?;

    let mut keypair_lock = CURRENT_KEYPAIR.try_lock()
        .map_err(|e| Error::Term(Box::new(format!("Failed to acquire lock: {}", e))))?;
    *keypair_lock = Some(keypair);

    Ok((atoms::ok(), "Keypair loaded successfully".encode(env)))
}

#[rustler::nif]
fn create_tree_config(
    max_depth: u32,
    max_buffer_size: u32,
    public_key: String,
    canopy_depth: Option<u32>,
) -> NifResult<(Term, Term)> {
    let authority = match decode_pubkey(&public_key) {
        Ok(key) => key,
        Err(e) => return Ok((atoms::error(), e.to_string().encode(env))),
    };

    let tree_config = TreeConfig {
        max_depth,
        max_buffer_size,
        authority,
        canopy_depth: canopy_depth.unwrap_or(0),
    };

    let client = match get_client() {
        Ok(client) => client,
        Err(e) => return Ok((atoms::error(), e.to_string().encode(env))),
    };

    let keypair = match CURRENT_KEYPAIR.try_lock() {
        Ok(lock) => match &*lock {
            Some(kp) => kp.clone(),
            None => return Ok((atoms::error(), "No keypair loaded".encode(env))),
        },
        Err(e) => return Ok((atoms::error(), format!("Failed to acquire keypair lock: {}", e).encode(env))),
    };

    let ix = match bubblegum_ix::create_tree(
        &tree_config,
        &authority,
    ) {
        Ok(ix) => ix,
        Err(e) => return Ok((atoms::error(), e.to_string().encode(env))),
    };

    let recent_blockhash = match client.get_latest_blockhash() {
        Ok(hash) => hash,
        Err(e) => return Ok((atoms::error(), format!("Failed to get blockhash: {}", e).encode(env))),
    };

    let tx = Transaction::new_signed_with_payer(
        &[ix],
        Some(&authority),
        &[&keypair],
        recent_blockhash,
    );

    info!("Sending create_tree transaction...");
    match client.send_and_confirm_transaction_with_spinner(&tx) {
        Ok(signature) => {
            info!("Tree created successfully: {}", signature);
            Ok((atoms::ok(), signature.to_string().encode(env)))
        },
        Err(e) => {
            error!("Failed to create tree: {}", e);
            Ok((atoms::error(), format!("Transaction failed: {}", e).encode(env)))
        }
    }
}

#[rustler::nif]
fn mint_v1(
    tree_authority: String,
    leaf_owner: String,
    leaf_delegate: String,
    metadata: NifMetadataArgs,
) -> NifResult<(Term, Term)> {
    let tree_auth = match decode_pubkey(&tree_authority) {
        Ok(key) => key,
        Err(e) => return Ok((atoms::error(), e.to_string().encode(env))),
    };

    let owner = match decode_pubkey(&leaf_owner) {
        Ok(key) => key,
        Err(e) => return Ok((atoms::error(), e.to_string().encode(env))),
    };

    let delegate = match decode_pubkey(&leaf_delegate) {
        Ok(key) => key,
        Err(e) => return Ok((atoms::error(), e.to_string().encode(env))),
    };

    let collection_key = match metadata.collection {
        Some(key) => Some(match decode_pubkey(&key) {
            Ok(key) => key,
            Err(e) => return Ok((atoms::error(), e.to_string().encode(env))),
        }),
        None => None,
    };

    let creators: Vec<Creator> = metadata.creators.iter()
        .map(|c| Creator {
            address: match decode_pubkey(&c.address) {
                Ok(key) => key,
                Err(_) => return Ok((atoms::error(), format!("Invalid creator address: {}", c.address).encode(env))),
            },
            verified: c.verified,
            share: c.share,
        })
        .collect();

    let metadata_args = MetadataArgs {
        name: metadata.name,
        symbol: metadata.symbol,
        uri: metadata.uri,
        creators,
        collection: collection_key,
        seller_fee_basis_points: metadata.seller_fee_basis_points,
        primary_sale_happened: metadata.primary_sale_happened,
        is_mutable: metadata.is_mutable,
        ..Default::default()
    };

    let client = match get_client() {
        Ok(client) => client,
        Err(e) => return Ok((atoms::error(), e.to_string().encode(env))),
    };

    let keypair = match CURRENT_KEYPAIR.try_lock() {
        Ok(lock) => match &*lock {
            Some(kp) => kp.clone(),
            None => return Ok((atoms::error(), "No keypair loaded".encode(env))),
        },
        Err(e) => return Ok((atoms::error(), format!("Failed to acquire keypair lock: {}", e).encode(env))),
    };

    let ix = match bubblegum_ix::mint_v1(
        &tree_auth,
        &owner,
        &delegate,
        &metadata_args,
    ) {
        Ok(ix) => ix,
        Err(e) => return Ok((atoms::error(), e.to_string().encode(env))),
    };

    let recent_blockhash = match client.get_latest_blockhash() {
        Ok(hash) => hash,
        Err(e) => return Ok((atoms::error(), format!("Failed to get blockhash: {}", e).encode(env))),
    };

    let tx = Transaction::new_signed_with_payer(
        &[ix],
        Some(&owner),
        &[&keypair],
        recent_blockhash,
    );

    info!("Sending mint transaction...");
    match client.send_and_confirm_transaction_with_spinner(&tx) {
        Ok(signature) => {
            info!("NFT minted successfully: {}", signature);
            Ok((atoms::ok(), signature.to_string().encode(env)))
        },
        Err(e) => {
            error!("Failed to mint NFT: {}", e);
            Ok((atoms::error(), format!("Transaction failed: {}", e).encode(env)))
        }
    }
}

#[rustler::nif]
fn transfer(
    tree_authority: String,
    leaf_owner: String,
    new_leaf_owner: String,
    merkle_tree: String,
    root: Vec<u8>,
    data_hash: Vec<u8>,
    creator_hash: Vec<u8>,
    nonce: u64,
    index: u32,
) -> NifResult<(Term, Term)> {
    let tree_auth = match decode_pubkey(&tree_authority) {
        Ok(key) => key,
        Err(e) => return Ok((atoms::error(), e.to_string().encode(env))),
    };

    let owner = match decode_pubkey(&leaf_owner) {
        Ok(key) => key,
        Err(e) => return Ok((atoms::error(), e.to_string().encode(env))),
    };

    let new_owner = match decode_pubkey(&new_leaf_owner) {
        Ok(key) => key,
        Err(e) => return Ok((atoms::error(), e.to_string().encode(env))),
    };

    let tree = match decode_pubkey(&merkle_tree) {
        Ok(key) => key,
        Err(e) => return Ok((atoms::error(), e.to_string().encode(env))),
    };

    let client = match get_client() {
        Ok(client) => client,
        Err(e) => return Ok((atoms::error(), e.to_string().encode(env))),
    };

    let keypair = match CURRENT_KEYPAIR.try_lock() {
        Ok(lock) => match &*lock {
            Some(kp) => kp.clone(),
            None => return Ok((atoms::error(), "No keypair loaded".encode(env))),
        },
        Err(e) => return Ok((atoms::error(), format!("Failed to acquire keypair lock: {}", e).encode(env))),
    };

    let ix = match bubblegum_ix::transfer(
        &tree_auth,
        &owner,
        &new_owner,
        &tree,
        root.as_slice(),
        data_hash.as_slice(),
        creator_hash.as_slice(),
        nonce,
        index,
    ) {
        Ok(ix) => ix,
        Err(e) => return Ok((atoms::error(), e.to_string().encode(env))),
    };

    let recent_blockhash = match client.get_latest_blockhash() {
        Ok(hash) => hash,
        Err(e) => return Ok((atoms::error(), format!("Failed to get blockhash: {}", e).encode(env))),
    };

    let tx = Transaction::new_signed_with_payer(
        &[ix],
        Some(&owner),
        &[&keypair],
        recent_blockhash,
    );

    info!("Sending transfer transaction...");
    match client.send_and_confirm_transaction_with_spinner(&tx) {
        Ok(signature) => {
            info!("NFT transferred successfully: {}", signature);
            Ok((atoms::ok(), signature.to_string().encode(env)))
        },
        Err(e) => {
            error!("Failed to transfer NFT: {}", e);
            Ok((atoms::error(), format!("Transaction failed: {}", e).encode(env)))
        }
    }
}

#[rustler::nif]
fn request_airdrop(public_key: String, amount_sol: f64) -> NifResult<(Term, Term)> {
    let pubkey = match decode_pubkey(&public_key) {
        Ok(key) => key,
        Err(e) => return Ok((atoms::error(), e.to_string().encode(env))),
    };

    let client = match get_client() {
        Ok(client) => client,
        Err(e) => return Ok((atoms::error(), e.to_string().encode(env))),
    };

    let amount_lamports = (amount_sol * 1_000_000_000.0) as u64;
    
    info!("Requesting airdrop of {} SOL...", amount_sol);
    match client.request_airdrop(&pubkey, amount_lamports) {
        Ok(signature) => {
            match client.confirm_transaction(&signature) {
                Ok(_) => {
                    info!("Airdrop successful: {}", signature);
                    Ok((atoms::ok(), signature.to_string().encode(env)))
                },
                Err(e) => {
                    error!("Failed to confirm airdrop: {}", e);
                    Ok((atoms::error(), format!("Failed to confirm airdrop: {}", e).encode(env)))
                }
            }
        },
        Err(e) => {
            error!("Airdrop request failed: {}", e);
            Ok((atoms::error(), format!("Airdrop request failed: {}", e).encode(env)))
        }
    }
}

#[rustler::nif]
pub fn decompress_v1(
    tree_authority: String,
    leaf_owner: String,
    leaf_delegate: String,
    merkle_tree: String,
    root: String,
    data_hash: String,
    creator_hash: String,
    nonce: u64,
    index: u32,
) -> Result<String, BubblegumError> {
    let tree_authority = Pubkey::from_str(&tree_authority)
        .map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))?;
    let leaf_owner = Pubkey::from_str(&leaf_owner)
        .map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))?;
    let leaf_delegate = Pubkey::from_str(&leaf_delegate)
        .map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))?;
    let merkle_tree = Pubkey::from_str(&merkle_tree)
        .map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))?;
    
    let root = bs58::decode(root)
        .into_vec()
        .map_err(|e| BubblegumError::DecodingError(e.to_string()))?;
    let data_hash = bs58::decode(data_hash)
        .into_vec()
        .map_err(|e| BubblegumError::DecodingError(e.to_string()))?;
    let creator_hash = bs58::decode(creator_hash)
        .into_vec()
        .map_err(|e| BubblegumError::DecodingError(e.to_string()))?;

    let ix = mpl_bubblegum::instructions::decompress_v1(
        &tree_authority,
        &leaf_owner,
        &leaf_delegate,
        &merkle_tree,
        root.as_slice(),
        data_hash.as_slice(),
        creator_hash.as_slice(),
        nonce,
        index,
    ).map_err(|e| BubblegumError::InstructionError(e.to_string()))?;

    process_instruction(ix)
}

#[rustler::nif]
pub fn delegate(
    tree_authority: String,
    leaf_owner: String,
    previous_leaf_delegate: String,
    new_leaf_delegate: String,
    merkle_tree: String,
    root: String,
    data_hash: String,
    creator_hash: String,
    nonce: u64,
    index: u32,
) -> Result<String, BubblegumError> {
    let tree_authority = Pubkey::from_str(&tree_authority)
        .map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))?;
    let leaf_owner = Pubkey::from_str(&leaf_owner)
        .map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))?;
    let previous_leaf_delegate = Pubkey::from_str(&previous_leaf_delegate)
        .map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))?;
    let new_leaf_delegate = Pubkey::from_str(&new_leaf_delegate)
        .map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))?;
    let merkle_tree = Pubkey::from_str(&merkle_tree)
        .map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))?;
    
    let root = bs58::decode(root)
        .into_vec()
        .map_err(|e| BubblegumError::DecodingError(e.to_string()))?;
    let data_hash = bs58::decode(data_hash)
        .into_vec()
        .map_err(|e| BubblegumError::DecodingError(e.to_string()))?;
    let creator_hash = bs58::decode(creator_hash)
        .into_vec()
        .map_err(|e| BubblegumError::DecodingError(e.to_string()))?;

    let ix = mpl_bubblegum::instructions::delegate(
        &tree_authority,
        &leaf_owner,
        &previous_leaf_delegate,
        &new_leaf_delegate,
        &merkle_tree,
        root.as_slice(),
        data_hash.as_slice(),
        creator_hash.as_slice(),
        nonce,
        index,
    ).map_err(|e| BubblegumError::InstructionError(e.to_string()))?;

    process_instruction(ix)
}

#[rustler::nif]
pub fn redeem(
    tree_authority: String,
    leaf_owner: String,
    leaf_delegate: String,
    merkle_tree: String,
    root: String,
    data_hash: String,
    creator_hash: String,
    nonce: u64,
    index: u32,
) -> Result<String, BubblegumError> {
    let tree_authority = Pubkey::from_str(&tree_authority)
        .map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))?;
    let leaf_owner = Pubkey::from_str(&leaf_owner)
        .map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))?;
    let leaf_delegate = Pubkey::from_str(&leaf_delegate)
        .map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))?;
    let merkle_tree = Pubkey::from_str(&merkle_tree)
        .map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))?;
    
    let root = bs58::decode(root)
        .into_vec()
        .map_err(|e| BubblegumError::DecodingError(e.to_string()))?;
    let data_hash = bs58::decode(data_hash)
        .into_vec()
        .map_err(|e| BubblegumError::DecodingError(e.to_string()))?;
    let creator_hash = bs58::decode(creator_hash)
        .into_vec()
        .map_err(|e| BubblegumError::DecodingError(e.to_string()))?;

    let ix = mpl_bubblegum::instructions::redeem(
        &tree_authority,
        &leaf_owner,
        &leaf_delegate,
        &merkle_tree,
        root.as_slice(),
        data_hash.as_slice(),
        creator_hash.as_slice(),
        nonce,
        index,
    ).map_err(|e| BubblegumError::InstructionError(e.to_string()))?;

    process_instruction(ix)
}

#[rustler::nif]
pub fn cancel_redeem(
    tree_authority: String,
    leaf_owner: String,
    merkle_tree: String,
    root: String,
    data_hash: String,
    creator_hash: String,
    nonce: u64,
    index: u32,
) -> Result<String, BubblegumError> {
    let tree_authority = Pubkey::from_str(&tree_authority)
        .map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))?;
    let leaf_owner = Pubkey::from_str(&leaf_owner)
        .map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))?;
    let merkle_tree = Pubkey::from_str(&merkle_tree)
        .map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))?;
    
    let root = bs58::decode(root)
        .into_vec()
        .map_err(|e| BubblegumError::DecodingError(e.to_string()))?;
    let data_hash = bs58::decode(data_hash)
        .into_vec()
        .map_err(|e| BubblegumError::DecodingError(e.to_string()))?;
    let creator_hash = bs58::decode(creator_hash)
        .into_vec()
        .map_err(|e| BubblegumError::DecodingError(e.to_string()))?;

    let ix = mpl_bubblegum::instructions::cancel_redeem(
        &tree_authority,
        &leaf_owner,
        &merkle_tree,
        root.as_slice(),
        data_hash.as_slice(),
        creator_hash.as_slice(),
        nonce,
        index,
    ).map_err(|e| BubblegumError::InstructionError(e.to_string()))?;

    process_instruction(ix)
}

#[rustler::nif]
pub fn compress(
    tree_authority: String,
    leaf_owner: String,
    leaf_delegate: String,
    merkle_tree: String,
    token_account: String,
    mint: String,
) -> Result<String, BubblegumError> {
    let tree_authority = Pubkey::from_str(&tree_authority)
        .map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))?;
    let leaf_owner = Pubkey::from_str(&leaf_owner)
        .map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))?;
    let leaf_delegate = Pubkey::from_str(&leaf_delegate)
        .map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))?;
    let merkle_tree = Pubkey::from_str(&merkle_tree)
        .map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))?;
    let token_account = Pubkey::from_str(&token_account)
        .map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))?;
    let mint = Pubkey::from_str(&mint)
        .map_err(|e| BubblegumError::InvalidPublicKey(e.to_string()))?;

    let ix = mpl_bubblegum::instructions::compress_nft(
        &tree_authority,
        &leaf_owner,
        &leaf_delegate,
        &merkle_tree,
        &token_account,
        &mint,
    ).map_err(|e| BubblegumError::InstructionError(e.to_string()))?;

    process_instruction(ix)
}

mod atoms {
    rustler::atoms! {
        ok,
        error
    }
}

rustler::init!("Elixir.BubblegumNif", [
    initialize_client,
    load_keypair,
    create_tree_config,
    mint_v1,
    transfer,
    request_airdrop,
    decompress_v1,
    delegate,
    redeem,
    cancel_redeem,
    compress
]);
