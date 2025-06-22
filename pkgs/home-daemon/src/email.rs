use std::{
    collections::HashMap,
    io::Write,
    path::PathBuf,
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
    time::{Duration, SystemTime},
};

use dashmap::DashMap;
use futures_util::StreamExt;
use mailparse::MailHeaderMap;
use serde::{Deserialize, Serialize};
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::{UnixListener, UnixStream},
};
use zbus::{
    zvariant::{ObjectPath, OwnedObjectPath, OwnedValue, Type, Value},
    CacheProperties, Connection,
};

#[zbus::dbus_proxy(
    interface = "org.freedesktop.Secret.Prompt",
    default_service = "org.freedesktop.Secret.Prompt"
)]
pub trait Prompt {
    fn prompt(&self, window_id: &str) -> zbus::Result<()>;

    fn dismiss(&self) -> zbus::Result<()>;

    #[dbus_proxy(signal)]
    fn completed(&self, dismissed: bool, result: Value<'_>) -> zbus::Result<()>;
}

#[zbus::dbus_proxy(
    interface = "org.freedesktop.Secret.Item",
    default_service = "org.freedesktop.Secret.Item"
)]
pub trait Item {
    fn delete(&self) -> zbus::Result<OwnedObjectPath>;

    fn get_secret(&self, session: &ObjectPath<'_>) -> zbus::Result<SecretStruct>;

    fn set_secret(&self, secret: &SecretStruct) -> zbus::Result<()>;

    #[dbus_proxy(property)]
    fn locked(&self) -> zbus::fdo::Result<bool>;

    #[dbus_proxy(property)]
    fn attributes(&self) -> zbus::fdo::Result<HashMap<String, String>>;

    #[dbus_proxy(property)]
    fn set_attributes(&self, attributes: HashMap<&str, &str>) -> zbus::fdo::Result<()>;

    #[dbus_proxy(property)]
    fn label(&self) -> zbus::fdo::Result<String>;

    #[dbus_proxy(property)]
    fn set_label(&self, new_label: &str) -> zbus::fdo::Result<()>;

    #[dbus_proxy(property)]
    fn created(&self) -> zbus::fdo::Result<u64>;

    #[dbus_proxy(property)]
    fn modified(&self) -> zbus::fdo::Result<u64>;
}

// definitions taken from https://github.com/open-source-cooperative/secret-service-rs/blob/master/src/proxy/service.rs
#[zbus::dbus_proxy(
    interface = "org.freedesktop.Secret.Service",
    default_service = "org.freedesktop.secrets",
    default_path = "/org/freedesktop/secrets"
)]
pub trait Service {
    fn open_session(&self, algorithm: &str, input: Value<'_>) -> zbus::Result<OpenSessionResult>;

    fn create_collection(
        &self,
        properties: HashMap<&str, Value<'_>>,
        alias: &str,
    ) -> zbus::Result<CreateCollectionResult>;

    fn search_items(&self, attributes: HashMap<&str, &str>) -> zbus::Result<SearchItemsResult>;

    fn unlock(&self, objects: Vec<ObjectPath<'_>>) -> zbus::Result<LockActionResult>;

    fn lock(&self, objects: Vec<ObjectPath<'_>>) -> zbus::Result<LockActionResult>;

    fn get_secrets(
        &self,
        objects: Vec<ObjectPath<'_>>,
    ) -> zbus::Result<HashMap<OwnedObjectPath, SecretStruct>>;

    fn read_alias(&self, name: &str) -> zbus::Result<OwnedObjectPath>;

    fn set_alias(&self, name: &str, collection: ObjectPath<'_>) -> zbus::Result<()>;

    #[dbus_proxy(property)]
    fn collections(&self) -> zbus::fdo::Result<Vec<ObjectPath<'_>>>;
}

#[derive(Debug, Serialize, Deserialize, Type)]
pub struct SecretStruct {
    pub(crate) session: OwnedObjectPath,
    pub(crate) parameters: Vec<u8>,
    pub(crate) value: Vec<u8>,
    pub(crate) content_type: String,
}

#[derive(Debug, Serialize, Deserialize, Type)]
pub struct OpenSessionResult {
    pub(crate) output: OwnedValue,
    pub(crate) result: OwnedObjectPath,
}

#[derive(Debug, Serialize, Deserialize, Type)]
pub struct CreateCollectionResult {
    pub(crate) collection: OwnedObjectPath,
    pub(crate) prompt: OwnedObjectPath,
}

#[derive(Debug, Serialize, Deserialize, Type)]
pub struct SearchItemsResult {
    pub(crate) unlocked: Vec<OwnedObjectPath>,
    pub(crate) locked: Vec<OwnedObjectPath>,
}

#[derive(Debug, Serialize, Deserialize, Type)]
pub struct LockActionResult {
    pub(crate) object_paths: Vec<OwnedObjectPath>,
    pub(crate) prompt: OwnedObjectPath,
}

pub struct Email<'a> {
    listener: UnixListener,
    conn: &'a Connection,
}

fn socket_path() -> PathBuf {
    let rt_dir = std::env::var_os("XDG_RUNTIME_DIR").unwrap();
    let mut ret = PathBuf::from(rt_dir);
    ret.push("home-daemon.sock");
    ret
}

impl<'a> Email<'a> {
    pub async fn new(conn: &'a Connection) -> Self {
        let path = socket_path();
        let _ = tokio::fs::remove_file(&path).await;
        let listener = tokio::net::UnixListener::bind(path).unwrap();
        Self { conn, listener }
    }
}

impl Email<'static> {
    pub async fn run(self) {
        let cache = Arc::<DashMap<(String, String), Vec<u8>>>::default();
        //let val = self.proxy.get_secrets(vec![locked.into()]).await.unwrap();
        let cache_allowed = Arc::<AtomicBool>::default();
        let listen_fut = async {
            loop {
                let Ok((mut stream, _addr)) = self.listener.accept().await else {
                    tokio::time::sleep(Duration::from_secs(5)).await;
                    continue;
                };
                let conn = self.conn;
                let cache_allowed = cache_allowed.clone();
                let cache = cache.clone();
                let handle = async move {
                    let k_len = stream.read_u16().await?;
                    let mut k = vec![0; k_len.into()];
                    stream.read_exact(&mut k).await?;
                    let k = std::str::from_utf8(&k)?;
                    let v_len = stream.read_u16().await?;
                    let mut v = vec![0; v_len.into()];
                    stream.read_exact(&mut v).await?;
                    let v = std::str::from_utf8(&v)?;
                    let p = if cache_allowed.load(Ordering::SeqCst) {
                        match cache.entry((k.to_owned(), v.to_owned())) {
                            dashmap::Entry::Vacant(entry) => {
                                entry.insert(get_password(conn, k, v).await?).clone()
                            }
                            dashmap::Entry::Occupied(entry) => entry.get().clone(),
                        }
                    } else {
                        get_password(conn, k, v).await?
                    };
                    stream.write_u16(u16::try_from(p.len())?).await?;
                    stream.write_all(&p).await?;
                    Ok::<_, Box<dyn std::error::Error + Send + Sync>>(())
                };
                tokio::spawn(handle);
            }
        };

        let mbsync_fut = async {
            let mut maildir = PathBuf::from(std::env::var_os("HOME").unwrap());
            maildir.push("Maildir");
            loop {
                #[cfg(not(debug_assertions))]
                tokio::time::sleep(Duration::from_secs(300)).await;
                cache_allowed.store(true, Ordering::SeqCst);
                let sync_time = SystemTime::now();
                match tokio::process::Command::new("mbsync").arg("--all").spawn() {
                    Ok(mut process) => {
                        let _ = process.wait().await;
                    }
                    Err(err) => {
                        eprintln!("{err}");
                    }
                }
                cache_allowed.store(false, Ordering::SeqCst);
                let Ok(proxy) = NotificationsProxy::new(self.conn).await else {
                    #[cfg(debug_assertions)]
                    tokio::time::sleep(Duration::from_secs(300)).await;
                    continue;
                };
                let Ok(mut maildir) = tokio::fs::read_dir(&maildir).await else {
                    #[cfg(debug_assertions)]
                    tokio::time::sleep(Duration::from_secs(300)).await;
                    continue;
                };
                while let Ok(Some(entry)) = maildir.next_entry().await {
                    for subdir in ["new", "cur"] {
                        let mut inbox = entry.path();
                        inbox.push("Inbox");
                        inbox.push(subdir);
                        let Ok(mut inbox) = tokio::fs::read_dir(inbox).await else {
                            continue;
                        };
                        while let Ok(Some(entry)) = inbox.next_entry().await {
                            let Ok(meta) = entry.metadata().await else {
                                continue;
                            };
                            let Ok(mtime) = meta.modified() else { continue };
                            if mtime >= sync_time {
                                tokio::spawn(maybe_show_notif(proxy.clone(), entry.path()));
                            }
                        }
                    }
                }
                #[cfg(debug_assertions)]
                tokio::time::sleep(Duration::from_secs(300)).await;
            }
        };
        tokio::join!(listen_fut, mbsync_fut);
    }
}

#[zbus::dbus_proxy(
    interface = "org.freedesktop.Notifications",
    default_service = "org.freedesktop.Notifications",
    default_path = "/org/freedesktop/Notifications"
)]
trait Notifications {
    #[allow(clippy::too_many_arguments)]
    fn notify(
        &self,
        app_name: &str,
        replaces_id: u32,
        app_icon: &str,
        summary: &str,
        body: &str,
        actions: &[&str],
        hints: &HashMap<&str, &Value<'_>>,
        expire_timeout: i32,
    ) -> zbus::Result<u32>;
}

async fn maybe_show_notif(
    proxy: NotificationsProxy<'_>,
    path: PathBuf,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let data = tokio::fs::read(&path).await?;
    let mail = mailparse::parse_mail(&data)?;
    let subject = mail
        .headers
        .get_first_value("Subject")
        .unwrap_or_else(|| "(no subject)".to_owned());
    let sender = mail
        .headers
        .get_first_value("From")
        .or_else(|| mail.headers.get_first_value("From"))
        .unwrap_or_else(|| "New email".to_owned());
    proxy
        .notify(
            "email",
            0,
            "dialog-information",
            &sender,
            &subject,
            &[],
            &HashMap::new(),
            10000,
        )
        .await?;
    Ok(())
}

pub async fn run_cli() {
    let mut args = std::env::args().skip(2);
    let k = args.next().expect("expected key");
    let v = args.next().expect("expected value");
    assert!(args.next().is_none());
    let path = socket_path();
    let mut conn = UnixStream::connect(path).await.unwrap();
    conn.write_u16(k.len().try_into().unwrap()).await.unwrap();
    conn.write_all(k.as_bytes()).await.unwrap();
    conn.write_u16(v.len().try_into().unwrap()).await.unwrap();
    conn.write_all(v.as_bytes()).await.unwrap();
    let len = conn.read_u16().await.unwrap();
    let mut buf = vec![0; len.into()];
    conn.read_exact(&mut buf).await.unwrap();
    std::io::stdout().write_all(&buf).unwrap();
}

async fn get_password(conn: &Connection, k: &str, v: &str) -> Result<Vec<u8>, zbus::Error> {
    let proxy = ServiceProxy::new(conn).await?;
    let mut a = HashMap::new();
    a.insert(k, v);
    let session = proxy.open_session("plain", "".into()).await?;
    //println!("{session:?}");
    let res = proxy.search_items(a).await?;
    let unlock_res = proxy
        .unlock(res.locked.iter().map(|x| x.as_ref()).collect())
        .await?;
    if unlock_res.object_paths.is_empty() {
        let prompt_proxy = PromptProxy::builder(conn)
            .destination("org.freedesktop.secrets")?
            .path(unlock_res.prompt)?
            .cache_properties(CacheProperties::No)
            .build()
            .await?;

        let mut receive_completed_iter = prompt_proxy.receive_completed().await?;
        prompt_proxy.prompt("").await?;

        let Some(signal) = receive_completed_iter.next().await else {
            return Err(zbus::Error::Unsupported);
        };
        let args = signal.args()?;
        if args.dismissed {
            return Err(zbus::Error::Unsupported);
        }
    }
    let mut combined = res.unlocked;
    combined.extend(res.locked);
    let Some(item) = combined.into_iter().next() else {
        return Err(zbus::Error::Unsupported);
    };
    let proxy = ItemProxy::builder(conn)
        .destination("org.freedesktop.secrets")?
        .path(&item)?
        .cache_properties(CacheProperties::No)
        .build()
        .await?;
    let res = proxy.get_secret(&session.result).await?;
    Ok(res.value)
}
