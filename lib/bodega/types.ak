use aiken/crypto.{Blake2b_224, Hash, ScriptHash, VerificationKey}
use cardano/assets.{AssetName, PolicyId}

pub type PubKeyHash =
  Hash<Blake2b_224, VerificationKey>

pub type Asset {
  policy_id: PolicyId,
  asset_name: AssetName,
}

pub type PositionType {
  BuyPos
  RewardPos
}

pub type PositionSide {
  SideTrue
  SideFalse
}

pub type PositionRedeemer {
  pred_in_idx: Int,
}

pub type PositionDatum {
  pos_user_pkh: PubKeyHash,
  pos_user_stake_key: Option<PubKeyHash>,
  pos_amount: Int,
  pos_batcher_fee: Int,
  pos_type: PositionType,
  pos_side: PositionSide,
}

pub type PredictionDatum {
  true_position_name: ByteArray,
  false_position_name: ByteArray,
  dead_line: Int,
  true_position_amount: Int,
  false_position_amount: Int,
  position_script_hash: ScriptHash,
  admin_fee: Int,
  cur_total_fee: Int,
  envelope_amount: Int,
}

pub type PredictionParams {
  prediction_nft: Asset,
  oracle_nft: Asset,
  share_policy_id: PolicyId,
  payment_asset: Asset,
  license_symbol: PolicyId,
  maximum_deadline_range: Int,
  treasury_script_hash: ScriptHash,
}

pub type PredictionRedeemer {
  PredApply {
    own_input_idx: Int,
    own_output_idx: Int,
    license_idx: Int,
    pos_indices: List<(Int, Int)>,
  }
  PredReward {
    own_input_idx: Int,
    own_output_idx: Int,
    license_idx: Int,
    pos_indices: List<(Int, Int)>,
  }
  PredWithdrawAdminFee {
    own_input_idx: Int,
    own_output_idx: Int,
    license_idx: Int,
    treasury_out_idx: Int,
  }
}

pub type OracleDatum {
  position_name: ByteArray,
}
