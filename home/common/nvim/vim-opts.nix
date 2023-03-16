{ stdenvNoCC
, lib
, neovim-unwrapped
, neovimUtils
, lua51Packages
, wrapNeovimUnstable
, CALL
, isGetInfo
, substituteAll
, plugins
, compileExpr
# , extraLuaPackages ? []
, ... }: 

# TODO: bfs instead of dfs in var dumps

let
update = self: prefix: lib.mapAttrs (k: v: let
  v' = update self prefix v;
  in (if builtins.isAttrs v && v?__kind then (
    if v.__kind == "rec" then
      lib.attrByPath (lib.splitString "." v.path) null self
    else if v.__kind == "var" && v._type == "function" then
        (args:
          if isGetInfo args then v'
          else CALL v' args)
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
  name = "neovim-types-${name}.json";
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
req = name: let res = update res name (getReqAttrs name); in res;
REQ = name: req "require(\"${name}\")";
# the code must not use external state! this can't be checked
# this could (?) be fixed with REQBIND', but I don't need it
REQ' = code: req (compileExpr { moduleName = "req"; scope = 1; } code);
_reqbind = name: varname: let s = "require(\"${name}\")"; res = update res "${varname}" (getReqAttrs s); in res;
in result // {
  inherit REQ REQ' _reqbind;
}
