defmodule BubblegumNif.MerkleTreeTest do
  use ExUnit.Case
  use PropCheck

  @moduletag :property

  property "merkle tree properties" do
    forall {leaves, index} <- {list(binary(32)), non_neg_integer()} do
      tree = create_test_tree(leaves)
      
      # Property 1: Root is always 32 bytes
      root = get_root(tree)
      byte_size(root) == 32 and
      
      # Property 2: Proof verification works for valid leaves
      case Enum.at(leaves, index) do
        nil -> true
        leaf ->
          proof = get_proof(tree, index)
          verify_proof(root, leaf, proof, index)
      end and
      
      # Property 3: Proof verification fails for invalid leaves
      forall invalid_leaf <- binary(32) do
        invalid_leaf not in leaves or
          not verify_proof(root, invalid_leaf, get_proof(tree, index), index)
      end and
      
      # Property 4: Tree maintains sorted order
      is_sorted(get_leaves(tree))
    end
  end

  property "merkle tree insertion" do
    forall {initial_leaves, new_leaf} <- {list(binary(32)), binary(32)} do
      tree = create_test_tree(initial_leaves)
      {:ok, new_index} = insert_leaf(tree, new_leaf)
      
      # Property 1: New leaf is retrievable
      get_leaf(tree, new_index) == new_leaf and
      
      # Property 2: Previous leaves are unchanged
      Enum.all?(Enum.with_index(initial_leaves), fn {leaf, i} ->
        get_leaf(tree, i) == leaf
      end) and
      
      # Property 3: Root changes after insertion
      old_root = get_root(create_test_tree(initial_leaves))
      new_root = get_root(tree)
      old_root != new_root
    end
  end

  property "merkle tree proof consistency" do
    forall {leaves, proof_index} <- {list(binary(32)), non_neg_integer()} do
      tree = create_test_tree(leaves)
      root = get_root(tree)
      
      case Enum.at(leaves, proof_index) do
        nil -> true
        leaf ->
          proof = get_proof(tree, proof_index)
          
          # Property 1: Valid proof for correct leaf
          verify_proof(root, leaf, proof, proof_index) and
          
          # Property 2: Invalid proof for wrong index
          forall wrong_index <- integer(0, length(leaves) - 1) do
            wrong_index == proof_index or
              not verify_proof(root, leaf, proof, wrong_index)
          end and
          
          # Property 3: Invalid proof for wrong leaf
          forall wrong_leaf <- binary(32) do
            wrong_leaf == leaf or
              not verify_proof(root, wrong_leaf, proof, proof_index)
          end
      end
    end
  end

  # Helper functions to interface with your actual implementation
  defp create_test_tree(leaves) do
    # This should create a merkle tree with the given leaves
    # Replace with actual implementation
    leaves
  end

  defp get_root(tree) do
    # This should return the root hash of the tree
    # Replace with actual implementation
    <<0::256>>
  end

  defp get_proof(tree, index) do
    # This should return the merkle proof for the leaf at the given index
    # Replace with actual implementation
    []
  end

  defp verify_proof(root, leaf, proof, index) do
    # This should verify the merkle proof
    # Replace with actual implementation
    true
  end

  defp get_leaves(tree) do
    # This should return all leaves in the tree
    # Replace with actual implementation
    []
  end

  defp get_leaf(tree, index) do
    # This should return the leaf at the given index
    # Replace with actual implementation
    <<0::256>>
  end

  defp insert_leaf(tree, leaf) do
    # This should insert a new leaf into the tree
    # Replace with actual implementation
    {:ok, 0}
  end

  defp is_sorted(leaves) do
    leaves == Enum.sort(leaves)
  end
end 