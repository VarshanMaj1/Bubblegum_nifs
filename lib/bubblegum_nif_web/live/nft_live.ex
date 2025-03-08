defmodule BubblegumNifWeb.NFTLive do
  use BubblegumNifWeb, :live_view
  alias BubblegumNif.Types.{Config, Creator, MetadataArgs}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(5000, self(), :update_status)
    end

    {:ok,
     assign(socket,
       page_title: "Bubblegum NFT Demo",
       tree_form: %{
         max_depth: 14,
         max_buffer_size: 64,
         authority: nil,
         canopy_depth: nil
       },
       mint_form: %{
         tree_authority: nil,
         name: nil,
         symbol: nil,
         uri: nil,
         creator_address: nil,
         creator_share: 100,
         seller_fee_basis_points: 500,
         collection: nil
       },
       transfer_form: %{
         tree_authority: nil,
         current_owner: nil,
         new_owner: nil,
         merkle_tree: nil,
         index: 0
       },
       decompress_form: %{
         tree_authority: nil,
         leaf_owner: nil,
         leaf_delegate: nil,
         merkle_tree: nil,
         root: nil,
         data_hash: nil,
         creator_hash: nil,
         nonce: 0,
         index: 0
       },
       delegate_form: %{
         tree_authority: nil,
         leaf_owner: nil,
         previous_delegate: nil,
         new_delegate: nil,
         merkle_tree: nil,
         root: nil,
         data_hash: nil,
         creator_hash: nil,
         nonce: 0,
         index: 0
       },
       redeem_form: %{
         tree_authority: nil,
         leaf_owner: nil,
         leaf_delegate: nil,
         merkle_tree: nil,
         root: nil,
         data_hash: nil,
         creator_hash: nil,
         nonce: 0,
         index: 0
       },
       compress_form: %{
         tree_authority: nil,
         leaf_owner: nil,
         leaf_delegate: nil,
         merkle_tree: nil,
         token_account: nil,
         mint: nil
       },
       loading: false,
       error: nil,
       success: nil,
       recent_transactions: [],
       active_tab: "create",
       network_status: "unknown",
       balance: nil
     )}
  end

  @impl true
  def handle_info(:update_status, socket) do
    # Update network status and balance
    network_status = get_network_status()
    balance = get_balance(socket.assigns.mint_form.creator_address)

    {:noreply, assign(socket, network_status: network_status, balance: balance)}
  end

  @impl true
  def handle_event("change-tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  @impl true
  def handle_event("validate-form", %{"tree" => params}, socket) do
    changeset = validate_tree_params(params)
    {:noreply, assign(socket, tree_form: changeset)}
  end

  @impl true
  def handle_event("validate-form", %{"mint" => params}, socket) do
    changeset = validate_mint_params(params)
    {:noreply, assign(socket, mint_form: changeset)}
  end

  @impl true
  def handle_event("create-tree", %{"tree" => params}, socket) do
    case BubblegumNif.create_tree_config(
      String.to_integer(params["max_depth"]),
      String.to_integer(params["max_buffer_size"]),
      params["authority"],
      if(params["canopy_depth"] != "", do: String.to_integer(params["canopy_depth"]))
    ) do
      {:ok, signature} ->
        {:noreply,
         socket
         |> put_flash(:info, "Tree created successfully! Signature: #{signature}")
         |> assign(:success, signature)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create tree: #{reason}")
         |> assign(:error, reason)}
    end
  end

  @impl true
  def handle_event("mint-nft", %{"mint" => params}, socket) do
    metadata = %MetadataArgs{
      name: params["name"],
      symbol: params["symbol"],
      uri: params["uri"],
      creators: [
        %Creator{
          address: params["creator_address"],
          verified: true,
          share: String.to_integer(params["creator_share"])
        }
      ],
      seller_fee_basis_points: String.to_integer(params["seller_fee_basis_points"]),
      primary_sale_happened: false,
      is_mutable: true,
      collection: if(params["collection"] != "", do: params["collection"])
    }

    case BubblegumNif.mint_v1(
      params["tree_authority"],
      params["creator_address"],
      params["creator_address"],
      metadata
    ) do
      {:ok, signature} ->
        {:noreply,
         socket
         |> put_flash(:info, "NFT minted successfully! Signature: #{signature}")
         |> assign(:success, signature)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to mint NFT: #{reason}")
         |> assign(:error, reason)}
    end
  end

  @impl true
  def handle_event("transfer-nft", %{"transfer" => params}, socket) do
    case BubblegumNif.transfer(
      params["tree_authority"],
      params["current_owner"],
      params["new_owner"],
      params["merkle_tree"],
      <<0::256>>,
      <<0::256>>,
      <<0::256>>,
      0,
      String.to_integer(params["index"])
    ) do
      {:ok, signature} ->
        {:noreply,
         socket
         |> put_flash(:info, "NFT transferred successfully! Signature: #{signature}")
         |> assign(:success, signature)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to transfer NFT: #{reason}")
         |> assign(:error, reason)}
    end
  end

  @impl true
  def handle_event("decompress-nft", %{"decompress" => params}, socket) do
    case BubblegumNif.decompress_v1(
      params["tree_authority"],
      params["leaf_owner"],
      params["leaf_delegate"],
      params["merkle_tree"],
      params["root"],
      params["data_hash"],
      params["creator_hash"],
      String.to_integer(params["nonce"]),
      String.to_integer(params["index"])
    ) do
      {:ok, signature} ->
        {:noreply,
         socket
         |> put_flash(:info, "NFT decompressed successfully! Signature: #{signature}")
         |> assign(:success, signature)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to decompress NFT: #{reason}")
         |> assign(:error, reason)}
    end
  end

  @impl true
  def handle_event("delegate-nft", %{"delegate" => params}, socket) do
    case BubblegumNif.delegate(
      params["tree_authority"],
      params["leaf_owner"],
      params["previous_delegate"],
      params["new_delegate"],
      params["merkle_tree"],
      params["root"],
      params["data_hash"],
      params["creator_hash"],
      String.to_integer(params["nonce"]),
      String.to_integer(params["index"])
    ) do
      {:ok, signature} ->
        {:noreply,
         socket
         |> put_flash(:info, "NFT delegated successfully! Signature: #{signature}")
         |> assign(:success, signature)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delegate NFT: #{reason}")
         |> assign(:error, reason)}
    end
  end

  @impl true
  def handle_event("redeem-nft", %{"redeem" => params}, socket) do
    case BubblegumNif.redeem(
      params["tree_authority"],
      params["leaf_owner"],
      params["leaf_delegate"],
      params["merkle_tree"],
      params["root"],
      params["data_hash"],
      params["creator_hash"],
      String.to_integer(params["nonce"]),
      String.to_integer(params["index"])
    ) do
      {:ok, signature} ->
        {:noreply,
         socket
         |> put_flash(:info, "NFT redeemed successfully! Signature: #{signature}")
         |> assign(:success, signature)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to redeem NFT: #{reason}")
         |> assign(:error, reason)}
    end
  end

  @impl true
  def handle_event("cancel-redeem", %{"cancel_redeem" => params}, socket) do
    case BubblegumNif.cancel_redeem(
      params["tree_authority"],
      params["leaf_owner"],
      params["merkle_tree"],
      params["root"],
      params["data_hash"],
      params["creator_hash"],
      String.to_integer(params["nonce"]),
      String.to_integer(params["index"])
    ) do
      {:ok, signature} ->
        {:noreply,
         socket
         |> put_flash(:info, "Redemption cancelled successfully! Signature: #{signature}")
         |> assign(:success, signature)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to cancel redemption: #{reason}")
         |> assign(:error, reason)}
    end
  end

  @impl true
  def handle_event("compress-nft", %{"compress" => params}, socket) do
    case BubblegumNif.compress(
      params["tree_authority"],
      params["leaf_owner"],
      params["leaf_delegate"],
      params["merkle_tree"],
      params["token_account"],
      params["mint"]
    ) do
      {:ok, signature} ->
        {:noreply,
         socket
         |> put_flash(:info, "NFT compressed successfully! Signature: #{signature}")
         |> assign(:success, signature)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to compress NFT: #{reason}")
         |> assign(:error, reason)}
    end
  end

  defp get_network_status do
    case BubblegumNif.get_network_status() do
      {:ok, status} -> status
      _ -> "unknown"
    end
  end

  defp get_balance(nil), do: nil
  defp get_balance(address) do
    case BubblegumNif.get_balance(address) do
      {:ok, balance} -> balance
      _ -> nil
    end
  end

  defp validate_tree_params(params) do
    types = %{
      max_depth: :integer,
      max_buffer_size: :integer,
      authority: :string,
      canopy_depth: :integer
    }

    {%{}, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
    |> Ecto.Changeset.validate_required([:max_depth, :max_buffer_size, :authority])
    |> Ecto.Changeset.validate_number(:max_depth, greater_than: 0, less_than_or_equal_to: 30)
    |> Ecto.Changeset.validate_number(:max_buffer_size, greater_than: 0)
  end

  defp validate_mint_params(params) do
    types = %{
      tree_authority: :string,
      name: :string,
      symbol: :string,
      uri: :string,
      creator_address: :string,
      creator_share: :integer,
      seller_fee_basis_points: :integer,
      collection: :string
    }

    {%{}, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
    |> Ecto.Changeset.validate_required([:tree_authority, :name, :symbol, :uri, :creator_address])
    |> Ecto.Changeset.validate_number(:creator_share, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> Ecto.Changeset.validate_number(:seller_fee_basis_points, greater_than_or_equal_to: 0, less_than_or_equal_to: 10000)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">Bubblegum NFT Demo</h1>

      <!-- Network Status -->
      <div class="mb-8 flex justify-between items-center">
        <div class="flex items-center space-x-4">
          <div class={"w-3 h-3 rounded-full #{network_status_color(@network_status)}"}></div>
          <span class="text-sm font-medium">Network: <%= @network_status %></span>
        </div>
        <%= if @balance do %>
          <div class="text-sm font-medium">
            Balance: <%= format_balance(@balance) %> SOL
          </div>
        <% end %>
      </div>

      <!-- Tab Navigation -->
      <div class="mb-8">
        <nav class="flex space-x-4">
          <%= for {tab, label} <- [
            {"create", "Create Tree"},
            {"mint", "Mint NFT"},
            {"transfer", "Transfer"},
            {"delegate", "Delegate"},
            {"redeem", "Redeem"},
            {"compress", "Compress"}
          ] do %>
            <button
              phx-click="change-tab"
              phx-value-tab={tab}
              class={"px-4 py-2 rounded-md #{if @active_tab == tab, do: "bg-indigo-600 text-white", else: "bg-gray-100 text-gray-700"}"}
            >
              <%= label %>
            </button>
          <% end %>
        </nav>
      </div>

      <!-- Forms -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
        <%= case @active_tab do %>
          <% "create" -> %>
            <!-- Create Tree Form -->
            <div class="bg-white p-6 rounded-lg shadow-md">
              <h2 class="text-xl font-semibold mb-4">Create Tree</h2>
              <.form for={%{}} phx-submit="create-tree" phx-change="validate-form">
                <div class="space-y-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Max Depth</label>
                    <input type="number" name="tree[max_depth]" value={@tree_form.max_depth}
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Max Buffer Size</label>
                    <input type="number" name="tree[max_buffer_size]" value={@tree_form.max_buffer_size}
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Authority</label>
                    <input type="text" name="tree[authority]" placeholder="Authority public key"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Canopy Depth (optional)</label>
                    <input type="number" name="tree[canopy_depth]"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <button type="submit"
                    class="w-full bg-indigo-600 text-white py-2 px-4 rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
                    Create Tree
                  </button>
                </div>
              </.form>
            </div>

          <% "mint" -> %>
            <!-- Mint NFT Form -->
            <div class="bg-white p-6 rounded-lg shadow-md">
              <h2 class="text-xl font-semibold mb-4">Mint NFT</h2>
              <.form for={%{}} phx-submit="mint-nft" phx-change="validate-form">
                <div class="space-y-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Tree Authority</label>
                    <input type="text" name="mint[tree_authority]" placeholder="Tree authority public key"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Name</label>
                    <input type="text" name="mint[name]" placeholder="NFT name"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Symbol</label>
                    <input type="text" name="mint[symbol]" placeholder="NFT symbol"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">URI</label>
                    <input type="text" name="mint[uri]" placeholder="Metadata URI"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Creator Address</label>
                    <input type="text" name="mint[creator_address]" placeholder="Creator public key"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <button type="submit"
                    class="w-full bg-indigo-600 text-white py-2 px-4 rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
                    Mint NFT
                  </button>
                </div>
              </.form>
            </div>

          <% "transfer" -> %>
            <!-- Transfer NFT Form -->
            <div class="bg-white p-6 rounded-lg shadow-md">
              <h2 class="text-xl font-semibold mb-4">Transfer NFT</h2>
              <.form for={%{}} phx-submit="transfer-nft">
                <div class="space-y-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Tree Authority</label>
                    <input type="text" name="transfer[tree_authority]" placeholder="Tree authority public key"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Current Owner</label>
                    <input type="text" name="transfer[current_owner]" placeholder="Current owner public key"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">New Owner</label>
                    <input type="text" name="transfer[new_owner]" placeholder="New owner public key"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Merkle Tree</label>
                    <input type="text" name="transfer[merkle_tree]" placeholder="Merkle tree public key"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Index</label>
                    <input type="number" name="transfer[index]" value={@transfer_form.index}
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <button type="submit"
                    class="w-full bg-indigo-600 text-white py-2 px-4 rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
                    Transfer NFT
                  </button>
                </div>
              </.form>
            </div>

          <% "delegate" -> %>
            <!-- Delegate NFT Form -->
            <div class="bg-white p-6 rounded-lg shadow-md">
              <h2 class="text-xl font-semibold mb-4">Delegate NFT</h2>
              <.form for={%{}} phx-submit="delegate-nft">
                <div class="space-y-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Tree Authority</label>
                    <input type="text" name="delegate[tree_authority]" placeholder="Tree authority public key"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Leaf Owner</label>
                    <input type="text" name="delegate[leaf_owner]" placeholder="Leaf owner public key"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Previous Delegate</label>
                    <input type="text" name="delegate[previous_delegate]" placeholder="Previous delegate public key"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">New Delegate</label>
                    <input type="text" name="delegate[new_delegate]" placeholder="New delegate public key"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Merkle Tree</label>
                    <input type="text" name="delegate[merkle_tree]" placeholder="Merkle tree public key"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Root Hash</label>
                    <input type="text" name="delegate[root]" placeholder="Root hash"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Data Hash</label>
                    <input type="text" name="delegate[data_hash]" placeholder="Data hash"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Creator Hash</label>
                    <input type="text" name="delegate[creator_hash]" placeholder="Creator hash"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Nonce</label>
                    <input type="number" name="delegate[nonce]" value={@delegate_form.nonce}
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Index</label>
                    <input type="number" name="delegate[index]" value={@delegate_form.index}
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <button type="submit"
                    class="w-full bg-indigo-600 text-white py-2 px-4 rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
                    Delegate NFT
                  </button>
                </div>
              </.form>
            </div>

          <% "redeem" -> %>
            <!-- Redeem NFT Form -->
            <div class="bg-white p-6 rounded-lg shadow-md">
              <h2 class="text-xl font-semibold mb-4">Redeem NFT</h2>
              <.form for={%{}} phx-submit="redeem-nft">
                <div class="space-y-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Tree Authority</label>
                    <input type="text" name="redeem[tree_authority]" placeholder="Tree authority public key"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Leaf Owner</label>
                    <input type="text" name="redeem[leaf_owner]" placeholder="Leaf owner public key"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Leaf Delegate</label>
                    <input type="text" name="redeem[leaf_delegate]" placeholder="Leaf delegate public key"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Merkle Tree</label>
                    <input type="text" name="redeem[merkle_tree]" placeholder="Merkle tree public key"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Root Hash</label>
                    <input type="text" name="redeem[root]" placeholder="Root hash"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Data Hash</label>
                    <input type="text" name="redeem[data_hash]" placeholder="Data hash"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Creator Hash</label>
                    <input type="text" name="redeem[creator_hash]" placeholder="Creator hash"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Nonce</label>
                    <input type="number" name="redeem[nonce]" value={@redeem_form.nonce}
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Index</label>
                    <input type="number" name="redeem[index]" value={@redeem_form.index}
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <button type="submit"
                    class="w-full bg-indigo-600 text-white py-2 px-4 rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
                    Redeem NFT
                  </button>
                </div>
              </.form>
            </div>

          <% "compress" -> %>
            <!-- Compress NFT Form -->
            <div class="bg-white p-6 rounded-lg shadow-md">
              <h2 class="text-xl font-semibold mb-4">Compress NFT</h2>
              <.form for={%{}} phx-submit="compress-nft">
                <div class="space-y-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Tree Authority</label>
                    <input type="text" name="compress[tree_authority]" placeholder="Tree authority public key"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Leaf Owner</label>
                    <input type="text" name="compress[leaf_owner]" placeholder="Leaf owner public key"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Leaf Delegate</label>
                    <input type="text" name="compress[leaf_delegate]" placeholder="Leaf delegate public key"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Merkle Tree</label>
                    <input type="text" name="compress[merkle_tree]" placeholder="Merkle tree public key"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Token Account</label>
                    <input type="text" name="compress[token_account]" placeholder="Token account public key"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Mint</label>
                    <input type="text" name="compress[mint]" placeholder="Mint public key"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" />
                  </div>

                  <button type="submit"
                    class="w-full bg-indigo-600 text-white py-2 px-4 rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
                    Compress NFT
                  </button>
                </div>
              </.form>
            </div>
        <% end %>

        <!-- Recent Transactions -->
        <div class="bg-white p-6 rounded-lg shadow-md">
          <h2 class="text-xl font-semibold mb-4">Recent Transactions</h2>
          <div class="space-y-4">
            <%= for tx <- @recent_transactions do %>
              <div class="p-4 border rounded-md">
                <div class="flex justify-between items-center">
                  <span class="font-medium"><%= tx.type %></span>
                  <span class={"text-sm #{if tx.status == "success", do: "text-green-600", else: "text-red-600"}"}><%= tx.status %></span>
                </div>
                <div class="text-sm text-gray-500 mt-1">
                  Signature: <%= tx.signature %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Status Messages -->
      <%= if @error do %>
        <div class="mt-8 p-4 bg-red-100 border border-red-400 text-red-700 rounded-md">
          <%= @error %>
        </div>
      <% end %>

      <%= if @success do %>
        <div class="mt-8 p-4 bg-green-100 border border-green-400 text-green-700 rounded-md">
          Transaction successful! Signature: <%= @success %>
        </div>
      <% end %>

      <!-- Loading Overlay -->
      <%= if @loading do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center">
          <div class="bg-white p-4 rounded-md shadow-lg">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600 mx-auto"></div>
            <p class="mt-2 text-center">Processing transaction...</p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp network_status_color("online"), do: "bg-green-500"
  defp network_status_color("degraded"), do: "bg-yellow-500"
  defp network_status_color(_), do: "bg-red-500"

  defp format_balance(balance) do
    :erlang.float_to_binary(balance, decimals: 4)
  end
end 