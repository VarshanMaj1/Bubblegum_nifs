use solana_program::{
    pubkey::Pubkey,
    program_pack::Pack,
};
use mpl_bubblegum::state::{metaplex_adapter::*, TreeConfig};
use anyhow::Result;

pub struct AccountDerivation;

impl AccountDerivation {
    pub fn derive_tree_authority(merkle_tree: &Pubkey) -> Result<(Pubkey, u8)> {
        let seeds = &[
            b"tree_authority",
            merkle_tree.as_ref(),
        ];
        Pubkey::find_program_address(seeds, &mpl_bubblegum::id())
            .map_err(|e| anyhow::anyhow!("Failed to derive tree authority: {}", e))
    }

    pub fn derive_voucher(
        tree_authority: &Pubkey,
        merkle_tree: &Pubkey,
        leaf_owner: &Pubkey,
        root: &[u8],
        data_hash: &[u8],
        creator_hash: &[u8],
        nonce: u64,
        index: u32,
    ) -> Result<(Pubkey, u8)> {
        let seeds = &[
            b"voucher",
            tree_authority.as_ref(),
            merkle_tree.as_ref(),
            leaf_owner.as_ref(),
            root,
            data_hash,
            creator_hash,
            &nonce.to_le_bytes(),
            &index.to_le_bytes(),
        ];
        Pubkey::find_program_address(seeds, &mpl_bubblegum::id())
            .map_err(|e| anyhow::anyhow!("Failed to derive voucher: {}", e))
    }

    pub fn derive_collection_metadata(mint: &Pubkey) -> Result<(Pubkey, u8)> {
        let seeds = &[
            b"metadata",
            mpl_token_metadata::id().as_ref(),
            mint.as_ref(),
        ];
        Pubkey::find_program_address(seeds, &mpl_token_metadata::id())
            .map_err(|e| anyhow::anyhow!("Failed to derive collection metadata: {}", e))
    }

    pub fn derive_collection_edition(mint: &Pubkey) -> Result<(Pubkey, u8)> {
        let seeds = &[
            b"metadata",
            mpl_token_metadata::id().as_ref(),
            mint.as_ref(),
            b"edition",
        ];
        Pubkey::find_program_address(seeds, &mpl_token_metadata::id())
            .map_err(|e| anyhow::anyhow!("Failed to derive collection edition: {}", e))
    }

    pub fn derive_tree_config(merkle_tree: &Pubkey) -> Result<TreeConfig> {
        let (authority, _) = Self::derive_tree_authority(merkle_tree)?;
        let config = TreeConfig {
            authority,
            merkle_tree: *merkle_tree,
            creator_hash: [0; 32],
            data_hash: [0; 32],
            root: [0; 32],
            num_minted: 0,
        };
        Ok(config)
    }

    pub fn derive_collection_delegate_record(
        collection_mint: &Pubkey,
        collection_authority: &Pubkey,
    ) -> Result<(Pubkey, u8)> {
        let seeds = &[
            b"metadata",
            mpl_token_metadata::id().as_ref(),
            collection_mint.as_ref(),
            b"collection_authority",
            collection_authority.as_ref(),
        ];
        Pubkey::find_program_address(seeds, &mpl_token_metadata::id())
            .map_err(|e| anyhow::anyhow!("Failed to derive collection delegate record: {}", e))
    }
} 