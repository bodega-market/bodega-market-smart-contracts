use aiken/collection/dict
use aiken/collection/list
use aiken/interval
use bodega/test_constants.{
  false_position_name, pos_user_pkh, position_script_hash, pred_nft_id,
  pred_nft_name, prediction_nft_asset, share_policy_id, true_position_name,
  usdm_asset, usdm_id, usdm_name,
}
use bodega/types.{
  Asset, BuyPos, PositionDatum, PredictionDatum, SideFalse, SideTrue,
}
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
      pos_amount: 10,
      pos_batcher_fee: 300_000,
      pos_type: BuyPos,
      pos_side: SideTrue,
    }
  let pos_out =
    Output {
      address: from_script(position_script_hash),
      value: mint
        |> assets.add(usdm_id, usdm_name, 10)
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
  let params = ShareParams { usdm_asset, prediction_nft: prediction_nft_asset }
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
      pos_amount: 10,
      pos_batcher_fee: 300_000,
      pos_type: BuyPos,
      pos_side: SideFalse,
    }
  let pos_out =
    Output {
      address: from_script(position_script_hash),
      value: mint
        |> assets.add(usdm_id, usdm_name, 10)
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
  let params = ShareParams { usdm_asset, prediction_nft: prediction_nft_asset }
  let redeemer = Buy { pred_ref_idx: 0 }
  shares.mint(params, redeemer, share_policy_id, tx)
}
