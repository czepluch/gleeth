import gleam/int
import gleam/io
import gleam/result
import gleeth/crypto/transaction
import gleeth/crypto/wallet
import gleeth/ethereum/formatting
import gleeth/ethereum/types as eth_types
import gleeth/rpc/methods
import gleeth/rpc/types as rpc_types
import gleeth/utils/hex

pub type SendArgs {
  SendArgs(
    to: String,
    value: String,
    private_key: String,
    gas_limit: String,
    data: String,
    legacy: Bool,
  )
}

pub fn execute(
  rpc_url: String,
  args: SendArgs,
) -> Result(Nil, rpc_types.GleethError) {
  // Load wallet
  use w <- result.try(
    wallet.from_private_key_hex(args.private_key)
    |> result.map_error(fn(err) {
      rpc_types.ConfigError(
        "Invalid private key: " <> wallet.error_to_string(err),
      )
    }),
  )
  let sender = wallet.get_address(w)

  // Query chain ID
  use chain_id_hex <- result.try(methods.get_chain_id(rpc_url))
  use chain_id <- result.try(
    hex.to_int(chain_id_hex)
    |> result.map_error(fn(_) {
      rpc_types.ParseError("Failed to parse chain ID: " <> chain_id_hex)
    }),
  )

  // Query nonce
  use nonce <- result.try(methods.get_transaction_count(
    rpc_url,
    sender,
    "pending",
  ))

  let gas_limit = case args.gas_limit {
    "" -> "0x5208"
    gl -> gl
  }

  io.println("Sending transaction...")
  formatting.print_labeled_value("From", sender)
  formatting.print_labeled_value("To", args.to)
  formatting.print_labeled_value("Value", args.value)
  formatting.print_labeled_value("Nonce", nonce)
  formatting.print_labeled_value("Chain ID", int.to_string(chain_id))

  case args.legacy {
    True -> send_legacy(rpc_url, w, args, nonce, gas_limit, chain_id)
    False -> send_eip1559(rpc_url, w, args, nonce, gas_limit, chain_id)
  }
}

fn send_legacy(
  rpc_url: String,
  w: wallet.Wallet,
  args: SendArgs,
  nonce: String,
  gas_limit: String,
  chain_id: Int,
) -> Result(Nil, rpc_types.GleethError) {
  use gas_price <- result.try(methods.get_gas_price(rpc_url))
  formatting.print_labeled_value("Gas Price", gas_price)
  formatting.print_labeled_value("Type", "Legacy (Type 0)")
  io.println("")

  use tx <- result.try(
    transaction.create_legacy_transaction(
      args.to,
      args.value,
      gas_limit,
      gas_price,
      nonce,
      args.data,
      chain_id,
    )
    |> map_tx_error,
  )
  use signed <- result.try(transaction.sign_transaction(tx, w) |> map_tx_error)

  use tx_hash <- result.try(methods.send_raw_transaction(
    rpc_url,
    signed.raw_transaction,
  ))

  io.println("Transaction sent!")
  formatting.print_labeled_value("Hash", tx_hash)
  print_receipt(rpc_url, tx_hash)
}

fn send_eip1559(
  rpc_url: String,
  w: wallet.Wallet,
  args: SendArgs,
  nonce: String,
  gas_limit: String,
  chain_id: Int,
) -> Result(Nil, rpc_types.GleethError) {
  use max_fee <- result.try(methods.get_gas_price(rpc_url))
  use priority_fee <- result.try(methods.get_max_priority_fee(rpc_url))
  formatting.print_labeled_value("Max Fee", max_fee)
  formatting.print_labeled_value("Priority Fee", priority_fee)
  formatting.print_labeled_value("Type", "EIP-1559 (Type 2)")
  io.println("")

  use tx <- result.try(
    transaction.create_eip1559_transaction(
      args.to,
      args.value,
      gas_limit,
      max_fee,
      priority_fee,
      nonce,
      args.data,
      chain_id,
      [],
    )
    |> map_tx_error,
  )
  use signed <- result.try(
    transaction.sign_eip1559_transaction(tx, w) |> map_tx_error,
  )

  use tx_hash <- result.try(methods.send_raw_transaction(
    rpc_url,
    signed.raw_transaction,
  ))

  io.println("Transaction sent!")
  formatting.print_labeled_value("Hash", tx_hash)
  print_receipt(rpc_url, tx_hash)
}

fn print_receipt(
  rpc_url: String,
  tx_hash: eth_types.Hash,
) -> Result(Nil, rpc_types.GleethError) {
  use receipt <- result.try(methods.get_transaction_receipt(rpc_url, tx_hash))
  io.println("")
  io.println("Receipt:")
  formatting.print_labeled_value("Status", case receipt.status {
    eth_types.Success -> "Success"
    eth_types.Failed -> "Failed"
  })
  formatting.print_labeled_value("Block", receipt.block_number)
  formatting.print_labeled_value("Gas Used", receipt.gas_used)
  Ok(Nil)
}

fn map_tx_error(
  res: Result(a, transaction.TransactionError),
) -> Result(a, rpc_types.GleethError) {
  result.map_error(res, fn(err) {
    rpc_types.ConfigError(transaction.error_to_string(err))
  })
}
