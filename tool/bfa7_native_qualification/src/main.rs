//! Loopback-only, separately stored qualification client; never prints keys/PSBTs.
use base64::{Engine, engine::general_purpose::STANDARD};
use rgb_lib::{
    AssetSchema, Assignment, Encryption, Error,
    bitcoin::hashes::{Hash, sha256},
    keys::{Keys, WitnessVersion, generate_keys, restore_keys},
    utils::BitcoinNetwork,
    wallet::{
        AssetFilter, DatabaseType, EvmChain, IndexerConfig, Invoice, OnlineOptions,
        RgbWalletOpsOffline, RgbWalletOpsOnline, SinglesigKeys, TransferScope, Wallet, WalletData,
    },
};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::{
    collections::HashMap,
    fs::{self, OpenOptions},
    io::{Read, Write},
    os::unix::fs::{DirBuilderExt, OpenOptionsExt},
    path::{Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};
const ASSET: &str = "rgb:kOryemwN-I8Iutl8-otIPmDa-rn1cPTq-7VuhGvS-oe6oiMc";
const PROXY: &str = "rpc://127.0.0.1:49790/json-rpc";
const SOURCE: &str = "9ec49c08be2e68f08521281e3efbd760ec989cb9";
const DIGEST: &str = "189674bd83baa0a74c06f86d4652d896e7725f33285b9e25c8006b2087044cb0";
type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;
#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct Identity {
    version: u32,
    wallet_binding: String,
    cohort: String,
    network: String,
    witness_version: String,
}
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct Request {
    version: u32,
    operation_id: String,
    kind: String,
    amount: String,
    fee_rate: String,
    address: Option<String>,
    asset_id: Option<String>,
    recipient_id: Option<String>,
    transport_endpoints: Vec<String>,
    sender_transport_endpoint: Option<String>,
    witness_amount_sat: Option<String>,
    witness_blinding: Option<String>,
    min_confirmations: u8,
    donation: bool,
    expiration_timestamp: Option<String>,
    invoice_public_key: Option<String>,
    invoice_encryption: Option<String>,
    #[serde(skip_serializing_if = "String::is_empty")]
    fingerprint: String,
}
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct Envelope {
    version: u32,
    backend: String,
    network: String,
    wallet_binding: String,
    recovery_cohort: String,
    native_source_revision: String,
    native_overlay: String,
    request: Request,
}
fn protected_write(path: &Path, bytes: &[u8]) -> Result<()> {
    let mut f = OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .open(path)?;
    f.write_all(bytes)?;
    f.sync_all()?;
    Ok(())
}
fn read(path: &Path) -> Result<String> {
    if path.is_symlink() || fs::metadata(path)?.len() > 250000 {
        return Err("invalid private input".into());
    }
    Ok(fs::read_to_string(path)?)
}
fn native<T>(value: std::result::Result<T, Error>) -> Result<T> {
    value.map_err(|e| match e {
        Error::Recovery { code } => code.into(),
        _ => "native operation failed; see private wallet log".into(),
    })
}
fn now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs()
}
fn run(input: Value) -> Result<Value> {
    let root = PathBuf::from(input["root"].as_str().ok_or("missing private root")?);
    if !root.is_absolute()
        || root.is_symlink()
        || !root
            .to_string_lossy()
            .contains("/.buildlog/bfa7-native/qualification-wallets/")
    {
        return Err("unadmitted private root".into());
    }
    let wallet_name = input["wallet"].as_str().ok_or("missing wallet")?;
    if !matches!(wallet_name, "sender" | "receiver") {
        return Err("unadmitted wallet name".into());
    }
    let action = input["action"].as_str().ok_or("missing action")?;
    let proxy = if input["faultProxy"] == "rgb-consignment-reply" {
        "rpc://127.0.0.1:49890/json-rpc"
    } else {
        PROXY
    };
    let dir = root.join(wallet_name);
    if action == "init" {
        fs::DirBuilder::new().mode(0o700).create(&dir)?;
        let keys = generate_keys(BitcoinNetwork::Regtest, WitnessVersion::Taproot);
        protected_write(&dir.join("keys.private.json"), &serde_json::to_vec(&keys)?)?;
        let binding = sha256::Hash::hash(
            format!(
                "regtest:taproot:{}:{}",
                keys.account_xpub_vanilla, keys.account_xpub_colored
            )
            .as_bytes(),
        )
        .to_string();
        let cohort =
            sha256::Hash::hash(format!("{}:{}:{}", keys.mnemonic, now(), wallet_name).as_bytes())
                .to_string()[..32]
                .to_string();
        protected_write(
            &dir.join("identity.json"),
            &serde_json::to_vec(&Identity {
                version: 1,
                wallet_binding: binding,
                cohort,
                network: "regtest".into(),
                witness_version: "taproot".into(),
            })?,
        )?;
        fs::DirBuilder::new()
            .mode(0o700)
            .create(dir.join("native"))?;
    }
    let keys: Keys = serde_json::from_str(&read(&dir.join("keys.private.json"))?)?;
    let keys = restore_keys(
        BitcoinNetwork::Regtest,
        keys.mnemonic,
        WitnessVersion::Taproot,
    )?;
    let identity: Identity = serde_json::from_str(&read(&dir.join("identity.json"))?)?;
    let mut wallet = native(Wallet::new(
        WalletData {
            data_dir: dir.join("native").to_string_lossy().to_string(),
            bitcoin_network: BitcoinNetwork::Regtest,
            database_type: DatabaseType::Sqlite,
            max_allocations_per_utxo: 5,
            supported_schemas: vec![AssetSchema::Bfa],
        },
        SinglesigKeys {
            account_xpub_vanilla: keys.account_xpub_vanilla,
            account_xpub_colored: keys.account_xpub_colored,
            vanilla_keychain: None,
            master_fingerprint: keys.master_fingerprint,
            mnemonic: Some(keys.mnemonic),
            witness_version: WitnessVersion::Taproot,
        },
    ))?;
    native(
        wallet.initialize_onchain_recovery(serde_json::to_string(&identity)?, action == "init"),
    )?;
    if action == "init" {
        return Ok(
            json!({"ok":true,"walletBinding":identity.wallet_binding,"cohort":identity.cohort}),
        );
    }
    if action == "address" {
        return Ok(json!({"address":native(wallet.get_address())?}));
    }
    if action == "import" {
        let path = PathBuf::from(
            input["contractPath"]
                .as_str()
                .ok_or("missing public contract")?,
        );
        let bytes = fs::read(path)?;
        if bytes.len() != 444 || sha256::Hash::hash(&bytes).to_string() != DIGEST {
            return Err("public contract provenance mismatch".into());
        }
        return Ok(serde_json::from_str(&native(
            wallet.import_contract_base64(STANDARD.encode(bytes), ASSET.into()),
        )?)?);
    }
    let online = native(wallet.go_online(OnlineOptions {
        indexer_config: if input["faultIndexer"] == "esplora-broadcast-reply" {
            IndexerConfig::Esplora {
                url: "http://127.0.0.1:49894".into(),
            }
        } else {
            IndexerConfig::Electrum {
                url: "tcp://127.0.0.1:49702".into(),
            }
        },
        skip_consistency_check: false,
        vanilla_sync_lookback: 20,
        failed_witness_receive_grace_secs: 86400,
        proxy_auth_keys: HashMap::new(),
        evm_chains: HashMap::from([(
            31337,
            EvmChain {
                rpc_url: "http://127.0.0.1:49745".into(),
                min_mint_lock_blocks: 2,
                max_mint_lock_blocks: 512,
            },
        )]),
    }))?;
    match action {
        "balance" => Ok(
            json!({"btc":native(wallet.get_btc_balance(Some(online),false))?,"rgb":native(wallet.get_asset_balance(ASSET.into()))?}),
        ),
        "history" => Ok(
            json!({"btc":native(wallet.list_transactions(Some(online),false))?,"rgb":native(wallet.list_transfers(AssetFilter::Id(ASSET.into()),TransferScope::All))?}),
        ),
        "refresh" => {
            Ok(json!({"refresh":native(wallet.refresh(online,Some(ASSET.into()),vec![],false))?}))
        }
        "outputs" => {
            native(wallet.assert_no_pending_onchain_send())?;
            Ok(
                json!({"created":native(wallet.create_utxos(online,false,Some(4),Some(20000),1,false))?}),
            )
        }
        "receive" => {
            native(wallet.assert_no_pending_onchain_send())?;
            Ok(
                json!({"receive":native(wallet.witness_receive(Some(online),Some(ASSET.into()),Assignment::Fungible(input["amount"].as_u64().ok_or("missing amount")?),now()+86400,vec![proxy.into()],3,Some(Encryption::Optional)))?}),
            )
        }
        "blind-receive-for-fixture-mint" => {
            native(wallet.assert_no_pending_onchain_send())?;
            Ok(
                json!({"receive":native(wallet.blind_receive(Some(online),Some(ASSET.into()),Assignment::Fungible(input["amount"].as_u64().ok_or("missing amount")?),now()+86400,vec![proxy.into()],3,Some(Encryption::Optional)))?}),
            )
        }
        "received-mint" => Ok(
            json!({"mint":native(wallet.get_received_mint(input["recipientId"].as_str().ok_or("missing recipient")?.into()))?}),
        ),
        "command" => {
            let label = input["label"].as_str().ok_or("missing label")?;
            if label.is_empty()
                || label.len() > 32
                || !label
                    .bytes()
                    .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-')
            {
                return Err("bad label".into());
            }
            let rgb = input["kind"] == "rgb";
            let op = sha256::Hash::hash(format!("{}:{label}", identity.cohort).as_bytes())
                .to_string()[..32]
                .to_string();
            let mut r = Request {
                version: 2,
                operation_id: op,
                kind: if rgb { "rgb" } else { "bitcoin" }.into(),
                amount: input["amount"]
                    .as_u64()
                    .ok_or("missing amount")?
                    .to_string(),
                fee_rate: "1".into(),
                address: None,
                asset_id: None,
                recipient_id: None,
                transport_endpoints: vec![],
                sender_transport_endpoint: None,
                witness_amount_sat: None,
                witness_blinding: None,
                min_confirmations: if rgb { 3 } else { 1 },
                donation: false,
                expiration_timestamp: None,
                invoice_public_key: None,
                invoice_encryption: None,
                fingerprint: String::new(),
            };
            if rgb {
                let d = native(Invoice::new(
                    input["invoice"].as_str().ok_or("missing invoice")?.into(),
                ))?
                .invoice_data();
                if d.asset_id.as_deref() != Some(ASSET) {
                    return Err("asset mismatch".into());
                }
                r.asset_id = d.asset_id;
                r.recipient_id = Some(d.recipient_id);
                r.transport_endpoints = d.transport_endpoints;
                r.sender_transport_endpoint = Some(proxy.into());
                r.witness_amount_sat = Some("1000".into());
                r.expiration_timestamp = d.expiration_timestamp.map(|n| n.to_string());
                r.invoice_public_key = d.public_key;
                r.invoice_encryption = Some(format!("{:?}", d.encryption));
            } else {
                r.address = Some(input["address"].as_str().ok_or("missing address")?.into())
            }
            let mut e = Envelope {
                version: 3,
                backend: "RGB_L1".into(),
                network: "regtest".into(),
                wallet_binding: identity.wallet_binding,
                recovery_cohort: identity.cohort,
                native_source_revision: SOURCE.into(),
                native_overlay: "flutter-bfa7-durable-v1".into(),
                request: r,
            };
            e.request.fingerprint = sha256::Hash::hash(&serde_json::to_vec(&e)?).to_string();
            protected_write(
                &dir.join(format!("command-{label}.json")),
                &serde_json::to_vec(&e)?,
            )?;
            Ok(json!({"operationId":e.request.operation_id,"fingerprint":e.request.fingerprint}))
        }
        "audit" => {
            let v: Value = serde_json::from_str(&native(wallet.onchain_recovery_state())?)?;
            Ok(
                json!({"pending":v["pending"].as_array().map(|a|a.iter().map(|r|json!({"operationId":r["operationId"],"phase":r["phase"],"endAuthorized":r["endAuthorized"],"txid":r["txid"]})).collect::<Vec<_>>()),"cohort":v["cohort"],"retainedReceipts":v["retainedReceipts"]}),
            )
        }
        "receipts" => Ok(serde_json::from_str(&native(
            wallet.list_onchain_send_receipts(0, 100),
        )?)?),
        "prepare" | "commit" | "status" | "cancel" => {
            let label = input["label"].as_str().ok_or("missing label")?;
            if !label
                .bytes()
                .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-')
            {
                return Err("bad label".into());
            }
            let raw = read(&dir.join(format!("command-{label}.json")))?;
            let response = match action {
                "prepare" => wallet.prepare_onchain_send(online, raw),
                "commit" => wallet.commit_onchain_send(online, raw),
                "cancel" => wallet.cancel_onchain_send(Some(online), raw),
                _ => wallet.onchain_send_status(Some(online), raw),
            };
            Ok(serde_json::from_str(&native(response)?)?)
        }
        _ => Err("unknown action".into()),
    }
}
fn main() {
    let mut input = String::new();
    if std::io::stdin()
        .take(250000)
        .read_to_string(&mut input)
        .is_err()
    {
        std::process::exit(2)
    }
    let result = serde_json::from_str(&input)
        .map_err(|_| "invalid input".into())
        .and_then(run);
    match result {
        Ok(value) => println!("{}", value),
        Err(error) => {
            let text = error.to_string();
            let code = if text.starts_with("RECOVERY_")
                && text.len() < 128
                && text.bytes().all(|b| b.is_ascii_uppercase() || b == b'_')
            {
                text.as_str()
            } else {
                "qualification action failed; inspect private native log"
            };
            println!("{}", json!({"ok":false,"error":code}));
            std::process::exit(1)
        }
    }
}
