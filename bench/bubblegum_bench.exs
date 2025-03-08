defmodule BubblegumBench do
  alias BubblegumNif.Types.{Config, Creator, MetadataArgs}

  @test_authority "5ZWj7a1f8tWkjBESHKgrLmXshuXxqeY9SYcfbshpAqPG"
  @test_owner "7UX2i7SucgLMQcfZ75s3VXmZZY4YRUyJN9X1RgfMoDUi"
  @test_delegate "7UX2i7SucgLMQcfZ75s3VXmZZY4YRUyJN9X1RgfMoDUi"
  @test_metadata_uri "https://arweave.net/123"

  def setup do
    config = %Config{
      network: "devnet",
      rpc_url: "https://api.devnet.solana.com",
      commitment: "confirmed"
    }

    {:ok, _} = BubblegumNif.initialize_client(config)

    # Load test keypair
    keypair_json = File.read!(Path.expand("./test/fixtures/test_keypair.json"))
    {:ok, _} = BubblegumNif.load_keypair(keypair_json)

    # Request airdrop for test wallet
    {:ok, _} = BubblegumNif.request_airdrop(@test_authority, 2.0)
    
    :ok
  end

  def run do
    setup()

    metadata = %MetadataArgs{
      name: "Benchmark NFT",
      symbol: "BNFT",
      uri: @test_metadata_uri,
      creators: [
        %Creator{
          address: @test_authority,
          verified: true,
          share: 100
        }
      ],
      seller_fee_basis_points: 500,
      primary_sale_happened: false,
      is_mutable: true,
      collection: nil
    }

    Benchee.run(
      %{
        "create_tree_config" => fn ->
          BubblegumNif.create_tree_config(14, 64, @test_authority, nil)
        end,
        "mint_v1" => fn ->
          BubblegumNif.mint_v1(
            @test_authority,
            @test_owner,
            @test_delegate,
            metadata
          )
        end,
        "transfer" => fn ->
          BubblegumNif.transfer(
            @test_authority,
            @test_owner,
            @test_delegate,
            @test_authority,
            <<0::256>>,
            <<0::256>>,
            <<0::256>>,
            1,
            0
          )
        end,
        "request_airdrop" => fn ->
          BubblegumNif.request_airdrop(@test_authority, 0.1)
        end
      },
      time: 10,
      memory_time: 2,
      formatters: [
        {Benchee.Formatters.Console, extended_statistics: true},
        {Benchee.Formatters.HTML, file: "bench/output/bubblegum.html", auto_open: false}
      ],
      print: [
        fast_warning: false
      ],
      parallel: 1,
      warmup: 2
    )
  end
end

BubblegumBench.run() 