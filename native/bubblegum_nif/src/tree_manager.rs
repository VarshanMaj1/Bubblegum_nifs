use crate::merkle::MerkleTree;
use async_trait::async_trait;
use dashmap::DashMap;
use solana_sdk::pubkey::Pubkey;
use std::{sync::Arc, path::PathBuf};
use tokio::sync::Mutex;
use tracing::{info, error};

#[async_trait]
pub trait TreeStorage: Send + Sync {
    async fn load_tree(&self, authority: &Pubkey) -> anyhow::Result<Option<MerkleTree>>;
    async fn save_tree(&self, authority: &Pubkey, tree: &MerkleTree) -> anyhow::Result<()>;
    async fn delete_tree(&self, authority: &Pubkey) -> anyhow::Result<()>;
}

#[cfg(feature = "persistent-storage")]
pub struct RocksDBStorage {
    db: Arc<rocksdb::DB>,
}

#[cfg(feature = "persistent-storage")]
impl RocksDBStorage {
    pub fn new(path: PathBuf) -> anyhow::Result<Self> {
        let db = rocksdb::DB::open_default(path)?;
        Ok(Self { db: Arc::new(db) })
    }
}

#[cfg(feature = "persistent-storage")]
#[async_trait]
impl TreeStorage for RocksDBStorage {
    async fn load_tree(&self, authority: &Pubkey) -> anyhow::Result<Option<MerkleTree>> {
        let key = authority.to_bytes();
        Ok(self.db.get(&key)?
            .map(|bytes| bincode::deserialize(&bytes))
            .transpose()?)
    }

    async fn save_tree(&self, authority: &Pubkey, tree: &MerkleTree) -> anyhow::Result<()> {
        let key = authority.to_bytes();
        let value = bincode::serialize(tree)?;
        Ok(self.db.put(&key, value)?)
    }

    async fn delete_tree(&self, authority: &Pubkey) -> anyhow::Result<()> {
        let key = authority.to_bytes();
        Ok(self.db.delete(&key)?)
    }
}

pub struct TreeManager {
    trees: DashMap<Pubkey, Arc<Mutex<MerkleTree>>>,
    storage: Arc<dyn TreeStorage>,
}

impl TreeManager {
    pub fn new(storage: Arc<dyn TreeStorage>) -> Self {
        Self {
            trees: DashMap::new(),
            storage,
        }
    }

    pub async fn get_or_create_tree(
        &self,
        authority: &Pubkey,
        max_depth: u32,
    ) -> anyhow::Result<Arc<Mutex<MerkleTree>>> {
        if let Some(tree) = self.trees.get(authority) {
            return Ok(tree.value().clone());
        }

        let tree = if let Some(stored_tree) = self.storage.load_tree(authority).await? {
            info!("Loaded existing tree for authority: {}", authority);
            stored_tree
        } else {
            info!("Creating new tree for authority: {}", authority);
            MerkleTree::new(max_depth)
        };

        let tree = Arc::new(Mutex::new(tree));
        self.trees.insert(*authority, tree.clone());
        Ok(tree)
    }

    pub async fn save_tree_state(
        &self,
        authority: &Pubkey,
    ) -> anyhow::Result<()> {
        if let Some(tree) = self.trees.get(authority) {
            let tree = tree.value().lock().await;
            self.storage.save_tree(authority, &tree).await?;
            info!("Saved tree state for authority: {}", authority);
        }
        Ok(())
    }

    pub async fn insert_leaf(
        &self,
        authority: &Pubkey,
        leaf_data: &[u8],
    ) -> anyhow::Result<(u32, Vec<u8>)> {
        let tree = self.get_or_create_tree(authority, 14).await?;
        let mut tree = tree.lock().await;
        
        let index = tree.insert(leaf_data)?;
        let root = tree.get_root();
        
        // Save state after modification
        drop(tree); // Release lock before saving
        self.save_tree_state(authority).await?;
        
        Ok((index, root))
    }

    pub async fn verify_leaf(
        &self,
        authority: &Pubkey,
        leaf_hash: &[u8],
        index: u32,
    ) -> anyhow::Result<bool> {
        let tree = self.get_or_create_tree(authority, 14).await?;
        let tree = tree.lock().await;
        
        let proof = tree.get_proof(index)?;
        let root = tree.get_root();
        
        Ok(MerkleTree::verify_proof(&root, leaf_hash, &proof, index))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[tokio::test]
    async fn test_tree_manager() -> anyhow::Result<()> {
        let temp_dir = tempdir()?;
        let storage = Arc::new(RocksDBStorage::new(temp_dir.path().to_path_buf())?);
        let manager = TreeManager::new(storage);

        let authority = Pubkey::new_unique();
        let leaf_data = b"test leaf";

        // Insert leaf and verify
        let (index, root) = manager.insert_leaf(&authority, leaf_data).await?;
        assert!(manager.verify_leaf(&authority, &root, index).await?);

        // Test persistence
        let leaf_hash = solana_program::keccak::hash(leaf_data).to_bytes();
        assert!(manager.verify_leaf(&authority, &leaf_hash, index).await?);

        Ok(())
    }
} 