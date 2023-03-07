//! I tried to create a proper parser, but those abstractions turned out to be not-so-zero cost!
//! Here's a simple version instead
#![allow(clippy::similar_names)]
#![allow(clippy::cast_possible_truncation)]
#![allow(clippy::needless_pass_by_value)]

use fork::daemon;
use std::collections::{HashMap, HashSet};
use std::io::{self, prelude::*};
use std::sync::mpsc;
use std::time::{Duration, SystemTime};

fn read_file(p: impl AsRef<std::path::Path>) -> io::Result<Vec<u8>> {
    let p = p.as_ref().to_owned();
    let mut vec = Vec::new();
    let mut file = std::fs::File::open(p)?;
    file.read_to_end(&mut vec)?;
    Ok(vec)
}
fn read_file_s(p: impl AsRef<std::path::Path>) -> io::Result<String> {
    let p = p.as_ref().to_owned();
    let mut s = String::new();
    let mut file = std::fs::File::open(p)?;
    std::io::Read::read_to_string(&mut file, &mut s)?;
    Ok(s)
}

fn write_file(p: impl AsRef<std::path::Path>, data: Vec<u8>) -> io::Result<()> {
    let p = p.as_ref().to_owned();
    let mut file = std::fs::File::create(p)?;
    std::io::Write::write_all(&mut file, &data)
}

#[derive(Clone, Debug, PartialEq)]
pub struct AppInfoEntry {
    pub app_id: u32,
    pub info_state: u32,
    pub last_updated: u32,
    pub pics_token: u64,
    pub text_vdf_sha1: [u8; 20],
    pub change_number: u32,
    pub info: HashMap<Vec<u8>, Value>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct AppInfo {
    pub magic: u32,
    pub universe: u32,
    pub entries: Vec<AppInfoEntry>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum Value {
    Map(HashMap<Vec<u8>, Value>),
    String(Vec<u8>),
}

#[allow(clippy::missing_const_for_fn)]
impl Value {
    fn into_map(self) -> Option<HashMap<Vec<u8>, Self>> {
        if let Self::Map(map) = self {
            Some(map)
        } else {
            None
        }
    }
    fn into_string(self) -> Option<Vec<u8>> {
        if let Self::String(s) = self {
            Some(s)
        } else {
            None
        }
    }
}

fn read_map(reader: &mut impl io::Read) -> io::Result<HashMap<Vec<u8>, Value>> {
    let mut ret = HashMap::new();
    let mut buf = [0u8];
    let mut buf2 = [0u8; 2];
    let mut buf4 = [0u8; 4];
    let mut buf8 = [0u8; 8];
    loop {
        reader.read_exact(&mut buf)?;
        let kind = buf[0];
        if kind == 8 || kind == 11 {
            break Ok(ret);
        }
        let mut key = vec![];
        loop {
            reader.read_exact(&mut buf)?;
            if buf[0] == 0 {
                break;
            }
            key.push(buf[0]);
        }
        #[allow(clippy::match_same_arms)]
        match kind {
            0 => {
                ret.insert(key, Value::Map(read_map(reader)?));
            }
            1 => {
                let mut s = vec![];
                loop {
                    reader.read_exact(&mut buf)?;
                    if buf[0] == 0 {
                        break;
                    }
                    s.push(buf[0]);
                }
                ret.insert(key, Value::String(s));
            }
            2 => {
                reader.read_exact(&mut buf4)?;
                // ret.insert(key, Value::I32(i32::from_le_bytes(buf4)))?;
            }
            3 => {
                reader.read_exact(&mut buf4)?;
                // ret.insert(key, Value::F32(f32::from_le_bytes(buf4)))?;
            }
            4 => {
                reader.read_exact(&mut buf4)?;
                // ret.insert(key, Value::Pointer(i32::from_le_bytes(buf4)))?;
            }
            5 => {
                let mut s = vec![0u16; 2];
                loop {
                    reader.read_exact(&mut buf2)?;
                    if buf2 == [0u8, 0u8] {
                        break;
                    }
                    s.extend_from_slice(&[u16::from_le_bytes(buf2)]);
                }
                // utf-8 is used instead of utf-16 here
                // ret.insert(key, Value::WideString(s))?;
            }
            7 => {
                reader.read_exact(&mut buf8)?;
                // ret.insert(key, Value::U64(u64::from_le_bytes(buf8)))?;
            }
            10 => {
                reader.read_exact(&mut buf8)?;
                // ret.insert(key, Value::I64(i64::from_le_bytes(buf8)))?;
            }
            n => panic!("invalid vdf data type: {n}"),
        }
    }
}

fn read_app_info(reader: &mut impl io::Read) -> io::Result<AppInfo> {
    let mut buf4 = [0u8; 4];
    // let mut buf8 = [0u8; 8];
    // let mut buf20 = [0u8; 20];
    let mut buf64 = [0u8; 64];
    reader.read_exact(&mut buf4)?;
    assert_eq!(buf4, [0x28, 0x44, 0x56, 0x07]);
    reader.read_exact(&mut buf4)?;
    assert_eq!(u32::from_le_bytes(buf4), 1);
    let mut ret = AppInfo {
        magic: 0x0756_4428,
        universe: 1,
        entries: vec![],
    };
    loop {
        reader.read_exact(&mut buf4)?;
        let app_id = u32::from_le_bytes(buf4);
        if app_id == 0 {
            break Ok(ret);
        }
        let mut entry = AppInfoEntry {
            app_id,
            info_state: 0,
            last_updated: 0,
            pics_token: 0,
            text_vdf_sha1: [0u8; 20],
            change_number: 0,
            info: HashMap::new(),
        };
        reader.read_exact(&mut buf64[..4 * 3 + 8 + 20 + 4 + 20])?;
        // reader.read_exact(&mut buf4)?;
        // size
        // reader.read_exact(&mut buf4)?;
        // entry.info_state = u32::from_le_bytes(buf4);
        // reader.read_exact(&mut buf4)?;
        // entry.last_updated = u32::from_le_bytes(buf4);
        // reader.read_exact(&mut buf8)?;
        // entry.pics_token = u64::from_le_bytes(buf8);
        // reader.read_exact(&mut buf20)?;
        // entry.text_vdf_sha1 = buf20;
        // reader.read_exact(&mut buf4)?;
        // entry.change_number = u32::from_le_bytes(buf4);
        // reader.read_exact(&mut buf20)?;
        // bin sha1
        entry.info = read_map(reader)?;
        ret.entries.push(entry);
    }
}

fn home() -> String {
    std::env::var("HOME").unwrap()
}
fn xdg_home() -> String {
    std::env::var("XDG_DATA_HOME").unwrap_or_else(|_| home() + "/.local/share")
}
fn xdg_cache() -> String {
    std::env::var("XDG_CACHE_HOME").unwrap_or_else(|_| home() + "/.cache")
}
fn cache_dir() -> String {
    let dir = xdg_cache() + "/rofi-steam-game-list";
    let _ = std::fs::create_dir_all(&dir);
    dir
}
fn history_dir() -> String {
    let dir = xdg_home() + "/rofi-steam-game-list";
    let _ = std::fs::create_dir_all(&dir);
    dir
}
fn history(k: &str) -> HashMap<u32, u32> {
    let dir = history_dir();
    let mut ret = HashMap::new();
    let Ok(data) = read_file(dir + "/history_" + k) else {
        return ret;
    };
    if data.len() < 8 {
        return ret;
    }
    let count = u32::from_le_bytes(data[4..8].try_into().unwrap());
    let data = &mut &data[8..];
    let mut buf4 = [0u8; 4];
    for _ in 0..count {
        if std::io::Read::read_exact(data, &mut buf4).is_err() {
            return ret;
        }
        let k = u32::from_le_bytes(buf4);
        if std::io::Read::read_exact(data, &mut buf4).is_err() {
            return ret;
        }
        let v = u32::from_le_bytes(buf4);
        ret.insert(k, v);
    }
    ret
}
fn write_history(m: &HashMap<u32, u32>, k: &str) {
    let dir = history_dir();
    let mut data = vec![];
    data.extend_from_slice(&[0; 4]);
    data.extend_from_slice(&(m.len() as u32).to_le_bytes());
    for (k, v) in m.iter() {
        data.extend_from_slice(&k.to_le_bytes());
        data.extend_from_slice(&v.to_le_bytes());
    }
    let _ = write_file(dir + "/history_" + k, data);
}

fn read_time(s: String) -> io::Result<SystemTime> {
    std::fs::metadata(s + "/Steam/appcache/appinfo.vdf")?.modified()
}

fn read_appinfo(target_type: String, s: String) -> io::Result<(SystemTime, Vec<(u32, String)>)> {
    let time = read_time(s.clone())?;
    let vec = read_file(s + "/Steam/appcache/appinfo.vdf")?;
    let data = read_app_info(&mut &vec[..])?;
    let mut ret = Vec::new();
    for mut info in data.entries {
        if let Some(mut x) = info
            .info
            .remove(&b"appinfo"[..])
            .and_then(Value::into_map)
            .and_then(|mut x| x.remove(&b"common"[..]))
            .and_then(Value::into_map)
        {
            if let Some(mut t) = x
                .remove(&b"type"[..])
                .and_then(Value::into_string)
                .and_then(|x| String::from_utf8(x).ok())
            {
                if let Some(n) = x
                    .remove(&b"name"[..])
                    .and_then(Value::into_string)
                    .and_then(|x| String::from_utf8(x).ok())
                {
                    t.make_ascii_lowercase();
                    if t == target_type {
                        ret.push((info.app_id, n));
                    }
                }
            }
        }
    }
    Ok((time, ret))
}

fn list_appids(s: &str) -> HashSet<u32> {
    let Ok(data) = read_file_s(s.to_owned() + "/Steam/steamapps/libraryfolders.vdf") else {
        return HashSet::new();
    };
    let ret = keyvalues_parser::Vdf::parse(&data)
        .unwrap()
        .value
        .get_obj()
        .unwrap()
        .values()
        .flat_map(|x| {
            x.iter().flat_map(|x| {
                x.get_obj().unwrap().get("apps").into_iter().flat_map(|x| {
                    x.iter().flat_map(|x| {
                        x.get_obj()
                            .unwrap()
                            .keys()
                            .filter_map(|x| x.parse::<u32>().ok())
                    })
                })
            })
        })
        .collect::<HashSet<u32>>();
    ret
}

fn cache_time(k: &str) -> std::io::Result<SystemTime> {
    let path = cache_dir() + "/type_" + k;
    let mut file = std::fs::File::open(path)?;
    let mut data = Vec::new();
    file.read_to_end(&mut data)?;
    if data.len() >= 12 {
        let (_, data) = data.split_at(4);
        let (first, _data) = data.split_at(8);
        let time = SystemTime::UNIX_EPOCH
            + Duration::from_millis(u64::from_le_bytes(first.try_into().unwrap()));
        Ok(time)
    } else {
        Err(io::Error::from(io::ErrorKind::Other))
    }
}

fn read_cache(k: &str) -> io::Result<(SystemTime, Vec<(u32, String)>)> {
    let path = cache_dir() + "/type_" + k;
    let mut file = std::fs::File::open(path)?;
    let mut data = Vec::new();
    file.read_to_end(&mut data)?;
    if data.len() >= 16 {
        let (_, data) = data.split_at(4);
        let (first, data) = data.split_at(8);
        let time = SystemTime::UNIX_EPOCH
            + Duration::from_millis(u64::from_le_bytes(first.try_into().unwrap()));
        let (first, data) = data.split_at(4);
        let count = u32::from_le_bytes(first.try_into().unwrap());
        let data = &mut &data[..];
        let mut buf4 = [0u8; 4];
        let mut buf1 = [0u8; 1];
        let mut ret = Vec::with_capacity(count as usize);
        for _ in 0..count {
            std::io::Read::read_exact(data, &mut buf4)?;
            std::io::Read::read_exact(data, &mut buf1)?;
            let len = if buf1[0] == 255 {
                std::io::Read::read_exact(data, &mut buf1)?;
                255 + buf1[0] as usize
            } else {
                buf1[0] as usize
            };
            let mut buf = vec![0; len];
            std::io::Read::read_exact(data, &mut buf)?;
            if let Ok(s) = String::from_utf8(buf) {
                ret.push((u32::from_le_bytes(buf4), s));
            }
        }
        Ok((time, ret))
    } else {
        Err(std::io::Error::new(
            std::io::ErrorKind::Other,
            "invalid app id cache format",
        ))
    }
}

fn write_cache(k: &str, time: SystemTime, ids: &[(u32, String)]) {
    let mut data = Vec::new();
    data.extend_from_slice(&[0; 4]);
    data.extend_from_slice(
        &(time
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap()
            .as_millis() as u64)
            .to_le_bytes(),
    );
    data.extend_from_slice(&(ids.len() as u32).to_le_bytes());
    for (id, s) in ids {
        if s.len() > u8::MAX as usize + u8::MAX as usize {
            continue;
        }
        data.extend_from_slice(&id.to_le_bytes());
        if s.len() > u8::MAX as usize {
            data.extend_from_slice(&255u8.to_le_bytes());
            data.extend_from_slice(&((s.len() - u8::MAX as usize) as u8).to_le_bytes());
        } else {
            data.extend_from_slice(&(s.len() as u8).to_le_bytes());
        }
        data.extend_from_slice(s.as_bytes());
    }
    let path = cache_dir() + "/type_" + k;
    if let Ok(mut file) = std::fs::File::create(path) {
        let _ = file.write_all(&data);
    }
}

struct PendingFut;
impl std::future::Future for PendingFut {
    type Output = ();
    fn poll(self: std::pin::Pin<&mut Self>, _: &mut std::task::Context<'_>) -> std::task::Poll<()> {
        std::task::Poll::Pending
    }
}

fn main() {
    let target_type = std::env::var("STEAM_GAME_LIST_TYPE").map_or_else(
        |_| "game".to_owned(),
        |mut x| {
            x.make_ascii_lowercase();
            x
        },
    );
    if let Ok(appid) = std::env::var("ROFI_INFO") {
        let _ = daemon(true, false);
        let mut cmd = std::process::Command::new("xdg-open")
            .arg(&format!("steam://rungameid/{appid}"))
            .spawn()
            .unwrap();
        if let Ok(x) = appid.parse::<u32>() {
            let mut history = history(&target_type);
            history.entry(x).and_modify(|curr| *curr += 1).or_insert(1);
            write_history(&history, &target_type);
        }
        let _ = cmd.wait();
        return;
    }
    /*
     * Flow1: read app info -> print app info -> write cache
     * Flow2: read cache -> print cache -> check app info mod time -> write cache
     * */
    let xdg_home = xdg_home();
    let xdg_home2 = xdg_home.clone();
    let xdg_home3 = xdg_home;
    let target_type2 = target_type.clone();
    let target_type3 = target_type.clone();
    let target_type4 = target_type.clone();
    let a = std::thread::spawn(move || history(&target_type3));
    let (tx0, rx0) = mpsc::channel();
    let (tx2, rx2) = mpsc::channel();
    let b = std::thread::spawn(move || {
        let tx1 = tx0.clone();
        std::thread::spawn(move || {
            tx0.send(
                read_appinfo(target_type2, crate::xdg_home()).map_or_else(|_| {
                    let _ = tx2.send(None);
                    None
                }, |info| {
                    let _ = tx2.send(Some(info.clone()));
                    Some((info, false))
                })
            )
        });
        std::thread::spawn(move || tx1.send(read_cache(&target_type4).ok().map(|x| (x, true))));
        #[allow(clippy::same_functions_in_if_condition)]
        if let Ok(Some(x)) = rx0.recv() {
            x
        } else if let Ok(Some(x)) = rx0.recv() {
            x
        } else {
            panic!()
        }
    });
    let c = std::thread::spawn(move || list_appids(&xdg_home2));
    let history = a.join().unwrap();
    let ((time, app_info), is_cache) = b.join().unwrap();
    let installed_games = c.join().unwrap();

    let mut app_info_2 = app_info
        .iter()
        .filter_map(|x| {
            if installed_games.contains(&x.0) {
                Some(x.clone())
            } else {
                None
            }
        })
        .collect::<Vec<_>>();
    app_info_2.sort_by_key(|x| u32::MAX - history.get(&x.0).unwrap_or(&0));
    for (app_id, n) in &app_info_2 {
        let icon = format!("{xdg_home3}/Steam/appcache/librarycache/{app_id}_icon.jpg");
        print!("{n}\0info\x1f{app_id}");
        if std::fs::metadata(&icon).is_ok() {
            print!("\x1ficon\x1f{icon}");
        }
        println!();
    }
    let _ = daemon(true, false);
    if is_cache {
        if read_time(xdg_home3).unwrap() <= time {
            return;
        }
        if let Some((time, app_info)) = rx2.recv().unwrap() {
            write_cache(&target_type, time, &app_info);
        }
    } else {
        if let Ok(ctime) = cache_time(&target_type) {
            if time <= ctime {
                return;
            }
        }
        write_cache(&target_type, time, &app_info);
    }
}
