use aiken/collection/list
use bodega/types.{Asset, PositionDatum, PositionRedeemer}
use cardano/assets
use cardano/transaction.{OutputReference, Transaction}

validator positions(prediction_nft: Asset) {
  spend(
    _datum: Option<PositionDatum>,
    redeemer: PositionRedeemer,
    _own_ref: OutputReference,
    self: Transaction,
  ) {
    let Transaction { inputs, .. } = self
    expect Some(pred_input) = list.at(inputs, redeemer.pred_in_idx)
    assets.quantity_of(
      pred_input.output.value,
      prediction_nft.policy_id,
      prediction_nft.asset_name,
    ) == 1
  }

  else(_) {
    fail
  }
}
