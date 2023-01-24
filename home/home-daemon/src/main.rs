use dbus_async::DBus;
use dbus_message_parser::{message::Message, value::Value};
use futures_util::stream::StreamExt;
use std::{collections::HashSet, sync::Arc};
use swayipc_async::{Connection, Event, EventType, WindowChange};

#[tokio::main(flavor = "current_thread")]
async fn main() {
    let (dbus, _server_handle) = DBus::system(false, false)
        .await
        .expect("failed to get the DBus object");
    let dbus = Arc::new(dbus);

    let mut handlers = Vec::<Box<dyn SwayIpcHandler>>::new();
    for args in std::env::args().skip(1) {
        handlers.push(match args.as_str() {
            "system76-scheduler" => Box::new(System76::new(dbus.clone())),
            _ => panic!("handler not supported"),
        })
    }
    if handlers.is_empty() {
        panic!("no handlers set up");
    }

    let mut subs = HashSet::new();
    for handler in &mut handlers {
        handler.register(&mut subs);
    }
    let subs = subs.into_iter().collect::<Vec<_>>();

    let mut events = Connection::new()
        .await
        .unwrap()
        .subscribe(&subs)
        .await
        .unwrap();
    while let Some(event) = events.next().await {
        if let Ok(event) = event {
            for handler in &mut handlers {
                handler.handle(&event);
            }
        }
    }
}

trait SwayIpcHandler {
    fn register(&mut self, subs: &mut HashSet<EventType>);
    fn handle(&mut self, event: &Event);
}

struct System76 {
    dbus: Arc<DBus>,
    msg: Message,
}

impl System76 {
    pub fn new(dbus: Arc<DBus>) -> Self {
        let msg = Message::method_call(
            "com.system76.Scheduler".try_into().unwrap(),
            "/com/system76/Scheduler".try_into().unwrap(),
            "com.system76.Scheduler".try_into().unwrap(),
            "SetForegroundProcess".try_into().unwrap(),
        );
        Self { dbus, msg }
    }
}

impl SwayIpcHandler for System76 {
    fn register(&mut self, subs: &mut HashSet<EventType>) {
        subs.insert(EventType::Window);
    }
    fn handle(&mut self, event: &Event) {
        if let Event::Window(window) = event {
            if window.change != WindowChange::Focus {
                return;
            }
            if let Some(pid) = window.container.pid.and_then(|x| u32::try_from(x).ok()) {
                let dbus = self.dbus.clone();
                let mut msg = self.msg.clone();
                msg.add_value(Value::Uint32(pid));
                tokio::spawn(async move {
                    drop(dbus.call(msg).await);
                });
            }
        }
    }
}
