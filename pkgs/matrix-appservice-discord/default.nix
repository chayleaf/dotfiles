{ matrix-appservice-discord, fetchpatch }:

matrix-appservice-discord.overrideAttrs (old: {
  doCheck = false;
  patches = (old.patches or []) ++ [
    # https://github.com/matrix-org/matrix-appservice-discord/pull/917
    (fetchpatch {
      url = "https://github.com/matrix-org/matrix-appservice-discord/commit/eb989fa710e8db4ebc8f2ce36c6679ee6cbc1a44.patch";
      hash = "sha256-GPeFDw3XujqXHJveHSsBHwHuG51vad50p55FX1Esq58=";
      name = "set-missing-config-defaults.patch";
    })
    # https://github.com/matrix-org/matrix-appservice-discord/pull/918
    (fetchpatch {
      url = "https://github.com/matrix-org/matrix-appservice-discord/commit/a4cd5e3a6a2d544adac2a263e164671c8a9009d9.patch";
      hash = "sha256-qQJ4V6/Ns2Msu8+X8JoEycuQ2Jc90TXulsuLLmPecGU=";
      name = "dont-send-filenames.patch";
    })
    # https://github.com/matrix-org/matrix-appservice-discord/pull/878/
    (fetchpatch {
      url = "https://github.com/matrix-org/matrix-appservice-discord/commit/fc850ba2473973e28858449ec4020380470d78b2.patch";
      hash = "sha256-Lq0FWmR08wLsoq4APRTokZzb7U2po98pgyxH4UR/9/M=";
      name = "bridge-discord-replies-1.patch";
    })
    (fetchpatch {
      url = "https://github.com/matrix-org/matrix-appservice-discord/commit/86388901fa44d5d0f9d3dec8727c18cc00d613e7.patch";
      hash = "sha256-XcLbKJPmFZElzwU4YS8Md8dNLajddJPKmau0U65bp00=";
      name = "bridge-discord-replies-2.patch";
    })
    (fetchpatch {
      url = "https://github.com/matrix-org/matrix-appservice-discord/commit/8299c626188e676723a708e49635d2c4afa26ffa.patch";
      hash = "sha256-ZfUwpJ21/m3QbktbxxHyO8Lcl/IuDhaSKQRXBEPeJBo=";
      name = "bridge-discord-replies-3.patch";
    })
    # https://github.com/matrix-org/matrix-appservice-discord/pull/819
    (fetchpatch {
      url = "https://github.com/matrix-org/matrix-appservice-discord/commit/1c3223387aaf78ba5637f58ca57bd8206ad0446c.patch";
      hash = "sha256-3hxyqjI9F4j/XBq/59b7c2PorYRN2mR4XZJjpygs9dI=";
      name = "bridge-matrix-edits-1.patch";
    })
    (fetchpatch {
      url = "https://github.com/matrix-org/matrix-appservice-discord/commit/f8e9449908b332d97f11932fb835552adca0aa5b.patch";
      hash = "sha256-1qb4Zah1XKzxTpVJqOOqz+TiXMFmnsIMZeuqJQdqSIA=";
      name = "bridge-matrix-edits-2.patch";
    })
    # https://github.com/matrix-org/matrix-appservice-discord/pull/862
    (fetchpatch {
      url = "https://github.com/matrix-org/matrix-appservice-discord/commit/3106957ebd857bc88ba3f62182a61dd00275f2fc.patch";
      hash = "sha256-Xf+TuWXNVqi+0YRwBbCkLcMfsYNxq1ZlsgLWpwjqPww=";
      name = "discord-to-matrix-reactions-1.patch";
    })
    (fetchpatch {
      url = "https://github.com/matrix-org/matrix-appservice-discord/commit/a8186874b03c545a8728892b299a4367776fc538.patch";
      hash = "sha256-Hq2HY44hPeGPXI3MglyN7Am+NCNAHAbr2hYhXvDYtGk=";
      name = "discord-to-matrix-reactions-2.patch";
    })
    (fetchpatch {
      url = "https://github.com/matrix-org/matrix-appservice-discord/commit/da2c3b88c7dd4f3a679890c58f934e9b2ed775df.patch";
      hash = "sha256-4NMAr+Ni+7pI/I007YH5Y+4ZwAhwg91/BXGvLVcO0BQ=";
      name = "discord-to-matrix-reactions-3.patch";
    })
    (fetchpatch {
      url = "https://github.com/matrix-org/matrix-appservice-discord/commit/a33f269c88c432c532d7816f180e5262d73ebf02.patch";
      hash = "sha256-0WkfDkQsDoxfKH3MgPb893UPDPxeWueQwVSaxD2RKAw=";
      name = "discord-to-matrix-reactions-4.patch";
    })
    ./reactions-as-mxc-urls.patch
    ./disable-attachment-forwarding-to-matrix.patch
    ./reduce-spamminess.patch
  ];
})
