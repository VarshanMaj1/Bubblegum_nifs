use solana_program::keccak;
use std::collections::HashMap;

#[derive(Debug)]
pub struct MerkleTree {
    pub max_depth: u32,
    pub nodes: HashMap<Vec<u8>, Vec<u8>>,
    pub leaves: Vec<Vec<u8>>,
}

impl MerkleTree {
    pub fn new(max_depth: u32) -> Self {
        Self {
            max_depth,
            nodes: HashMap::new(),
            leaves: Vec::new(),
        }
    }

    pub fn insert(&mut self, leaf_data: &[u8]) -> Result<u32, &'static str> {
        if self.leaves.len() >= (1 << self.max_depth) {
            return Err("Tree is full");
        }

        let leaf_hash = keccak::hash(leaf_data).to_bytes().to_vec();
        self.leaves.push(leaf_hash.clone());
        self.nodes.insert(leaf_hash, leaf_data.to_vec());

        Ok((self.leaves.len() - 1) as u32)
    }

    pub fn get_proof(&self, index: u32) -> Result<Vec<Vec<u8>>, &'static str> {
        if index as usize >= self.leaves.len() {
            return Err("Index out of bounds");
        }

        let mut proof = Vec::new();
        let mut current_index = index;
        let mut current_hash = self.leaves[index as usize].clone();

        for level in 0..self.max_depth {
            let sibling_index = if current_index % 2 == 0 {
                current_index + 1
            } else {
                current_index - 1
            };

            if sibling_index as usize < self.leaves.len() {
                proof.push(self.leaves[sibling_index as usize].clone());
            } else {
                proof.push(vec![0; 32]); // Empty node
            }

            current_index /= 2;
            current_hash = if current_index % 2 == 0 {
                keccak::hash(&[&current_hash[..], &proof[level as usize][..]].concat()).to_bytes().to_vec()
            } else {
                keccak::hash(&[&proof[level as usize][..], &current_hash[..]].concat()).to_bytes().to_vec()
            };
        }

        Ok(proof)
    }

    pub fn verify_proof(
        root: &[u8],
        leaf_hash: &[u8],
        proof: &[Vec<u8>],
        index: u32,
    ) -> bool {
        let mut current_hash = leaf_hash.to_vec();
        let mut current_index = index;

        for sibling in proof {
            current_hash = if current_index % 2 == 0 {
                keccak::hash(&[&current_hash[..], &sibling[..]].concat()).to_bytes().to_vec()
            } else {
                keccak::hash(&[&sibling[..], &current_hash[..]].concat()).to_bytes().to_vec()
            };
            current_index /= 2;
        }

        current_hash == root
    }

    pub fn get_root(&self) -> Vec<u8> {
        if self.leaves.is_empty() {
            return vec![0; 32];
        }

        let mut current_level = self.leaves.clone();
        while current_level.len() > 1 {
            let mut next_level = Vec::new();
            for chunk in current_level.chunks(2) {
                if chunk.len() == 2 {
                    let combined = keccak::hash(&[&chunk[0][..], &chunk[1][..]].concat()).to_bytes().to_vec();
                    next_level.push(combined);
                } else {
                    next_level.push(chunk[0].clone());
                }
            }
            current_level = next_level;
        }

        current_level[0].clone()
    }
} 