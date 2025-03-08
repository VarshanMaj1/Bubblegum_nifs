defmodule BubblegumNif.Types do
  @moduledoc """
  Type definitions for BubblegumNif.
  """

  defmodule Config do
    @moduledoc """
    Configuration for Solana client.
    """
    defstruct [:network, :rpc_url, :commitment]

    @type t :: %__MODULE__{
      network: String.t(),
      rpc_url: String.t(),
      commitment: String.t()
    }
  end

  defmodule Creator do
    @moduledoc """
    NFT creator information.
    """
    defstruct [:address, :verified, :share]

    @type t :: %__MODULE__{
      address: String.t(),
      verified: boolean(),
      share: integer()
    }
  end

  defmodule MetadataArgs do
    @moduledoc """
    NFT metadata arguments.
    """
    defstruct [
      :name,
      :symbol,
      :uri,
      :creators,
      :seller_fee_basis_points,
      :primary_sale_happened,
      :is_mutable,
      :collection
    ]

    @type t :: %__MODULE__{
      name: String.t(),
      symbol: String.t(),
      uri: String.t(),
      creators: [Creator.t()],
      seller_fee_basis_points: integer(),
      primary_sale_happened: boolean(),
      is_mutable: boolean(),
      collection: String.t() | nil
    }
  end
end 