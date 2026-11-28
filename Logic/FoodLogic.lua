-- FOODLOGIC
-- Inventory food scan, player selection, and auto-eat enable.
-- Profile food remains the default when nothing is selected.
-- settings.food_active  - on/off toggle (default true)
-- settings.selected_food - remembered pick from inventory ('' = profile default)

-- Only true food (gives the Food buff). Never medicines, echo drops,
-- antidotes, oils, ninjutsu tools, or other usable consumables.
-- Windower res.items.category for real food is "Foods".
local function Item_Is_Food(item)
    if not item then
        return false
    end
    local cat = string.lower(tostring(item.category or ''))
    -- Strict: Foods only. Type codes match too many usables (Echo Drops, etc.).
    if cat == 'foods' then
        return true
    end
    return false
end

-- Scan inventory (bag 0) for food. Returns { { name=, count=, id= }, ... }.
function Scan_Inventory_Foods()
    local found = {}
    local inv = windower.ffxi.get_items(0)
    if not inv or not res or not res.items then
        return {}
    end
    for slot = 1, inv.max or 80 do
        local entry = inv[slot]
        if entry and entry.id and entry.id > 0 and (entry.count or 0) > 0 then
            local item = res.items[entry.id]
            if item and item.en and Item_Is_Food(item) then
                local key = string.lower(item.en)
                if found[key] then
                    found[key].count = found[key].count + (entry.count or 1)
                else
                    found[key] = {
                        name = item.en,
                        count = entry.count or 1,
                        id = entry.id,
                    }
                end
            end
        end
    end
    local list = {}
    for _, e in pairs(found) do
        list[#list + 1] = e
    end
    table.sort(list, function(a, b)
        return string.lower(a.name) < string.lower(b.name)
    end)
    return list
end

function Food_Active()
    if settings and settings.food_active == false then
        return false
    end
    return true
end

function Get_Selected_Food()
    if settings and type(settings.selected_food) == 'string' and settings.selected_food ~= '' then
        return settings.selected_food
    end
    return nil
end

function Set_Selected_Food(name)
    if not settings then
        return false
    end
    if type(name) ~= 'string' or name == '' then
        settings.selected_food = ''
        return true
    end
    settings.selected_food = name
    return true
end

-- True when the named food is in inventory (bag 0).
function Has_Food_Available(food_name)
    if not food_name or food_name == '' then
        return false
    end
    local inv = windower.ffxi.get_items(0)
    if not inv then
        return false
    end
    local want = string.lower(tostring(food_name))
    for slot = 1, inv.max or 80 do
        local entry = inv[slot]
        if entry and entry.id and entry.id > 0 and entry.count and entry.count > 0 then
            local item = res.items and res.items[entry.id]
            if item and item.en and string.lower(item.en) == want then
                return true
            end
        end
    end
    return false
end

-- Combat pick: selection if available, else profile default. Never blocks.
function Get_Food()
    if not Food_Active() then
        return nil
    end
    local selected = Get_Selected_Food()
    if selected and Has_Food_Available(selected) then
        return selected
    end
    local profile_food = (active_profile and active_profile.food) or food
    if profile_food and Has_Food_Available(profile_food) then
        return profile_food
    end
    if selected then
        return selected
    end
    return profile_food
end
