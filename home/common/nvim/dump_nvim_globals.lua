local seen = {}

local result = {}

local function dump2(t, path, res)
    seen[t] = path
    if path ~= "" then
        path = path.."."
    end
    for k,v in pairs(t) do
        k = tostring(k)
        if path ~= "" or k ~= "package" then
            if type(v) == "table" then
                if seen[v] then
                    if not res[k] then
                        res[k] = { __kind = "rec", path = seen[v] }
                    end
                else
                    if not res[k] then
                        res[k] = {}
                    end
                    res[k].__kind = "var"
                    res[k]._type = "table"
                    res[k]._name = path..k
                    dump2(v, path..k, res[k])
                end
            elseif type(v) == "function" then
                local info = debug.getinfo(v)
                res[k] = {
                    __kind = "var",
                    _name = path..k,
                    _type = "function",
                    _minArity = info.nparams
                }
                if not info.isvararg then
                    res[k]["maxArity"] = info.nparams
                end
            else
                res[k] = {
                    __kind = "var", _name = path..k, _type = type(v)
                }
            end
        end
    end
end

local function dumpf(t, path, res)
    for k,v in pairs(t.funcs) do
        if type(v.args) == "table" then
            -- 1 value: min bound
            -- 2 values: min and max bound
            if #v.args == 1 then
                res[k] = {
                    __kind = "var",
                    _name = path..k,
                    _type = "function",
                    _minArity = v.args[1]
                }
            elseif #v.args == 2 then
                res[k] = {
                    __kind = "var",
                    _name = path..k,
                    _type = "function",
                    _minArity = v.args[1],
                    _maxArity = v.args[2]
                }
            else
                print("ERROR")
            end
        elseif type(v.args) == "number" then
            -- exact arg count
            res[k] = {
                __kind = "var",
                _name = path..k,
                _type = "function",
                _minArity = v.args,
                _maxArity = v.args
            }
        else
            -- zero args
            res[k] = {
                __kind = "var",
                _name = path..k,
                _type = "function",
                _minArity = 0,
                _maxArity = 0
            }
        end
    end
end

local function dumpo(t, path, opt, res)
    local types = {
        bool = "boolean",
        string = "string",
        number = "number",
    }
    local key_value_options = {
      fillchars = true,
      listchars = true,
      winhighlight = true,
    }
    for k,v in pairs(t.options) do
        if opt and key_value_options[v.full_name] then
            -- kv map
            res[v.full_name] = {
                __kind = "var",
                _name = path..v.full_name,
                _type = "table"
            }
            if type(v.abbreviation) == "string" then
                res[path..v.full_name] = { __kind = "rec", path = path..v.full_name, }
            end
        elseif opt and v.list then
            -- list
            res[v.full_name] = {
                __kind = "var",
                _name = path..v.full_name,
                _type = "table"
            }
            if type(v.abbreviation) == "string" then
                res[v.abbreviation] = { __kind = "rec", path = path..v.full_name, }
            end
        elseif not opt then
            res[v.full_name] = {
                __kind = "var",
                _name = path..v.full_name,
                _type = types[v.type],
            }
            if type(v.abbreviation) == "string" then
                res[v.abbreviation] = { __kind = "rec", path = path..v.full_name, }
            end
        end
    end
end

local json = require "json"

--- DUMPING BUILTINS
result["vim"] = { __kind = "var", _type = "table", _name = "vim" }
for k in pairs(vim._submodules) do
    result["vim"][k] = { __kind = "var", _type = "table", _name = "vim."..k }
    dump2(vim[k], "vim."..k, result["vim"][k])
end
dump2(package.loaded["vim.shared"], "vim", result["vim"])
-- for main thread only?
dump2(package.loaded["vim._editor"], "vim", result["vim"])
dump2(_G, "", result)
-- eval.lua from https://github.com/neovim/neovim/blob/674e23f19c509381e2476a3990e21272e362e3a4/src/nvim/eval.lua
dumpf(require("eval"), "vim.fn.", result["vim"]["fn"])
-- https://github.com/neovim/neovim/blob/674e23f19c509381e2476a3990e21272e362e3a4/src/nvim/options.lua
dumpo(require("options"), "vim.o.", false, result["vim"]["o"])
dumpo(require("options"), "vim.opt.", true, result["vim"]["opt"])
print(json.encode(result))

