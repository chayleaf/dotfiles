use futures_util::stream::StreamExt;
use std::collections::HashSet;
use swayipc_async::{Connection, Event, EventType, WindowChange};

#[tokio::main(flavor = "current_thread")]
async fn main() {
    let sys_dbus = Box::leak(Box::new(zbus::Connection::system().await.unwrap()));
    let _ses_dbus = Box::leak(Box::new(zbus::Connection::session().await.unwrap()));

    let mut handlers = Vec::<Box<dyn SwayIpcHandler>>::new();
    for args in std::env::args().skip(1) {
        handlers.push(match args.as_str() {
            "system76-scheduler" => Box::new(System76::new(sys_dbus).await),
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
    loop {
        drop(start(&subs, &mut handlers).await);
        tokio::time::sleep(std::time::Duration::from_secs(10)).await;
    }
}

async fn start(subs: &[EventType], handlers: &mut [Box<dyn SwayIpcHandler>]) -> Result<(), swayipc_async::Error> {
    let mut events = Connection::new()
        .await?
        .subscribe(&subs)
        .await?;
    while let Some(event) = events.next().await {
        match event {
            Ok(event) => {
                for handler in &mut *handlers {
                    handler.handle(&event);
                }
            }
            Err(err) => match err {
                swayipc_async::Error::Io(_) 
                | swayipc_async::Error::InvalidMagic(_)
                | swayipc_async::Error::SubscriptionFailed(_)
                    => return Err(err),
                _ => {}
            }
        }
    }
    Ok(())
}

trait SwayIpcHandler {
    fn register(&mut self, subs: &mut HashSet<EventType>);
    fn handle(&mut self, event: &Event);
}

#[zbus::dbus_proxy(
    interface = "com.system76.Scheduler",
    default_service = "com.system76.Scheduler",
    default_path = "/com/system76/Scheduler"
)]
pub trait System76Scheduler {
    /// This process will have its process group prioritized over background processes
    fn set_foreground_process(&mut self, pid: u32) -> zbus::fdo::Result<()>;
}

struct System76<'a> {
    proxy: System76SchedulerProxy<'a>,
}

impl<'a> System76<'a> {
    pub async fn new(dbus: &'a zbus::Connection) -> System76<'a> {
        let proxy = System76SchedulerProxy::new(dbus).await.unwrap();
        Self { proxy }
    }
}

impl SwayIpcHandler for System76<'static> {
    fn register(&mut self, subs: &mut HashSet<EventType>) {
        subs.insert(EventType::Window);
    }
    fn handle(&mut self, event: &Event) {
        if let Event::Window(window) = event {
            if window.change != WindowChange::Focus {
                return;
            }
            if let Some(pid) = window.container.pid.and_then(|x| u32::try_from(x).ok()) {
                let mut proxy = self.proxy.clone();
                tokio::spawn(async move {
                    drop(proxy.set_foreground_process(pid).await);
                });
            }
        }
    }
}

