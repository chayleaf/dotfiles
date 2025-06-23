{ lib, ... }:

{
  quoteListenAddr = addr: if lib.hasInfix ":" addr then "[${addr}]" else addr;
}
