use aiken/collection/list
use cardano/assets.{flatten}
use cardano/transaction.{OutputReference, Transaction}

validator pred_nft_mp(seed: OutputReference) {
  mint(_redeemer: Data, policy_id: ByteArray, self: Transaction) {
    let Transaction { inputs, mint, .. } = self
    expect list.any(inputs, fn(inp) { inp.output_reference == seed })

    flatten(mint) == [(policy_id, "PREDICTION_NFT", 1)]
  }

  else(_) {
    fail
  }
}
