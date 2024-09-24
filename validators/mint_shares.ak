use aiken/collection/list
use bodega/types.{Asset, PositionDatum, PredictionDatum, SideFalse, SideTrue}
use cardano/address.{Address, Script}
use cardano/assets.{PolicyId, flatten}
use cardano/transaction.{InlineDatum, Output, Transaction}

pub type ShareRedeemer {
  Buy { pred_ref_idx: Int }
  Reward { pred_in_idx: Int }
}

pub type ShareParams {
  usdm_asset: Asset,
  prediction_nft: Asset,
}

validator shares(params: ShareParams) {
  mint(redeemer: ShareRedeemer, policy_id: PolicyId, self: Transaction) {
    let Transaction { mint, inputs, reference_inputs, outputs, .. } = self
    let flatten_mint = flatten(mint)
    when redeemer is {
      Buy { pred_ref_idx } -> {
        expect Some(pred_ref_input) = list.at(reference_inputs, pred_ref_idx)
        expect
          assets.quantity_of(
            pred_ref_input.output.value,
            params.prediction_nft.policy_id,
            params.prediction_nft.asset_name,
          ) == 1
        expect InlineDatum(pred_output_datum) = pred_ref_input.output.datum
        expect pred_datum: PredictionDatum = pred_output_datum
        let pos_script_cred = Script(pred_datum.position_script_hash)
        let pos_outputs =
          list.filter(
            outputs,
            fn(output) {
              let Output { address: Address { payment_credential, .. }, .. } =
                output
              payment_credential == pos_script_cred && assets.quantity_of(
                output.value,
                assets.ada_policy_id,
                assets.ada_asset_name,
              ) >= pred_datum.admin_fee + pred_datum.envelope_amount
            },
          )
        expect [pos_output] = pos_outputs
        expect InlineDatum(pos_output_datum) = pos_output.datum
        expect pos_datum: PositionDatum = pos_output_datum
        expect pos_datum.pos_batcher_fee > 0 && pos_datum.pos_amount > 0
        let amount =
          assets.quantity_of(
            pos_output.value,
            params.usdm_asset.policy_id,
            params.usdm_asset.asset_name,
          )
        expect amount != 0
        when pos_datum.pos_side is {
          SideTrue ->
            [(policy_id, pred_datum.true_position_name, amount)] == flatten_mint
          SideFalse ->
            [(policy_id, pred_datum.false_position_name, amount)] == flatten_mint
        }
      }
      Reward { pred_in_idx } -> {
        expect Some(pred_input) = list.at(inputs, pred_in_idx)
        assets.quantity_of(
          pred_input.output.value,
          params.prediction_nft.policy_id,
          params.prediction_nft.asset_name,
        ) == 1
      }
    }
  }

  else(_) {
    fail
  }
}
