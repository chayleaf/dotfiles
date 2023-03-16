{ stdenvNoCC
, lib
, neovim-unwrapped
, neovimUtils
, lua51Packages
, wrapNeovimUnstable
, call
, substituteAll
, plugins
# , extraLuaPackages ? []
, ... }: 

let update = self: prefix: lib.mapAttrs (k: v: let
  v' = update self prefix v;
  in (if builtins.isAttrs v && v?__kind then (
    if v.__kind == "rec" then
      lib.attrByPath (lib.splitString "." v.path) self
    else if v.__kind == "var" && v._type == "function" then
      (args: if args == "GET_INFO" then v' else call v' args)
    else v'
  ) else if builtins.isAttrs v then v'
  else if prefix != "" && k == "_name" then
    (if v == "" then prefix else "${prefix}.${v}")
  else v));
data = builtins.fromJSON (builtins.readFile ./vim-defs.json);
result = update result "" data;
config = neovimUtils.makeNeovimConfig {
  extraLuaPackages = p: [ p.cjson ];
  # inherit extraLuaPackages;
  plugins = map (plugin: if plugin?plugin then {plugin=plugin.plugin;} else {inherit plugin;}) plugins;
};
neovim = wrapNeovimUnstable neovim-unwrapped config;
getReqAttrs = name: builtins.fromJSON (builtins.readFile (stdenvNoCC.mkDerivation {
  phases = [ "installPhase" ];
  name = "neovim-require-${name}.json";
  dumpPlugin = substituteAll {
    src = ./dump_plugin.lua;
    package = name;
  };
  nativeBuildInputs = [ neovim ];
  installPhase = ''
    export HOME="$TMPDIR"
    nvim --headless -S $dumpPlugin -i NONE -u NONE -n -c 'echo""|qall!' 2>$out
  '';
}));
req = name: let result = update result "require(\"${name}\")" (getReqAttrs name); in result;
_reqbind = name: varname: let result = update result "${varname}" (getReqAttrs name); in result;
in result // {
  inherit req _reqbind;
}
