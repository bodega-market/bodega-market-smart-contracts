use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Finite, Interval, IntervalBound}
use bodega/test_constants.{
  false_position_name, payment_asset, payment_asset__ada, payment_id,
  payment_name, pos_user_pkh, pos_user_stake_key,
  position_script_hash, pred_nft_id, pred_nft_name, prediction_nft_asset,
  share_policy_id, true_position_name,
}
use bodega/types.{
  Asset, BuyPos, PositionDatum, PredictionDatum, SideFalse, SideTrue,
}
use bodega/utils.{decimals, find_posix_time_range}
use cardano/address.{Address, Script, from_script}
use cardano/assets.{PolicyId, flatten}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}

pub type ShareRedeemer {
  Buy { pred_ref_idx: Int }
  Reward { pred_in_idx: Int }
}

pub type ShareParams {
  payment_asset: Asset,
  prediction_nft: Asset,
}

validator shares(params: ShareParams) {
  mint(redeemer: ShareRedeemer, policy_id: PolicyId, self: Transaction) {
    let Transaction {
      mint,
      inputs,
      reference_inputs,
      outputs,
      validity_range,
      ..
    } = self
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
        let (_start_valid_time_range, end_valid_time_range) =
          find_posix_time_range(validity_range)
        expect end_valid_time_range < pred_datum.dead_line
        let pos_script_cred = Script(pred_datum.position_script_hash)
        let pos_outputs =
          list.filter(
            outputs,
            fn(output) {
              let Output { address: Address { payment_credential, .. }, .. } =
                output
              payment_credential == pos_script_cred && assets.lovelace_of(
                output.value,
              ) >= pred_datum.admin_fee + pred_datum.envelope_amount
            },
          )
        expect [pos_output] = pos_outputs
        expect InlineDatum(pos_output_datum) = pos_output.datum
        expect pos_datum: PositionDatum = pos_output_datum
        expect pos_datum.pos_batcher_fee > 0 && pos_datum.pos_amount > 0
        let out_pos_lovelace = assets.lovelace_of(pos_output.value)
        let required_lovelace =
          pred_datum.admin_fee + pred_datum.envelope_amount + pos_datum.pos_batcher_fee
        let amount =
          when params.payment_asset.policy_id == assets.ada_policy_id is {
            True -> ( out_pos_lovelace - required_lovelace ) / decimals
            False ->
              assets.quantity_of(
                pos_output.value,
                params.payment_asset.policy_id,
                params.payment_asset.asset_name,
              ) / decimals
          }
        expect amount > 0
        when pos_datum.pos_side is {
          SideTrue ->
            assets.quantity_of(
              pos_output.value,
              policy_id,
              pred_datum.true_position_name,
            ) == amount && [(policy_id, pred_datum.true_position_name, amount)] == flatten_mint
          SideFalse ->
            assets.quantity_of(
              pos_output.value,
              policy_id,
              pred_datum.false_position_name,
            ) == amount && [(policy_id, pred_datum.false_position_name, amount)] == flatten_mint
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

test shares__mint_sidetrue() {
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
  let mint = assets.from_asset(share_policy_id, true_position_name, 10)
  let pos_datum =
    PositionDatum {
      pos_user_pkh,
      pos_user_stake_key: Some(pos_user_stake_key),
      pos_amount: 10,
      pos_batcher_fee: 300_000,
      pos_type: BuyPos,
      pos_side: SideTrue,
    }
  let pos_out =
    Output {
      address: from_script(position_script_hash),
      value: mint
        |> assets.add(payment_id, payment_name, 10 * decimals)
        |> assets.merge(assets.from_lovelace(2_500_000)),
      datum: InlineDatum(pos_datum),
      reference_script: None,
    }
  let tx =
    Transaction {
      inputs: [],
      reference_inputs: [pred_input],
      outputs: [pos_out],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let params =
    ShareParams { payment_asset, prediction_nft: prediction_nft_asset }
  let redeemer = Buy { pred_ref_idx: 0 }
  shares.mint(params, redeemer, share_policy_id, tx)
}

test shares__mint_sidefalse() {
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
  let mint = assets.from_asset(share_policy_id, false_position_name, 10)
  let pos_datum =
    PositionDatum {
      pos_user_pkh,
      pos_user_stake_key: Some(pos_user_stake_key),
      pos_amount: 10,
      pos_batcher_fee: 300_000,
      pos_type: BuyPos,
      pos_side: SideFalse,
    }
  let pos_out =
    Output {
      address: from_script(position_script_hash),
      value: mint
        |> assets.add(payment_id, payment_name, 10 * decimals)
        |> assets.merge(assets.from_lovelace(2_500_000)),
      datum: InlineDatum(pos_datum),
      reference_script: None,
    }
  let tx =
    Transaction {
      inputs: [],
      reference_inputs: [pred_input],
      outputs: [pos_out],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let params =
    ShareParams { payment_asset, prediction_nft: prediction_nft_asset }
  let redeemer = Buy { pred_ref_idx: 0 }
  shares.mint(params, redeemer, share_policy_id, tx)
}

test shares__mint_reward() {
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
  let mint = assets.from_asset(share_policy_id, false_position_name, -10)
  let tx =
    Transaction {
      inputs: [pred_input],
      reference_inputs: [],
      outputs: [],
      fee: 0,
      mint,
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
  let params =
    ShareParams { payment_asset, prediction_nft: prediction_nft_asset }
  let redeemer = Reward { pred_in_idx: 0 }
  shares.mint(params, redeemer, share_policy_id, tx)
}

test shares__mint_sidetrue_ada_payment() {
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
  let mint = assets.from_asset(share_policy_id, true_position_name, 10)
  let pos_datum =
    PositionDatum {
      pos_user_pkh,
      pos_user_stake_key: Some(pos_user_stake_key),
      pos_amount: 10,
      pos_batcher_fee: 300_000,
      pos_type: BuyPos,
      pos_side: SideTrue,
    }
  let pos_out =
    Output {
      address: from_script(position_script_hash),
      value: mint
        |> assets.merge(assets.from_lovelace(2_500_000))
        |> assets.merge(assets.from_lovelace(10 * decimals)),
      datum: InlineDatum(pos_datum),
      reference_script: None,
    }
  let tx =
    Transaction {
      inputs: [],
      reference_inputs: [pred_input],
      outputs: [pos_out],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let params =
    ShareParams {
      payment_asset: payment_asset__ada,
      prediction_nft: prediction_nft_asset,
    }
  let redeemer = Buy { pred_ref_idx: 0 }
  shares.mint(params, redeemer, share_policy_id, tx)
}

test shares__mint_sidefalse_ada_payment() {
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
  let mint = assets.from_asset(share_policy_id, false_position_name, 10)
  let pos_datum =
    PositionDatum {
      pos_user_pkh,
      pos_user_stake_key: Some(pos_user_stake_key),
      pos_amount: 10,
      pos_batcher_fee: 300_000,
      pos_type: BuyPos,
      pos_side: SideFalse,
    }
  let pos_out =
    Output {
      address: from_script(position_script_hash),
      value: mint
        |> assets.merge(assets.from_lovelace(2_500_000))
        |> assets.merge(assets.from_lovelace(10 * decimals)),
      datum: InlineDatum(pos_datum),
      reference_script: None,
    }
  let tx =
    Transaction {
      inputs: [],
      reference_inputs: [pred_input],
      outputs: [pos_out],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let params =
    ShareParams {
      payment_asset: payment_asset__ada,
      prediction_nft: prediction_nft_asset,
    }
  let redeemer = Buy { pred_ref_idx: 0 }
  shares.mint(params, redeemer, share_policy_id, tx)
}
