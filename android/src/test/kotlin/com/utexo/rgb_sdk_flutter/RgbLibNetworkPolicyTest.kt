package com.utexo.rgb_sdk_flutter
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.test.assertFalse
internal class RgbLibNetworkPolicyTest {
 @Test fun hostedDevRequiresExplicitAdmissionAndPreservesPublicSignet() {
  assertEquals("signet",RgbLibNetworkPolicy.nativeNetwork("utexo"))
  assertEquals("signet",RgbLibNetworkPolicy.nativeNetwork("signet"))
  assertFalse(RgbLibNetworkPolicy.permitsOpen("utexo"))
  assertTrue(RgbLibNetworkPolicy.permitsOpen("utexo", "utexo-dev-busdt-20261109-v1"))
  assertFalse(RgbLibNetworkPolicy.permitsOpen("signet", "utexo-dev-busdt-20261109-v1"))
  assertTrue(RgbLibNetworkPolicy.permitsOpen("signet"))
  for(kind in listOf("devSignetElectrum","devSignetEsplora")) {
   assertEquals(kind,RgbLibNetworkPolicy.indexerKind("utexo",kind))
   assertNull(RgbLibNetworkPolicy.indexerKind("signet",kind))
  }
  for(kind in listOf("electrum","esplora","bitcoind")) {
   assertEquals(kind,RgbLibNetworkPolicy.indexerKind("signet",kind))
   assertNull(RgbLibNetworkPolicy.indexerKind("utexo",kind))
  }
 }
}
