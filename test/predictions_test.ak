use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Finite, Interval, IntervalBound}
use aiken/primitive/string
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

test spend_prediction__apply() {
  let params =
    PredictionParams {
      prediction_nft: Asset {
        policy_id: pred_nft_id,
        asset_name: pred_nft_name,
      },
      oracle_nft: Asset {
        policy_id: oracle_nft_id,
        asset_name: oracle_nft_name,
      },
      share_policy_id,
      usdm_asset: Asset { policy_id: usdm_id, asset_name: usdm_name },
      license_symbol,
      maximum_deadline_range: 1_000_000_000,
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
  let pos_user_pkh = #"d48838fee1e840857dab28a04dd88193aec8c297b85d8150c0a1f5cc"
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
