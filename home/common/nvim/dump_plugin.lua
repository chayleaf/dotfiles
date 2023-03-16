local seen = {}

local result = {}

local function mark(t)
    seen[t] = true
    for k,v in pairs(t) do
        if type(v) == "table" and not seen[v] then
            mark(v)
        end
    end
end

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
                    if not res[k] and seen[v] ~= true then
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

local json = require "cjson"

-- mark globals before requiring package
mark(_G)

local package = "@package@"

result = { __kind = "var", _type = "table", _name = "" }
dump2(require(package), "", result)

print(json.encode(result))

