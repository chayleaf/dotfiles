use cpal::{
    traits::{DeviceTrait, HostTrait, StreamTrait},
    SampleFormat,
};
use futures_util::stream::StreamExt;
use std::collections::HashSet;
use swayipc_async::{Connection, Event, EventType, WindowChange};

mod email;

#[tokio::main(flavor = "current_thread")]
async fn main() {
    let sys_dbus = Box::leak(Box::new(zbus::Connection::system().await.unwrap()));
    let ses_dbus = Box::leak(Box::new(zbus::Connection::session().await.unwrap()));

    let mut handlers = Vec::<Box<dyn SwayIpcHandler>>::new();
    let mut panic = true;
    let mut args = std::env::args().skip(1);
    let mode = args.next().expect("must pass mode (cli/daemon)");
    match mode.as_str() {
        "cli" => {
            email::run_cli().await;
            return;
        }
        "daemon" => {}
        _ => panic!("mode must be cli or daemon"),
    }
    for arg in args {
        handlers.push(match arg.as_str() {
            "system76-scheduler" => Box::new(System76::new(sys_dbus).await),
            "empty-sound" => {
                panic = false;
                tokio::spawn(async {
                    play_empty_sound().await;
                });
                continue;
            }
            "email" => {
                panic = false;
                let email = email::Email::new(ses_dbus).await;
                tokio::spawn(email.run());
                continue;
            }
            _ => panic!("handler not supported"),
        })
    }
    if handlers.is_empty() {
        if panic {
            panic!("no handlers set up");
        } else {
            futures_util::future::pending::<()>().await;
        }
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

async fn start(
    subs: &[EventType],
    handlers: &mut [Box<dyn SwayIpcHandler>],
) -> Result<(), swayipc_async::Error> {
    let mut events = Connection::new().await?.subscribe(&subs).await?;
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
                | swayipc_async::Error::SubscriptionFailed(_) => return Err(err),
                _ => {}
            },
        }
    }
    Ok(())
}

async fn play_empty_sound() {
    let device = cpal::default_host()
        .default_output_device()
        .expect("no output device available");
    let supported_config = device
        .supported_output_configs()
        .unwrap()
        .find(|config| {
            config.sample_format() == SampleFormat::F32
                && (config.min_sample_rate()..=config.max_sample_rate())
                    .contains(&cpal::SampleRate(44100))
                && config.channels() == 1
        })
        .unwrap()
        .with_sample_rate(cpal::SampleRate(44100));
    let config = supported_config.into();
    let stream = Box::leak(Box::new(
        device
            .build_output_stream(
                &config,
                |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
                    for sample in data.iter_mut() {
                        *sample = 1.0 / 1985.0;
                    }
                },
                |err| eprintln!("an error occurred on the output audio stream: {}", err),
                None,
            )
            .unwrap(),
    ));
    stream.play().unwrap();
    futures_util::future::pending::<()>().await;
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
