mod snapshot_refresh_qualification {
    use super::*;
    use crate::wallet::backup::ScryptParams;

    fn pending_rows(wallet: &Wallet) -> Vec<DbBatchTransfer> {
        let txn = wallet.database().begin_transaction().unwrap();
        for (index, (incoming, status)) in [
            (false, TransferStatus::WaitingCounterparty),
            (true, TransferStatus::WaitingCounterparty),
            (true, TransferStatus::WaitingSafeHeight),
            (true, TransferStatus::WaitingBroadcast),
            (true, TransferStatus::WaitingConfirmations),
            (false, TransferStatus::WaitingConfirmations),
        ]
        .into_iter()
        .enumerate()
        {
            let mut row: DbBatchTransferActMod = DbBatchTransfer {
                idx: index as i32 + 1,
                txid: Some(format!("{:064x}", index + 1)),
                status,
                created_at: 1,
                updated_at: 1,
                expiration: Some(2),
                min_confirmations: 1,
                incoming,
                operation_secret_key: None,
                broadcast_deadline: Some(3),
                retention_deadline: None,
            }
            .into();
            row.idx = ActiveValue::NotSet;
            txn.set_batch_transfer(row).unwrap();
        }
        let rows = txn.iter_batch_transfers().unwrap();
        txn.commit().unwrap();
        rows
    }

    fn require_quarantine(wallet: &mut Wallet, expected: &[DbBatchTransfer]) {
        // The guard must win BEFORE online/session admission, journal recovery,
        // filtering or pending-state dispatch. Invalid Online is a tripwire:
        // without the guard this returns Offline instead of quarantine.
        code(
            wallet.refresh(Online { id: 0 }, None, vec![], false),
            "RECOVERY_RESTORE_UNCERTAIN",
        );
        code(
            wallet.refresh(Online { id: 0 }, Some("unknown-asset".into()), vec![], true),
            "RECOVERY_RESTORE_UNCERTAIN",
        );
        let txn = wallet.database().begin_transaction().unwrap();
        assert_eq!(txn.iter_batch_transfers().unwrap(), expected);
        txn.commit().unwrap();
    }

    #[test]
    fn encrypted_restored_pending_send_and_receive_cannot_enter_generic_refresh() {
        let (_source, mut wallet, identity) = setup();
        let expected = pending_rows(&wallet);
        let store = Store::open(&wallet, false).unwrap();
        let mut outbox = store.read(&wallet).unwrap();
        outbox
            .records
            .push(Record::new(command(&wallet, &"f1".repeat(16))));
        store.write(&outbox).unwrap();
        drop(store);
        // Pending payments on the current intact wallet retain refresh access.
        wallet.assert_snapshot_refresh_authority().unwrap();
        assert!(matches!(
            wallet.refresh(Online { id: 0 }, None, vec![], false),
            Err(Error::Offline)
        ));
        let files = tempfile::tempdir().unwrap();
        let archive = files.path().join("pending.backup");
        wallet
            .backup_customize(
                archive.to_str().unwrap(),
                "fixture-password",
                Some(ScryptParams::new(Some(10), Some(8), Some(1))),
            )
            .unwrap();
        let destination = tempfile::tempdir().unwrap();
        super::super::super::backup::restore_backup(
            archive.to_str().unwrap(),
            "fixture-password",
            destination.path().to_str().unwrap(),
        )
        .unwrap();
        let keys = wallet.get_keys();
        let mut restored = Wallet::load(
            destination.path().to_str().unwrap(),
            &keys.master_fingerprint,
            keys.mnemonic,
        )
        .unwrap();
        // Raw native refresh is blocked even BEFORE initializeOnchainRecovery.
        require_quarantine(&mut restored, &expected);
        restored
            .initialize_onchain_recovery(identity, false)
            .unwrap();
        require_quarantine(&mut restored, &expected);
        // Once authenticated, quarantine survives deletion of the transient
        // marker; neither a passive refresh nor a reopen can clear it.
        fs::remove_file(
            restored
                .get_wallet_dir()
                .join(super::super::super::backup::RESTORED_SNAPSHOT_FILE),
        )
        .unwrap();
        require_quarantine(&mut restored, &expected);
        let restored_keys = restored.get_keys();
        drop(restored);
        let mut reopened = Wallet::load(
            destination.path().to_str().unwrap(),
            &restored_keys.master_fingerprint,
            restored_keys.mnemonic,
        )
        .unwrap();
        require_quarantine(&mut reopened, &expected);
    }

    #[test]
    fn lost_managed_journal_and_alias_restore_markers_never_grant_refresh_authority() {
        let (_source, wallet, _) = setup();
        fs::remove_dir_all(wallet.get_wallet_dir().join(DIRECTORY)).unwrap();
        code(
            wallet.assert_snapshot_refresh_authority(),
            "RECOVERY_STORAGE_INVALID",
        );
        let marker = wallet
            .get_wallet_dir()
            .join(super::super::super::backup::RESTORED_SNAPSHOT_FILE);
        let missing = wallet.get_wallet_dir().join("nonexistent-marker-target");
        std::os::unix::fs::symlink(missing, &marker).unwrap();
        code(
            wallet.assert_snapshot_refresh_authority(),
            "RECOVERY_RESTORE_UNCERTAIN",
        );
    }
    #[test]
    fn unmanaged_native_wallet_is_compatible_but_sdk_profile_requires_its_journal() {
        let root = tempfile::tempdir().unwrap();
        let keys = crate::keys::generate_keys(BitcoinNetwork::Regtest, WitnessVersion::Taproot);
        let wallet = Wallet::new(
            WalletData {
                data_dir: root.path().to_str().unwrap().into(),
                bitcoin_network: BitcoinNetwork::Regtest,
                database_type: DatabaseType::Sqlite,
                max_allocations_per_utxo: 5,
                supported_schemas: vec![AssetSchema::Nia],
            },
            SinglesigKeys::from_keys(&keys, None),
        )
        .unwrap();
        wallet.assert_snapshot_refresh_authority().unwrap();
        let profile = wallet.get_wallet_dir().join("rgb-sdk-profile.json");
        write_private(&profile, b"{}");
        code(
            wallet.assert_snapshot_refresh_authority(),
            "RECOVERY_STORAGE_INVALID",
        );
    }
    #[test]
    fn current_managed_pending_wallet_retains_refresh_and_honors_exclusive_journal_lease() {
        let (_source, wallet, _) = setup();
        wallet.assert_snapshot_refresh_authority().unwrap();
        let store = Store::open(&wallet, false).unwrap();
        let mut outbox = store.read(&wallet).unwrap();
        outbox
            .records
            .push(Record::new(command(&wallet, &"f2".repeat(16))));
        store.write(&outbox).unwrap();
        code(wallet.assert_snapshot_refresh_authority(), "RECOVERY_BUSY");
        drop(store);
        // Pending authority is valid for normal refresh; only simultaneous
        // ownership or permanent snapshot quarantine prevents admission.
        wallet.assert_snapshot_refresh_authority().unwrap();
    }
}
