use aiken/collection/dict
use aiken/collection/list
use aiken/interval
use bodega/test_constants.{
  false_position_name, payment_id, payment_name, pos_user_pkh,
  pos_user_stake_key, position_script_hash, pred_nft_id, pred_nft_name,
  prediction_nft_asset, share_policy_id, true_position_name, user_address_test,
}
use bodega/types.{
  Asset, BuyPos, PositionDatum, PositionRedeemer, PredictionDatum, SideTrue,
}
use cardano/address.{from_script}
use cardano/assets
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}

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

test positions__spend() {
  let pos_datum =
    PositionDatum {
      pos_user_pkh,
      pos_user_stake_key: Some(pos_user_stake_key),
      pos_amount: 10,
      pos_batcher_fee: 300_000,
      pos_type: BuyPos,
      pos_side: SideTrue,
    }
  let pos_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let pos_input =
    Input {
      output_reference: pos_ref,
      output: Output {
        address: user_address_test,
        value: assets.zero
          |> assets.add(share_policy_id, true_position_name, 10)
          |> assets.add(payment_id, payment_name, 10),
        datum: InlineDatum(pos_datum),
        reference_script: None,
      },
    }
  let pred_datum =
    PredictionDatum {
      true_position_name,
      false_position_name,
      dead_line: 1730394000000,
      true_position_amount: 0,
      false_position_amount: 0,
      position_script_hash,
      admin_fee: 200_000,
      cur_total_fee: 0,
      envelope_amount: 2_000_000,
    }
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }
  let pred_input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_script(#""),
        value: assets.from_lovelace(2_000_000)
          |> assets.add(pred_nft_id, pred_nft_name, 1),
        datum: InlineDatum(pred_datum),
        reference_script: None,
      },
    }
  let pos_redeemer = PositionRedeemer { pred_in_idx: 0 }
  let tx =
    Transaction {
      inputs: [pred_input, pos_input],
      reference_inputs: [],
      outputs: [],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: interval.everything,
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  positions.spend(prediction_nft_asset, None, pos_redeemer, pos_ref, tx)
}
