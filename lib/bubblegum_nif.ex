defmodule BubblegumNif do
  @moduledoc """
  Native Implemented Functions (NIFs) for Metaplex Bubblegum compressed NFTs on Solana.

  This module provides functions to interact with the Solana blockchain for creating,
  minting, and transferring compressed NFTs using the mpl-bubblegum crate.

  ## Configuration

  Before using any of the functions, you need to initialize the client with proper configuration:

      config = %BubblegumNif.Types.Config{
        network: "devnet",
        rpc_url: "https://api.devnet.solana.com",
        commitment: "confirmed"
      }
      BubblegumNif.initialize_client(config)

  ## Keypair Management

  You also need to load your Solana keypair:

      {:ok, _} = BubblegumNif.load_keypair(File.read!("~/.config/solana/id.json"))

  ## Examples

      # Create a new tree configuration
      {:ok, signature} = BubblegumNif.create_tree_config(
        14,                # max_depth
        64,               # max_buffer_size
        "YOUR_PUBLIC_KEY", # authority public key
        nil                # optional canopy depth
      )

      # Mint a new compressed NFT
      metadata = %BubblegumNif.Types.MetadataArgs{
        name: "My NFT",
        symbol: "MNFT",
        uri: "https://arweave.net/xxx",
        creators: [
          %BubblegumNif.Types.Creator{
            address: "YOUR_CREATOR_ADDRESS",
            verified: true,
            share: 100
          }
        ],
        seller_fee_basis_points: 500,
        primary_sale_happened: false,
        is_mutable: true
      }

      {:ok, signature} = BubblegumNif.mint_v1(
        "TREE_AUTHORITY",
        "LEAF_OWNER",
        "LEAF_DELEGATE",
        metadata
      )
  """

  use Rustler, otp_app: :bubblegum_nif, crate: :bubblegum_nif
  alias BubblegumNif.Types.{Config, MetadataArgs}

  @doc """
  Initializes the Solana client with the given configuration.

  ## Parameters

  * `config` - A `BubblegumNif.Types.Config` struct containing:
    * `network` - The Solana network to connect to (e.g., "devnet", "mainnet-beta")
    * `rpc_url` - The RPC endpoint URL
    * `commitment` - The commitment level (e.g., "processed", "confirmed", "finalized")

  ## Returns

  * `{:ok, message}` on success
  * `{:error, reason}` on failure
  """
  @spec initialize_client(Config.t()) :: {:ok, String.t()} | {:error, String.t()}
  def initialize_client(_config), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Loads a Solana keypair from its JSON representation.

  ## Parameters

  * `keypair_json` - The JSON string containing the keypair data

  ## Returns

  * `{:ok, message}` on success
  * `{:error, reason}` on failure
  """
  @spec load_keypair(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def load_keypair(_keypair_json), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Creates a new compressed NFT tree configuration.

  ## Parameters

  * `max_depth` - Maximum depth of the merkle tree
  * `max_buffer_size` - Maximum buffer size for the tree
  * `public_key` - Base58 encoded public key of the tree authority
  * `canopy_depth` - Optional depth of the canopy

  ## Returns

  * `{:ok, signature}` on success
  * `{:error, reason}` on failure
  """
  @spec create_tree_config(
    max_depth :: non_neg_integer(),
    max_buffer_size :: non_neg_integer(),
    public_key :: String.t(),
    canopy_depth :: non_neg_integer() | nil
  ) :: {:ok, String.t()} | {:error, String.t()}
  def create_tree_config(_max_depth, _max_buffer_size, _public_key, _canopy_depth),
    do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Mints a new compressed NFT.

  ## Parameters

  * `tree_authority` - Base58 encoded public key of the tree authority
  * `leaf_owner` - Base58 encoded public key of the leaf owner
  * `leaf_delegate` - Base58 encoded public key of the leaf delegate
  * `metadata` - A `BubblegumNif.Types.MetadataArgs` struct containing the NFT metadata

  ## Returns

  * `{:ok, signature}` on success
  * `{:error, reason}` on failure
  """
  @spec mint_v1(
    tree_authority :: String.t(),
    leaf_owner :: String.t(),
    leaf_delegate :: String.t(),
    metadata :: MetadataArgs.t()
  ) :: {:ok, String.t()} | {:error, String.t()}
  def mint_v1(_tree_authority, _leaf_owner, _leaf_delegate, _metadata),
    do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Transfers a compressed NFT to a new owner.

  ## Parameters

  * `tree_authority` - Base58 encoded public key of the tree authority
  * `leaf_owner` - Base58 encoded public key of the current leaf owner
  * `new_leaf_owner` - Base58 encoded public key of the new leaf owner
  * `merkle_tree` - Base58 encoded public key of the merkle tree
  * `root` - Current root hash of the merkle tree
  * `data_hash` - Hash of the NFT data
  * `creator_hash` - Hash of the NFT creator
  * `nonce` - Nonce of the leaf
  * `index` - Index of the leaf in the tree

  ## Returns

  * `{:ok, signature}` on success
  * `{:error, reason}` on failure
  """
  @spec transfer(
    tree_authority :: String.t(),
    leaf_owner :: String.t(),
    new_leaf_owner :: String.t(),
    merkle_tree :: String.t(),
    root :: binary(),
    data_hash :: binary(),
    creator_hash :: binary(),
    nonce :: non_neg_integer(),
    index :: non_neg_integer()
  ) :: {:ok, String.t()} | {:error, String.t()}
  def transfer(
    _tree_authority,
    _leaf_owner,
    _new_leaf_owner,
    _merkle_tree,
    _root,
    _data_hash,
    _creator_hash,
    _nonce,
    _index
  ), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Requests an airdrop of SOL tokens for testing purposes (devnet only).

  ## Parameters

  * `public_key` - Base58 encoded public key to receive the airdrop
  * `amount_sol` - Amount of SOL to request

  ## Returns

  * `{:ok, signature}` on success
  * `{:error, reason}` on failure
  """
  @spec request_airdrop(public_key :: String.t(), amount_sol :: float()) ::
    {:ok, String.t()} | {:error, String.t()}
  def request_airdrop(_public_key, _amount_sol), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Decompresses a compressed NFT, converting it back to a regular SPL token.

  ## Parameters
  - tree_authority: The public key of the tree authority
  - leaf_owner: The public key of the leaf owner
  - leaf_delegate: The public key of the leaf delegate
  - merkle_tree: The public key of the merkle tree
  - root: The root hash of the merkle tree
  - data_hash: The hash of the NFT data
  - creator_hash: The hash of the creator data
  - nonce: The nonce of the leaf
  - index: The index of the leaf in the tree

  ## Returns
  - `{:ok, signature}` on success
  - `{:error, reason}` on failure
  """
  @spec decompress_v1(
    tree_authority :: String.t(),
    leaf_owner :: String.t(),
    leaf_delegate :: String.t(),
    merkle_tree :: String.t(),
    root :: String.t(),
    data_hash :: String.t(),
    creator_hash :: String.t(),
    nonce :: non_neg_integer(),
    index :: non_neg_integer()
  ) :: {:ok, String.t()} | {:error, String.t()}
  def decompress_v1(tree_authority, leaf_owner, leaf_delegate, merkle_tree, root, data_hash, creator_hash, nonce, index) do
    case :erlang.nif_error(:nif_not_loaded) do
      {:ok, signature} -> {:ok, signature}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Delegates authority over a compressed NFT to a new delegate.

  ## Parameters
  - tree_authority: The public key of the tree authority
  - leaf_owner: The public key of the leaf owner
  - previous_leaf_delegate: The public key of the previous delegate
  - new_leaf_delegate: The public key of the new delegate
  - merkle_tree: The public key of the merkle tree
  - root: The root hash of the merkle tree
  - data_hash: The hash of the NFT data
  - creator_hash: The hash of the creator data
  - nonce: The nonce of the leaf
  - index: The index of the leaf in the tree

  ## Returns
  - `{:ok, signature}` on success
  - `{:error, reason}` on failure
  """
  @spec delegate(
    tree_authority :: String.t(),
    leaf_owner :: String.t(),
    previous_leaf_delegate :: String.t(),
    new_leaf_delegate :: String.t(),
    merkle_tree :: String.t(),
    root :: String.t(),
    data_hash :: String.t(),
    creator_hash :: String.t(),
    nonce :: non_neg_integer(),
    index :: non_neg_integer()
  ) :: {:ok, String.t()} | {:error, String.t()}
  def delegate(tree_authority, leaf_owner, previous_leaf_delegate, new_leaf_delegate, merkle_tree, root, data_hash, creator_hash, nonce, index) do
    case :erlang.nif_error(:nif_not_loaded) do
      {:ok, signature} -> {:ok, signature}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Redeems a compressed NFT, preparing it for decompression.

  ## Parameters
  - tree_authority: The public key of the tree authority
  - leaf_owner: The public key of the leaf owner
  - leaf_delegate: The public key of the leaf delegate
  - merkle_tree: The public key of the merkle tree
  - root: The root hash of the merkle tree
  - data_hash: The hash of the NFT data
  - creator_hash: The hash of the creator data
  - nonce: The nonce of the leaf
  - index: The index of the leaf in the tree

  ## Returns
  - `{:ok, signature}` on success
  - `{:error, reason}` on failure
  """
  @spec redeem(
    tree_authority :: String.t(),
    leaf_owner :: String.t(),
    leaf_delegate :: String.t(),
    merkle_tree :: String.t(),
    root :: String.t(),
    data_hash :: String.t(),
    creator_hash :: String.t(),
    nonce :: non_neg_integer(),
    index :: non_neg_integer()
  ) :: {:ok, String.t()} | {:error, String.t()}
  def redeem(tree_authority, leaf_owner, leaf_delegate, merkle_tree, root, data_hash, creator_hash, nonce, index) do
    case :erlang.nif_error(:nif_not_loaded) do
      {:ok, signature} -> {:ok, signature}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Cancels a pending redemption of a compressed NFT.

  ## Parameters
  - tree_authority: The public key of the tree authority
  - leaf_owner: The public key of the leaf owner
  - merkle_tree: The public key of the merkle tree
  - root: The root hash of the merkle tree
  - data_hash: The hash of the NFT data
  - creator_hash: The hash of the creator data
  - nonce: The nonce of the leaf
  - index: The index of the leaf in the tree

  ## Returns
  - `{:ok, signature}` on success
  - `{:error, reason}` on failure
  """
  @spec cancel_redeem(
    tree_authority :: String.t(),
    leaf_owner :: String.t(),
    merkle_tree :: String.t(),
    root :: String.t(),
    data_hash :: String.t(),
    creator_hash :: String.t(),
    nonce :: non_neg_integer(),
    index :: non_neg_integer()
  ) :: {:ok, String.t()} | {:error, String.t()}
  def cancel_redeem(tree_authority, leaf_owner, merkle_tree, root, data_hash, creator_hash, nonce, index) do
    case :erlang.nif_error(:nif_not_loaded) do
      {:ok, signature} -> {:ok, signature}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Compresses a regular SPL token into a compressed NFT.

  ## Parameters
  - tree_authority: The public key of the tree authority
  - leaf_owner: The public key of the leaf owner
  - leaf_delegate: The public key of the leaf delegate
  - merkle_tree: The public key of the merkle tree
  - token_account: The public key of the token account to compress
  - mint: The public key of the token mint

  ## Returns
  - `{:ok, signature}` on success
  - `{:error, reason}` on failure
  """
  @spec compress(
    tree_authority :: String.t(),
    leaf_owner :: String.t(),
    leaf_delegate :: String.t(),
    merkle_tree :: String.t(),
    token_account :: String.t(),
    mint :: String.t()
  ) :: {:ok, String.t()} | {:error, String.t()}
  def compress(tree_authority, leaf_owner, leaf_delegate, merkle_tree, token_account, mint) do
    case :erlang.nif_error(:nif_not_loaded) do
      {:ok, signature} -> {:ok, signature}
      {:error, reason} -> {:error, reason}
    end
  end
end