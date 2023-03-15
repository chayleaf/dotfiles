{ lib, raw, call }: let defs = map (line: 
  if lib.hasPrefix "function/" line then let split = lib.splitString "/" (lib.removePrefix "function/" line); in {
    type = "function";
    arity = lib.toInt (builtins.elemAt split 0);
    value = builtins.elemAt split 1;
  } else if lib.hasPrefix "string/" line then {
    type = "string";
    value = lib.removePrefix "string/" line;
  } else if lib.hasPrefix "boolean/" line then {
    type = "boolean";
    value = lib.removePrefix "boolean/" line;
  } else if lib.hasPrefix "number/" line then {
    type = "number";
    value = lib.removePrefix "number/" line;
  } else {
    type = "ignore";
    value = "____ignore.___ignore";
  }) (lib.splitString "\n" (builtins.readFile ./vim-lua.txt));
  process' = val: (
    if val.type == "function" then (
      #if val.arity == 0 then
      args: if args == "GET_INFO" then val else call (raw val.value) args
      #else if val.arity == 1 then (a: if a == "GET_INFO" then val else call (raw val.value) [a])
      #else (a: if a == "GET_INFO" then val else call (raw val.value) a)
    ) else raw val.value
  );
  process = val: lib.setAttrByPath (lib.splitString "." val.value) (process' val);
  processOpt = o: val: lib.setAttrByPath ["vim" o val] (raw "vim.${o}.${val}");
  processVar = val:
    if lib.hasPrefix "b:" val then lib.setAttrByPath ["vim" "b" (lib.removePrefix "b:" val)] (raw "vim.b.${val}")
    else if lib.hasPrefix "v:" val then lib.setAttrByPath ["vim" "v" (lib.removePrefix "v:" val)] (raw "vim.v.${val}")
    else if lib.hasPrefix "w:" val then lib.setAttrByPath ["vim" "w" (lib.removePrefix "w:" val)] (raw "vim.w.${val}")
    else if lib.hasPrefix "t:" val then lib.setAttrByPath ["vim" "t" (lib.removePrefix "t:" val)] (raw "vim.t.${val}")
    else if lib.hasPrefix "v:" val then lib.setAttrByPath ["vim" "v" (lib.removePrefix "v:" val)] (raw "vim.v.${val}")
    else lib.setAttrByPath ["vim" "g" val] (raw "vim.g.${val}");
  setPath = path: key: val: if builtins.isAttrs val
    then (builtins.mapAttrs (setPath "${path}${key}.") val) // { __kind = "var"; _name = "${path}${key}"; }
    else val;
  opts = (lib.splitString "\n" (builtins.readFile ./vim-opts.txt));
  vars = (lib.splitString "\n" (builtins.readFile ./vim-vars.txt));
  zip = x: if x == [] then {} else lib.recursiveUpdate (zip (builtins.tail x)) (builtins.head x);
  patch = builtins.mapAttrs (k: v: if k == "vim" then v // {
    inspect = process' {
      type = "function";
      arity = 2;
      value = "vim.inspect";
    };
    cmd = process' {
      type = "function";
      arity = 1;
      value = "vim.cmd";
    };
    fn = (if v?fn then v.fn else {}) // {
      visualmode = {
        type = "function";
        arity = 0;
        value = "vim.fn.visualmode";
      };
    };
  } else v);
in
  patch (builtins.mapAttrs (setPath "")
    (zip (
      (map process defs)
      ++ (map process (map (x: x // {value = "vim" + (lib.removePrefix "vim.shared" x.value); }) (builtins.filter ({value,...}: lib.hasPrefix "vim.shared" value) defs)))
      ++ (map (processOpt "o") opts)
      ++ (map (processOpt "opt") opts)
      ++ (map processVar vars)
    )))
