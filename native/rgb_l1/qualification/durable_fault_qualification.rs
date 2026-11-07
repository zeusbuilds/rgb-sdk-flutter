//! Regression tests injected only into a sealed-source test copy.
//! Local HTTP responses exercise observation decisions; they do not claim a live reorg.
use super::*;
use bdk_wallet::bitcoin::{
    Amount, OutPoint, ScriptBuf, Sequence, TxIn, TxOut, Witness, absolute, transaction,
};

#[derive(Clone, Copy, Debug)]
enum View {
    Confirmed { height: u32, tip: u32 },
    Mempool,
    Absent,
    StatusUnavailable,
    StatusMalformed,
    RawUnavailable,
}

fn transaction_with_witness() -> BdkTransaction {
    BdkTransaction {
        version: transaction::Version::TWO,
        lock_time: absolute::LockTime::ZERO,
        input: vec![TxIn {
            previous_output: OutPoint { txid: "11".repeat(32).parse().unwrap(), vout: 1 },
            script_sig: ScriptBuf::new(),
            sequence: Sequence::ENABLE_RBF_NO_LOCKTIME,
            witness: Witness::from_slice(&[b"exact-native-witness"]),
        }],
        output: vec![TxOut { value: Amount::from_sat(1500), script_pubkey: ScriptBuf::new() }],
    }
}

/// The only network surface is an ephemeral local mock server. Every POST is forbidden.
fn observe(expected: &BdkTransaction, raw: &BdkTransaction, view: View) -> Result<bool, Error> {
    let mut server = mockito::Server::new();
    let txid = expected.compute_txid().to_string();
    let status_path = format!("/tx/{txid}/status");
    let raw_path = format!("/tx/{txid}/raw");
    let writes = server.mock("POST", mockito::Matcher::Any).expect(0).create();
    let status = match view {
        View::StatusUnavailable => server.mock("GET", status_path.as_str()).with_status(503),
        View::StatusMalformed => server.mock("GET", status_path.as_str()).with_status(200).with_body("{incomplete"),
        View::Confirmed { height, .. } => server.mock("GET", status_path.as_str())
            .with_status(200).with_body(serde_json::json!({"confirmed":true,"block_height":height,
                "block_hash":"22".repeat(32),"block_time":1700000000}).to_string()),
        View::RawUnavailable => server.mock("GET", status_path.as_str()).with_status(200)
            .with_body(serde_json::json!({"confirmed":true,"block_height":10,
                "block_hash":"22".repeat(32),"block_time":1700000000}).to_string()),
        View::Mempool | View::Absent => server.mock("GET", status_path.as_str()).with_status(200)
            .with_body("{\"confirmed\":false}"),
    }.expect(1).create();
    let height = match view {
        View::Confirmed { tip, .. } => Some(server.mock("GET", "/blocks/tip/height")
            .with_status(200).with_body(tip.to_string()).expect(1).create()),
        View::RawUnavailable => Some(server.mock("GET", "/blocks/tip/height")
            .with_status(200).with_body("12").expect(1).create()),
        _ => None,
    };
    let raw_calls = match view {
        View::Mempool => 2,
        View::Confirmed { height, tip } if height <= tip => 1,
        View::Absent | View::RawUnavailable => 1,
        _ => 0,
    };
    let raw_mock = server.mock("GET", raw_path.as_str());
    let raw_mock = match view {
        View::Absent => raw_mock.with_status(404),
        View::RawUnavailable => raw_mock.with_status(503),
        _ => raw_mock.with_status(200).with_body(bdk_wallet::bitcoin::consensus::serialize(raw)),
    }.expect(raw_calls).create();
    let indexer = Indexer::Esplora(Box::new(EsploraClient::from_builder(
        EsploraBuilder::new(&server.url()).max_retries(0).timeout(1),
    )));
    let result = exact_chain_transaction(&indexer, expected);
    status.assert();
    if let Some(height) = height { height.assert(); }
    raw_mock.assert();
    writes.assert();
    result
}

#[test]
fn exact_mempool_submission_is_positive_proof_without_claiming_confirmation() {
    let tx = transaction_with_witness();
    assert!(observe(&tx, &tx, View::Mempool).unwrap());
}

#[test]
fn exact_confirmed_submission_is_positive_proof() {
    let tx = transaction_with_witness();
    assert!(observe(&tx, &tx, View::Confirmed { height: 100, tip: 102 }).unwrap());
}

#[test]
fn absent_unavailable_and_malformed_observations_never_certify_nonexecution() {
    let tx = transaction_with_witness();
    for view in [View::Absent, View::StatusUnavailable, View::StatusMalformed, View::RawUnavailable] {
        assert!(!observe(&tx, &tx, view).unwrap(), "view {view:?} must remain unknown");
    }
}

#[test]
fn reorg_between_height_reads_is_unknown_instead_of_unsigned_confirmation_underflow() {
    let tx = transaction_with_witness();
    assert!(!observe(&tx, &tx, View::Confirmed { height: 103, tip: 102 }).unwrap());
}

#[test]
fn proof_requires_exact_signed_bytes_even_when_txid_matches() {
    let expected = transaction_with_witness();
    let mut substituted = expected.clone();
    substituted.input[0].witness = Witness::from_slice(&[b"other-witness"]);
    assert_eq!(expected.compute_txid(), substituted.compute_txid());
    assert_ne!(expected.compute_wtxid(), substituted.compute_wtxid());
    assert!(matches!(observe(&expected, &substituted, View::Confirmed { height: 100, tip: 102 }),
        Err(Error::Recovery { code }) if code == "RECOVERY_OBSERVATION_INVALID"));
}

#[test]
fn a_different_transaction_returned_under_the_expected_txid_is_rejected() {
    let expected = transaction_with_witness();
    let mut substituted = expected.clone();
    substituted.output[0].value = Amount::from_sat(1501);
    assert_ne!(expected.compute_txid(), substituted.compute_txid());
    assert!(matches!(observe(&expected, &substituted, View::Confirmed { height: 100, tip: 102 }),
        Err(Error::Recovery { code }) if code == "RECOVERY_OBSERVATION_INVALID"));
}

#[test]
fn observation_can_follow_confirmation_loss_and_reconfirmation_without_a_write() {
    let tx = transaction_with_witness();
    for (view, positive) in [
        (View::Confirmed { height: 100, tip: 102 }, true),
        (View::Mempool, true),
        (View::Absent, false),
        (View::StatusUnavailable, false),
        (View::Confirmed { height: 104, tip: 106 }, true),
    ] {
        assert_eq!(observe(&tx, &tx, view).unwrap(), positive, "view {view:?}");
    }
}

#[test]
fn recipient_ack_cannot_cross_wallet_transfer_or_consignment_boundaries() {
    let sender = ed25519_from_seed(&[7u8; 32]);
    let foreign = ed25519_from_seed(&[8u8; 32]);
    let recipient = LocalRecipient {
        recipient_id: "test-invoice".into(),
        local_recipient_data: LocalRecipientData::Witness(LocalWitnessData { amount_sat:1000, blinding:None, vout:0 }),
        assignment: Assignment::Fungible(1), transport_endpoints:vec![],
        public_key:sender.verifying_key().to_bytes().to_vec(), encryption:Encryption::Required,
        invoice_expiration:None,
    };
    let hash = "ab".repeat(32);
    let message = sha256_digest(format!("transfertrue{hash}").as_bytes());
    for signature in [
        hex::encode(sign_ed25519(&foreign, &message)),
        hex::encode(sign_ed25519(&sender, &sha256_digest(format!("transferfalse{hash}").as_bytes()))),
        "00".repeat(63),
        "not-hex".into(),
    ] {
        let response = GetAckResponse { acks:HashMap::from([("transfer".into(),true)]),
            signatures:HashMap::from([("transfer".into(),signature)]) };
        assert!(verified_ack(&response, &recipient, "transfer", &hash).is_none());
    }
}
