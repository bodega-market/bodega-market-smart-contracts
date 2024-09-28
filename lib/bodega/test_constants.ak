use bodega/types.{Asset}

pub const pred_nft_id =
  #"b5bab2940b09a2350d7814b3077822f622e740e3921812d6c58112bb"

pub const pred_nft_name = #"50524544494354494f4e5f4e4654"

pub const oracle_nft_id =
  #"d0042cba4453eeb32b8c3a3c6662c40895d35358182431f1b36e60a2"

pub const oracle_nft_name = #"323032345f454c454354494f4e5f4f5241434c455f4e4654"

pub const share_policy_id =
  #"a5ff2c36e9eeb9655d06c0a2f02d9e200aa6f8db00d760acf62c0eba"

pub const usdm_id = #"965f87c8322049a498f0803697298766e9e6b673c7ec120613048642"

pub const usdm_name = #"46414b455f5553444d"

pub const license_symbol =
  #"fded0503f223bab933388a77348f2722548ac6fa6a3fef5831c41b6c"

pub const true_position_name = #"5452554d50"

pub const false_position_name = #"484152524953"

pub const position_script_hash =
  #"308ffeb4f158771f82c4ea5948dcced9ff81dc5c74f74027257cfc03"

pub const maximum_deadline_range = 1_000_000_000

pub const pos_user_pkh =
  #"d48838fee1e840857dab28a04dd88193aec8c297b85d8150c0a1f5cc"

pub const treasury_script_hash =
  #"8193aec8c297b85d8150c0a1f5ccd48838fee1e840857dab28a04dd8"

pub const prediction_nft_asset =
  Asset { policy_id: pred_nft_id, asset_name: pred_nft_name }

pub const oracle_nft_asset =
  Asset { policy_id: oracle_nft_id, asset_name: oracle_nft_name }

pub const usdm_asset = Asset { policy_id: usdm_id, asset_name: usdm_name }
