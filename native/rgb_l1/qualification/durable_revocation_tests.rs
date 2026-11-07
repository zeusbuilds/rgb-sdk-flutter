mod revocation_qualification {
    use super::*;
    use bdk_wallet::bitcoin::{Amount, OutPoint, ScriptBuf, Sequence, TxIn, TxOut, Witness, absolute, transaction};

    fn reply(result: Value, error: Value) -> JsonRpcResponse<bool> {
        serde_json::from_value(json!({"jsonrpc":"2.0","id":"test","result":result,"error":error})).unwrap()
    }

    #[test]
    fn revocation_requires_affirmative_success_not_false_null_or_an_error() {
        assert_eq!(durable_revocation_response(reply(json!(true), Value::Null)), DurableRevocation::Revoked);
        for result in [json!(false), Value::Null] {
            assert_eq!(durable_revocation_response(reply(result, Value::Null)), DurableRevocation::Unknown);
        }
        for code in [-104, -502, -500] {
            assert_eq!(durable_revocation_response(reply(json!(true), json!({"code":code,"message":"test"}))), DurableRevocation::Unknown);
        }
        assert_eq!(durable_revocation_response(reply(json!(true), json!({"code":-107,"message":"released"}))), DurableRevocation::Released);
    }

    #[test]
    fn legacy_journal_mac_stays_identical_when_the_new_certificate_is_absent() {
        let (_root, wallet, _) = setup();
        let store = Store::open(&wallet, false).unwrap();
        let mut outbox = store.read(&wallet).unwrap();
        outbox.records.push(Record::new(command(&wallet, &"e1".repeat(16))));
        store.write(&outbox).unwrap();
        let raw = fs::read(current_file(&wallet)).unwrap();
        assert!(!String::from_utf8(raw.clone()).unwrap().contains("revocationConfirmed"));
        let decoded: Outbox = serde_json::from_slice(&raw).unwrap();
        assert!(!decoded.records[0].revocation_confirmed);
        assert_eq!(serde_json::to_vec(&decoded).unwrap(), raw);
        store.authenticate(&decoded).unwrap();
        assert_eq!(store.read(&wallet).unwrap().records[0].phase, Phase::Preparing);
    }

    fn dispatched_rgb(wallet: &Wallet) -> Record {
        let mut e = command(wallet, &"e2".repeat(16));
        e.request.kind = Kind::Rgb;
        e.request.address = None;
        e.request.asset_id = Some("rgb:A6k89KtR-e3oXqRP-uH3jUrz-LU_sYL3-hMZ0k3O-6u8DXbE".into());
        e.request.recipient_id = Some("native-test-recipient".into());
        e.request.transport_endpoints = vec!["rpc://127.0.0.1:49790/json-rpc".into()];
        e.request.sender_transport_endpoint = Some("rpc://127.0.0.1:49790/json-rpc".into());
        e.request.witness_amount_sat = Some("1000".into());
        e.request.expiration_timestamp = Some("2000000000".into());
        e.request.invoice_public_key = Some("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a".into());
        e.request.invoice_encryption = Some("Required".into());
        e.request.min_confirmations = 3;
        e.request.fingerprint.clear();
        e.request.fingerprint = sha256::Hash::hash(&serde_json::to_vec(&e).unwrap()).to_string();
        e.validate().unwrap();
        let transaction = BdkTransaction {
            version: transaction::Version::TWO, lock_time: absolute::LockTime::ZERO,
            input: vec![TxIn { previous_output: OutPoint { txid:"11".repeat(32).parse().unwrap(),vout:0 },
                script_sig:ScriptBuf::new(), sequence:Sequence::ENABLE_RBF_NO_LOCKTIME, witness:Witness::default() }],
            output:vec![TxOut { value:Amount::from_sat(1000),script_pubkey:ScriptBuf::new() }],
        };
        let mut unsigned = Psbt::from_unsigned_tx(transaction).unwrap();
        unsigned.inputs[0].witness_utxo = Some(TxOut { value:Amount::from_sat(2000),script_pubkey:ScriptBuf::new() });
        let mut signed = unsigned.clone();
        signed.inputs[0].final_script_witness = Some(Witness::from_slice(&[b"test-only-final-witness"]));
        let mut r = Record::new(e);
        r.phase = Phase::Committing;
        r.txid = Some(unsigned.unsigned_tx.compute_txid().to_string());
        r.batch_transfer_index = Some(1);
        r.unsigned_psbt = Some(unsigned.to_string());
        r.signed_psbt = Some(signed.to_string());
        r.dispatch_started = true;
        r
    }

    #[test]
    fn a_cancel_request_never_revokes_or_releases_a_dispatched_record_by_itself() {
        let (_root, wallet, _) = setup();
        let store = Store::open(&wallet, false).unwrap();
        let outbox = store.read(&wallet).unwrap();
        let mut record = dispatched_rgb(&wallet);
        record.cancel_requested = true;
        record.validate(&outbox).unwrap();
        assert_eq!(record.phase, Phase::Committing);
        assert_eq!(record.response()["endAuthorized"], true);
        assert!(!record.revocation_confirmed);
        assert!(!record.terminal());
    }

    #[test]
    fn the_certificate_is_bound_to_dispatched_cancelling_rgb_state() {
        let (_root, wallet, _) = setup();
        let store = Store::open(&wallet, false).unwrap();
        let outbox = store.read(&wallet).unwrap();
        let mut record = dispatched_rgb(&wallet);
        record.cancel_requested = true;
        record.revocation_confirmed = true;
        record.validate(&outbox).unwrap();
        assert!(serde_json::to_string(&record).unwrap().contains("\"revocationConfirmed\":true"));
        let mut missing_cancel = record.clone(); missing_cancel.cancel_requested = false;
        code(missing_cancel.validate(&outbox), "RECOVERY_STORAGE_INVALID");
        let mut no_dispatch = record.clone(); no_dispatch.dispatch_started = false;
        code(no_dispatch.validate(&outbox), "RECOVERY_STORAGE_INVALID");
        let mut uncommitted = record.clone(); uncommitted.phase = Phase::Prepared;
        code(uncommitted.validate(&outbox), "RECOVERY_STORAGE_INVALID");
        let mut bitcoin = Record::new(command(&wallet, &"e3".repeat(16)));
        bitcoin.revocation_confirmed = true;
        code(bitcoin.validate(&outbox), "RECOVERY_STORAGE_INVALID");
    }

    #[test]
    fn terminal_certificates_compact_proof_and_keep_cancelled_outcomes_unambiguous() {
        let (_root, wallet, _) = setup();
        let store = Store::open(&wallet, false).unwrap();
        let outbox = store.read(&wallet).unwrap();
        let mut rejected = dispatched_rgb(&wallet);
        rejected.cancel_requested = true;
        rejected.revocation_confirmed = true;
        rejected.finish(false, Some("cancelled"));
        rejected.validate(&outbox).unwrap();
        assert_eq!(rejected.response()["phase"], "rejected");
        assert_eq!(rejected.response()["endAuthorized"], false);
        assert_eq!(rejected.response()["failureCode"], "cancelled");
        assert!(rejected.signed_psbt.is_none() && rejected.unsigned_psbt.is_none() && rejected.command.is_none());
        assert!(!rejected.revocation_confirmed);
        let mut accepted = dispatched_rgb(&wallet);
        accepted.cancel_requested = true;
        accepted.finish(true, None);
        accepted.validate(&outbox).unwrap();
        assert!(!accepted.cancel_requested);
        assert_eq!(accepted.response()["phase"], "accepted");
        assert_eq!(accepted.response()["endAuthorized"], true);
    }
    #[test]
    fn explicit_revocation_rejects_bitcoin_before_any_online_action() {
        let (_root, mut wallet, _) = setup();
        let raw = serde_json::to_string(&command(&wallet, &"e4".repeat(16))).unwrap();
        code(wallet.revoke_onchain_send(Online { id:0 }, raw), "RECOVERY_REQUEST_INVALID");
    }

    #[test]
    fn watch_only_cannot_acquire_signed_proxy_revocation_authority() {
        let (_root, wallet, _) = setup();
        let keys = wallet.get_keys();
        let readonly_root = tempfile::tempdir().unwrap();
        let mut readonly = Wallet::new(WalletData {
            data_dir:readonly_root.path().to_str().unwrap().into(), bitcoin_network:BitcoinNetwork::Regtest,
            database_type:DatabaseType::Sqlite, max_allocations_per_utxo:5, supported_schemas:vec![AssetSchema::Bfa],
        }, SinglesigKeys {
            account_xpub_vanilla:keys.account_xpub_vanilla,
            account_xpub_colored:keys.account_xpub_colored,
            vanilla_keychain:None,
            master_fingerprint:keys.master_fingerprint,
            mnemonic:None, witness_version:WitnessVersion::Taproot,
        }).unwrap();
        let raw = serde_json::to_string(dispatched_rgb(&readonly).command.as_ref().unwrap()).unwrap();
        assert!(matches!(readonly.revoke_onchain_send(Online { id:0 }, raw), Err(Error::WatchOnly)));
    }

}
