use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Finite, Interval, IntervalBound}
use aiken/primitive/string
use bodega/test_constants.{
  false_position_name, license_symbol, maximum_deadline_range, oracle_nft_asset,
  pos_user_pkh, position_script_hash, pred_nft_id, pred_nft_name,
  prediction_nft_asset, share_policy_id, true_position_name, usdm_asset, usdm_id,
  usdm_name,
}
use bodega/types.{
  Asset, BuyPos, OracleDatum, PositionDatum, PredApply, PredReward,
  PredUpdateSetting, PredWithdrawAdminFee, PredictionDatum, PredictionParams,
  PredictionRedeemer, SideTrue,
}
use bodega/utils.{find_license_deadline, find_posix_time_range}
use cardano/address.{from_script, from_verification_key}
use cardano/assets.{flatten}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}

validator predictions(params: PredictionParams) {
  spend(
    option_datum: Option<PredictionDatum>,
    redeemer: PredictionRedeemer,
    _own_ref: OutputReference,
    self: Transaction,
  ) {
    expect Some(datum) = option_datum
    let own_input_datum: PredictionDatum = datum
    when redeemer is {
      PredApply { own_input_idx, own_output_idx, license_idx, pos_indices } -> {
        let Transaction { inputs, outputs, validity_range, .. } = self
        expect Some(Input { output: Output { value: batcher_value, .. }, .. }) =
          list.at(inputs, license_idx)
        let license_deadline =
          find_license_deadline(params.license_symbol, batcher_value)
        let (start_valid_time_range, end_valid_time_range) =
          find_posix_time_range(validity_range)
        expect and {
            license_deadline >= end_valid_time_range,
            license_deadline <= start_valid_time_range + params.maximum_deadline_range,
          }
        expect Some(own_input) = list.at(inputs, own_input_idx)
        expect Some(own_output) = list.at(outputs, own_output_idx)
        expect InlineDatum(own_output_inline_datum) = own_output.datum
        expect own_output_datum: PredictionDatum = own_output_inline_datum
        expect
          assets.quantity_of(
            own_input.output.value,
            params.prediction_nft.policy_id,
            params.prediction_nft.asset_name,
          ) == 1
        expect
          assets.quantity_of(
            own_output.value,
            params.prediction_nft.policy_id,
            params.prediction_nft.asset_name,
          ) == 1
        let (true_shares, false_shares, batch_size, are_correct_positions) =
          list.foldl(
            pos_indices,
            (0, 0, 0, True),
            fn(curr, acc) {
              let (in_idx, out_idx) = curr
              let (num_true, num_false, bs, are_correct) = acc
              expect Some(in) = list.at(inputs, in_idx)
              expect Some(out) = list.at(outputs, out_idx)
              expect InlineDatum(pos_inline_datum) = in.output.datum
              expect pos_datum: PositionDatum = pos_inline_datum
              expect
                from_verification_key(pos_datum.pos_user_pkh) == out.address
              let num_true_shares =
                assets.quantity_of(
                  in.output.value,
                  params.share_policy_id,
                  own_input_datum.true_position_name,
                )
              let num_false_shares =
                assets.quantity_of(
                  in.output.value,
                  params.share_policy_id,
                  own_input_datum.false_position_name,
                )
              if num_true_shares > 0 {
                expect
                  [
                    (
                      assets.ada_policy_id,
                      assets.ada_asset_name,
                      own_output_datum.envelope_amount,
                    ),
                    (
                      params.share_policy_id,
                      own_input_datum.true_position_name,
                      num_true_shares,
                    ),
                  ] == assets.flatten(out.value)
              } else {
                expect
                  [
                    (
                      assets.ada_policy_id,
                      assets.ada_asset_name,
                      own_output_datum.envelope_amount,
                    ),
                    (
                      params.share_policy_id,
                      own_input_datum.false_position_name,
                      num_false_shares,
                    ),
                  ] == assets.flatten(out.value)
              }

              expect
                num_true_shares == assets.quantity_of(
                  out.value,
                  params.share_policy_id,
                  own_input_datum.true_position_name,
                )
              expect
                num_false_shares == assets.quantity_of(
                  out.value,
                  params.share_policy_id,
                  own_input_datum.false_position_name,
                )
              let num_out_assets = list.length(assets.flatten(out.value))
              (
                num_true + num_true_shares,
                num_false + num_false_shares,
                bs + 1,
                num_out_assets == 2 && are_correct,
              )
            },
          )
        let flatten_own_output_value = assets.flatten(own_output.value)
        expect list.length(flatten_own_output_value) <= 3
        let input_usdm =
          assets.quantity_of(
            own_input.output.value,
            params.usdm_asset.policy_id,
            params.usdm_asset.asset_name,
          )
        let output_usdm =
          assets.quantity_of(
            own_output.value,
            params.usdm_asset.policy_id,
            params.usdm_asset.asset_name,
          )
        let input_lovelace =
          assets.quantity_of(
            own_input.output.value,
            assets.ada_policy_id,
            assets.ada_asset_name,
          )
        let output_lovelace =
          assets.quantity_of(
            own_output.value,
            assets.ada_policy_id,
            assets.ada_asset_name,
          )
        expect input_usdm + true_shares + false_shares <= output_usdm
        expect
          input_lovelace + batch_size * own_input_datum.admin_fee <= output_lovelace
        expect
          own_input_datum.true_position_amount + true_shares == own_output_datum.true_position_amount
        expect
          own_input_datum.false_position_amount + false_shares == own_output_datum.false_position_amount

        correct_own_output_datum(own_input_datum, own_output_datum) && own_input.output.address == own_output.address && are_correct_positions
      }
      PredReward { own_input_idx, own_output_idx, license_idx, pos_indices } -> {
        let Transaction {
          inputs,
          outputs,
          mint,
          reference_inputs,
          validity_range,
          ..
        } = self
        expect Some(own_input) = list.at(inputs, own_input_idx)
        expect Some(own_output) = list.at(outputs, own_output_idx)
        expect Some(Input { output: Output { value: batcher_value, .. }, .. }) =
          list.at(inputs, license_idx)
        let license_deadline =
          find_license_deadline(params.license_symbol, batcher_value)
        let (start_valid_time_range, end_valid_time_range) =
          find_posix_time_range(validity_range)
        expect and {
            license_deadline >= end_valid_time_range,
            license_deadline <= start_valid_time_range + params.maximum_deadline_range,
          }
        expect InlineDatum(own_output_inline_datum) = own_output.datum
        expect own_output_datum: PredictionDatum = own_output_inline_datum
        expect
          assets.quantity_of(
            own_input.output.value,
            params.prediction_nft.policy_id,
            params.prediction_nft.asset_name,
          ) == 1
        expect
          assets.quantity_of(
            own_output.value,
            params.prediction_nft.policy_id,
            params.prediction_nft.asset_name,
          ) == 1
        expect Some(oracle_ref_input) =
          reference_inputs
            |> list.find(
                fn(input) {
                  assets.quantity_of(
                    input.output.value,
                    params.oracle_nft.policy_id,
                    params.oracle_nft.asset_name,
                  ) == 1
                },
              )
        expect InlineDatum(oracle_inline_datum) = oracle_ref_input.output.datum
        expect oracle_datum: OracleDatum = oracle_inline_datum
        let (total_winning, total_losing) =
          if oracle_datum.position_name == own_output_datum.true_position_name {
            (
              own_output_datum.true_position_amount,
              own_output_datum.false_position_amount,
            )
          } else {
            (
              own_output_datum.false_position_amount,
              own_output_datum.true_position_amount,
            )
          }
        let (num_shares, does_reward_correctly) =
          list.foldl(
            pos_indices,
            (0, True),
            fn(curr, acc) {
              let (in_idx, out_idx) = curr
              let (ns, reward_correctly) = acc
              expect Some(in) = list.at(inputs, in_idx)
              expect Some(out) = list.at(outputs, out_idx)
              expect InlineDatum(pos_inline_datum) = in.output.datum
              expect pos_datum: PositionDatum = pos_inline_datum
              expect
                from_verification_key(pos_datum.pos_user_pkh) == out.address
              let curr_shares =
                assets.quantity_of(
                  in.output.value,
                  params.share_policy_id,
                  oracle_datum.position_name,
                )
              expect curr_shares > 0
              let reward_amount =
                curr_shares + curr_shares / total_winning * total_losing
              (
                ns + curr_shares,
                reward_correctly && assets.quantity_of(
                  out.value,
                  params.usdm_asset.policy_id,
                  params.usdm_asset.asset_name,
                ) == reward_amount,
              )
            },
          )
        let input_usdm =
          assets.quantity_of(
            own_input.output.value,
            params.usdm_asset.policy_id,
            params.usdm_asset.asset_name,
          )
        let output_usdm =
          assets.quantity_of(
            own_output.value,
            params.usdm_asset.policy_id,
            params.usdm_asset.asset_name,
          )
        let input_lovelace =
          assets.quantity_of(
            own_input.output.value,
            assets.ada_policy_id,
            assets.ada_asset_name,
          )
        let output_lovelace =
          assets.quantity_of(
            own_output.value,
            assets.ada_policy_id,
            assets.ada_asset_name,
          )
        expect input_usdm == output_usdm + num_shares
        expect input_lovelace <= output_lovelace
        expect
          [(params.share_policy_id, oracle_datum.position_name, -num_shares)] == flatten(
            mint,
          )
        does_reward_correctly
      }
      PredWithdrawAdminFee -> False
      PredUpdateSetting -> False
    }
  }

  else(_) {
    fail
  }
}

fn correct_own_output_datum(
  in_datum: PredictionDatum,
  out_datum: PredictionDatum,
) -> Bool {
  in_datum.true_position_name == out_datum.true_position_name && in_datum.false_position_name == out_datum.false_position_name && in_datum.dead_line == out_datum.dead_line && in_datum.position_script_hash == out_datum.position_script_hash && in_datum.admin_fee == out_datum.admin_fee && in_datum.envelope_amount == out_datum.envelope_amount
}

test predictions__spend_apply() {
  let params =
    PredictionParams {
      prediction_nft: prediction_nft_asset,
      oracle_nft: oracle_nft_asset,
      share_policy_id,
      usdm_asset,
      license_symbol,
      maximum_deadline_range,
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
  let pred_out_datum =
    PredictionDatum {
      true_position_name,
      false_position_name,
      dead_line: 1730394000000,
      true_position_amount: 10,
      false_position_amount: 0,
      position_script_hash,
      admin_fee: 200_000,
      envelope_amount: 2_000_000,
    }
  let pred_out =
    Output {
      address: from_script(#""),
      value: assets.from_lovelace(2_200_000)
        |> assets.add(pred_nft_id, pred_nft_name, 1)
        |> assets.add(usdm_id, usdm_name, 10),
      datum: InlineDatum(pred_out_datum),
      reference_script: None,
    }
  let pos_datum =
    PositionDatum {
      pos_user_pkh,
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
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(share_policy_id, true_position_name, 10)
          |> assets.add(usdm_id, usdm_name, 10),
        datum: InlineDatum(pos_datum),
        reference_script: None,
      },
    }
  let user_pos_out =
    Output {
      address: from_verification_key(pos_user_pkh),
      value: assets.from_lovelace(2_000_000)
        |> assets.add(share_policy_id, true_position_name, 10),
      datum: InlineDatum(pos_datum),
      reference_script: None,
    }
  let license_input =
    Input {
      output_reference: OutputReference {
        transaction_id: #"07f157faf99b850b4971034feee28d",
        output_index: 0,
      },
      output: Output {
        address: from_script(#"12"),
        value: assets.add(
          assets.zero,
          license_symbol,
          string.to_bytearray(@"1727715600000"),
          1,
        ),
        datum: NoDatum,
        reference_script: None,
      },
    }
  let license_output =
    Output {
      address: from_script(#"12"),
      value: assets.add(
        assets.zero,
        license_symbol,
        string.to_bytearray(@"1727715600000"),
        1,
      ),
      datum: NoDatum,
      reference_script: None,
    }
  let pred_ref_outref =
    OutputReference {
      transaction_id: #"f99b850b4971034feee28d07f157fa",
      output_index: 0,
    }
  let pred_ref_input =
    Input {
      output_reference: pred_ref_outref,
      output: Output {
        address: from_script(#"13"),
        value: assets.from_lovelace(2_000_000),
        datum: NoDatum,
        reference_script: Some(#""),
      },
    }
  let tx =
    Transaction {
      inputs: [pred_input, pos_input, license_input],
      reference_inputs: [pred_ref_input],
      outputs: [pred_out, user_pos_out, license_output],
      fee: 0,
      mint: assets.zero,
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
  let pred_redeemer =
    PredApply {
      own_input_idx: 0,
      own_output_idx: 0,
      license_idx: 2,
      pos_indices: [(1, 1)],
    }
  predictions.spend(params, Some(pred_datum), pred_redeemer, own_ref, tx)
}
