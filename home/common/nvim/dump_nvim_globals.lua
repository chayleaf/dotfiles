-- globals.lua
-- list all global variables
-- :enew|pu=execute('luafile /path/to/file.lua')
-- list vim vars
-- :new | put! =getcompletion('*', 'var')
-- list events
-- :new | put! =getcompletion('*', 'event')
-- list options
-- :new | put! =getcompletion('*', 'option')

local seen={}

function dump(t,i)
    seen[t]=true
    local s={}
    local n=0
    for k in pairs(t) do
        n=n+1 s[n]=k
    end
    local p0 = "package.loaded."
    local i1 = (i:sub(0, #p0) == p0) and i:sub(#p0+1) or i
    local p1 = "package.preload."
    local i2 = (i1:sub(0, #p1) == p1) and i1:sub(#p1+1) or i1
    for k,v in ipairs(s) do
        local v0=t[v]
        if type(v0)=="table" and not seen[v0] then
            dump(v0,i1..v..".")
        elseif v ~= "vim._meta" and v ~= "vim._init_packages" and v ~= "table.clear" and v ~= "table.new" and type(v0) == "function" and i:sub(0, #p1) == p1 then
            dump(v0(),i2..v..".")
        elseif type(v0) == "function" then
            print("function/"..debug.getinfo(v0).nparams.."/"..i..v)
        elseif type(v0) ~= "table" then
            print(type(v0).."/"..i..v)
        end
    end
end

dump(_G,"")

