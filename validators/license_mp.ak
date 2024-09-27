use aiken/collection/list
use bodega/types.{PubKeyHash}
use cardano/assets.{flatten}
use cardano/transaction.{Transaction}

pub type LicenseRedeemer {
  dead_line: ByteArray,
}

validator batcher_mp(admin_pkh: PubKeyHash) {
  mint(redeemer: LicenseRedeemer, policy_id: ByteArray, self: Transaction) {
    let Transaction { mint, extra_signatories, .. } = self
    list.has(extra_signatories, admin_pkh) && flatten(mint) == [
      (policy_id, redeemer.dead_line, 1),
    ]
  }

  else(_) {
    fail
  }
}
