/// Reviewed native-source dispositions, independent of Pub vulnerability checks.
/// A new binary/source pin requires a fresh native dependency and funds-safety
/// review; absence of a known finding is never treated as proof of closure.
List<String> nativeProductionBlockers(String sourceCommit) {
  if (sourceCommit != 'ecc69f20308231400561f6f060fea88acfa40cc4') {
    return const [
      'Native source has no approved production security disposition. Review the exact native dependency graph and on-chain correctness fixes.',
    ];
  }
  return const [
    'P03: pinned native RGB refresh does not roll settled transfers back after a reorg. A corrected native artifact and reorg/reconfirmation evidence are required.',
    'P04: pinned native amount-bound Witness pending accounting can double count a receipt. A corrected native artifact and accounting evidence are required.',
    'P06: pinned BFA consensus can reject a valid backing event after an earlier wrong-amount event. A corrected native artifact and event-order regression evidence are required.',
    'Native TLS: selected minreq 2.14.1 -> rustls 0.21.12 -> rustls-webpki 0.101.7 has unresolved RUSTSEC-2026-0098/0099 certificate name-constraint advisories. RUSTSEC-2026-0104 CRL reachability is unproven; no-CRL callers are unaffected. Adopt a fixed native graph or an independently reviewed security disposition.',
  ];
}

/// RGB_L1 is a separate Rust graph and cannot inherit RLN's disposition.
List<String> rgbLibProductionBlockers(Object? lockSha256) {
  if (lockSha256 ==
          '4b675f6187e069e6236033415ff157379b039717b387a1dd596669ec52f6a21f' ||
      lockSha256 ==
          '81af7c87fac88abbd40b1621ce2fa7655165b6b0c8bdd23faa313d25139330a6') {
    return const [
      'RGB_L1 BFA.7: the exact patched UniFFI lock has zero known vulnerabilities and zero unsound notices at RustSec 309392b18f6b17022f82c701f300433126901068. Three unmaintained dependencies remain (basic-toml, bincode, unsafe-libyaml); maintain their exact-graph disposition and review future advisories. Native funded/platform, reorg, backup-freshness and signed-archive privacy qualification remain required; RGB_L1 is not production approved.',
    ];
  }
  if (lockSha256 !=
      '68a48cc0d37e0c6777871d7c5780e92752a3abdaf5b9cae9b0e16807888bb290') {
    return const [
      'RGB_L1 native source lock has no approved production security disposition.',
    ];
  }
  return const [
    'RGB_L1 BFA.5: the exact UniFFI lock has nine RustSec advisories, including legacy TLS, ctutils and Tokio. Patch the dependency graph or approve reachability evidence for the exact artifacts before production.',
  ];
}
