{ lib
, ...
}:

{
  options.phone = {
    mac = lib.mkOption {
      description = "mac address";
      type = lib.types.str;
    };
  };
}
