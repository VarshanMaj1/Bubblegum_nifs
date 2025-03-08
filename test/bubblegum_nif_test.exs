defmodule BubblegumNifTest do
  use ExUnit.Case
  doctest BubblegumNif

  alias BubblegumNif.Types.{Config, Creator, MetadataArgs}

  @moduletag :integration

  @test_authority "5ZWj7a1f8tWkjBESHKgrLmXshuXxqeY9SYcfbshpAqPG"
  @test_owner "7UX2i7SucgLMQcfZ75s3VXmZZY4YRUyJN9X1RgfMoDUi"
  @test_delegate "7UX2i7SucgLMQcfZ75s3VXmZZY4YRUyJN9X1RgfMoDUi"
  @test_metadata_uri "https://arweave.net/123"

  setup do
    config = %Config{
      network: "devnet",
      rpc_url: "https://api.devnet.solana.com",
      commitment: "confirmed"
    }
    {:ok, _} = BubblegumNif.initialize_client(config)

    # Load test keypair - this should be a devnet keypair
    keypair_json = File.read!("test/support/test_keypair.json")
    {:ok, _} = BubblegumNif.load_keypair(keypair_json)

    # Request airdrop for test account
    {:ok, _} = BubblegumNif.request_airdrop(keypair_json, 2.0)

    :ok
  end

  describe "tree operations" do
    test "creates a new merkle tree" do
      {:ok, signature} = BubblegumNif.create_tree_config(
        14,
        64,
        "YOUR_TEST_PUBKEY",
        nil
      )
      assert is_binary(signature)
    end
  end

  describe "NFT operations" do
    setup do
      {:ok, tree_signature} = BubblegumNif.create_tree_config(
        14,
        64,
        "YOUR_TEST_PUBKEY",
        nil
      )

      {:ok, %{tree_signature: tree_signature}}
    end

    test "mints a new compressed NFT", %{tree_signature: tree_signature} do
      metadata = %MetadataArgs{
        name: "Test NFT",
        symbol: "TEST",
        uri: "https://arweave.net/test",
        creators: [
          %Creator{
            address: "YOUR_TEST_PUBKEY",
            verified: true,
            share: 100
          }
        ],
        seller_fee_basis_points: 500,
        primary_sale_happened: false,
        is_mutable: true,
        collection: nil
      }

      {:ok, signature} = BubblegumNif.mint_v1(
        tree_signature,
        "YOUR_TEST_PUBKEY",
        "YOUR_TEST_PUBKEY",
        metadata
      )

      assert is_binary(signature)
    end

    test "transfers a compressed NFT", %{tree_signature: tree_signature} do
      {:ok, signature} = BubblegumNif.transfer(
        tree_signature,
        "YOUR_TEST_PUBKEY",
        "RECIPIENT_TEST_PUBKEY",
        "MERKLE_TREE_PUBKEY",
        <<0::256>>,
        <<0::256>>,
        <<0::256>>,
        0,
        0
      )

      assert is_binary(signature)
    end

    test "delegates a compressed NFT", %{tree_signature: tree_signature} do
      {:ok, signature} = BubblegumNif.delegate(
        tree_signature,
        "YOUR_TEST_PUBKEY",
        "PREVIOUS_DELEGATE_PUBKEY",
        "NEW_DELEGATE_PUBKEY",
        "MERKLE_TREE_PUBKEY",
        Base58.encode(<<0::256>>),
        Base58.encode(<<0::256>>),
        Base58.encode(<<0::256>>),
        0,
        0
      )

      assert is_binary(signature)
    end

    test "redeems a compressed NFT", %{tree_signature: tree_signature} do
      {:ok, signature} = BubblegumNif.redeem(
        tree_signature,
        "YOUR_TEST_PUBKEY",
        "YOUR_TEST_PUBKEY",
        "MERKLE_TREE_PUBKEY",
        Base58.encode(<<0::256>>),
        Base58.encode(<<0::256>>),
        Base58.encode(<<0::256>>),
        0,
        0
      )

      assert is_binary(signature)
    end

    test "cancels redemption of a compressed NFT", %{tree_signature: tree_signature} do
      {:ok, signature} = BubblegumNif.cancel_redeem(
        tree_signature,
        "YOUR_TEST_PUBKEY",
        "MERKLE_TREE_PUBKEY",
        Base58.encode(<<0::256>>),
        Base58.encode(<<0::256>>),
        Base58.encode(<<0::256>>),
        0,
        0
      )

      assert is_binary(signature)
    end

    test "compresses an NFT", %{tree_signature: tree_signature} do
      {:ok, signature} = BubblegumNif.compress(
        tree_signature,
        "YOUR_TEST_PUBKEY",
        "YOUR_TEST_PUBKEY",
        "MERKLE_TREE_PUBKEY",
        "TOKEN_ACCOUNT_PUBKEY",
        "MINT_PUBKEY"
      )

      assert is_binary(signature)
    end

    test "decompresses an NFT", %{tree_signature: tree_signature} do
      {:ok, signature} = BubblegumNif.decompress_v1(
        tree_signature,
        "YOUR_TEST_PUBKEY",
        "YOUR_TEST_PUBKEY",
        "MERKLE_TREE_PUBKEY",
        Base58.encode(<<0::256>>),
        Base58.encode(<<0::256>>),
        Base58.encode(<<0::256>>),
        0,
        0
      )

      assert is_binary(signature)
    end
  end

  describe "error handling" do
    test "handles invalid public key" do
      {:error, reason} = BubblegumNif.create_tree_config(
        14,
        64,
        "invalid_pubkey",
        nil
      )
      assert reason =~ "Invalid public key"
    end

    test "handles invalid metadata" do
      metadata = %MetadataArgs{
        name: "Test NFT",
        symbol: "TEST",
        uri: "https://arweave.net/test",
        creators: [
          %Creator{
            address: "invalid_pubkey",
            verified: true,
            share: 100
          }
        ],
        seller_fee_basis_points: 500,
        primary_sale_happened: false,
        is_mutable: true,
        collection: nil
      }

      {:error, reason} = BubblegumNif.mint_v1(
        "YOUR_TEST_PUBKEY",
        "YOUR_TEST_PUBKEY",
        "YOUR_TEST_PUBKEY",
        metadata
      )

      assert reason =~ "Invalid public key"
    end
  end
end