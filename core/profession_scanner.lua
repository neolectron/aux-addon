module 'aux.core.profession_scanner'

local T = require 'T'
local aux = require 'aux'
local info = require 'aux.util.info'

-- Profession scanner: Dynamically scan profession recipes when window opens
-- Stores in account-wide cache for cross-character sharing

function aux.handle.LOAD()
    -- Initialize cache structure
    aux.account_data.profession_cache = aux.account_data.profession_cache or {}
    
    -- Hook profession window events
    aux.event_listener('TRADE_SKILL_SHOW', function()
        scan_trade_skill()
    end)
    
    aux.event_listener('CRAFT_SHOW', function()
        scan_craft()
    end)
end

-- Scan vendor price for an item using multiple sources
local function get_vendor_price_for_item(item_id, item_link)
    -- Use existing vendor price sources
    local vendor_price = info.get_vendor_price(item_id)
    if vendor_price then
        return vendor_price
    end
    
    -- Default to 1 copper if not in database - allows recipes to show even without exact vendor price
    -- The profit calculation will use auction house prices instead
    return 1
end

-- Scan TradeSkill professions (most professions)
function scan_trade_skill()
    local profession_name = GetTradeSkillLine()
    if not profession_name or profession_name == "UNKNOWN" then
        return
    end
    
    local char_key = GetCVar("realmName") .. "|" .. UnitName("player")
    local cache_key = profession_name .. "|" .. char_key
    
    local recipes = {}
    local num_recipes = GetNumTradeSkills()
    
    for i = 1, num_recipes do
        local recipe_name, skill_type = GetTradeSkillInfo(i)
        
        -- Skip headers and unavailable recipes
        if recipe_name and skill_type ~= "header" then
            local output_link = GetTradeSkillItemLink(i)
            if output_link then
                local output_id = info.parse_link(output_link)
                
                if output_id then
                    -- Get output quantity by parsing tooltip or recipe info
                    local min_made, max_made = GetTradeSkillNumMade(i)
                    local output_quantity = max_made or 1
                    
                    -- Get vendor price
                    local vendor_price = get_vendor_price_for_item(output_id, output_link)
                    
                    -- Get materials
                    local materials = {}
                    local num_reagents = GetTradeSkillNumReagents(i)
                    for j = 1, num_reagents do
                        local mat_name, _, mat_quantity = GetTradeSkillReagentInfo(i, j)
                        local mat_link = GetTradeSkillReagentItemLink(i, j)
                        if mat_link then
                            local mat_id = info.parse_link(mat_link)
                            local mat_vendor_price = get_vendor_price_for_item(mat_id, mat_link)
                            
                            tinsert(materials, {
                                item_id = mat_id,
                                name = mat_name,
                                quantity = mat_quantity,
                                base_value = mat_vendor_price,
                            })
                        end
                    end
                    
                    -- Only store recipe if we have complete data
                    if getn(materials) > 0 then
                        recipes[recipe_name] = {
                            output_id = output_id,
                            vendor_price = vendor_price,
                            output_quantity = output_quantity,
                            materials = materials,
                            profession = profession_name,
                            skill_type = skill_type,
                            scanned_at = time(),
                        }
                    end
                end
            end
        end
    end
    
    -- Store in cache
    aux.account_data.profession_cache[cache_key] = recipes
    
    aux.print(format('Scanned %d %s recipes', aux.size(recipes), profession_name))
    
    -- Notify Craft tab to update its UI
    if aux.tabs and aux.tabs.craft and aux.tabs.craft.update_cache_status then
        aux.tabs.craft.update_cache_status()
    end
end

-- Scan Craft professions (Enchanting)
function scan_craft()
    local profession_name = GetCraftDisplaySkillLine()
    if not profession_name then
        return
    end
    
    local char_key = GetCVar("realmName") .. "|" .. UnitName("player")
    local cache_key = profession_name .. "|" .. char_key
    
    local recipes = {}
    local num_recipes = GetNumCrafts()
    
    for i = 1, num_recipes do
        local recipe_name, _, skill_type = GetCraftInfo(i)
        
        -- Skip headers
        if recipe_name and skill_type ~= "header" then
            local output_link = GetCraftItemLink(i)
            if output_link then
                local output_id = info.parse_link(output_link)
                
                -- Enchanting usually makes 1
                local output_quantity = 1
                
                -- Get vendor price
                local vendor_price = get_vendor_price_for_item(output_id, output_link)
                
                -- Get materials
                local materials = {}
                local num_reagents = GetCraftNumReagents(i)
                for j = 1, num_reagents do
                    local mat_name, _, mat_quantity = GetCraftReagentInfo(i, j)
                    local mat_link = GetCraftReagentItemLink(i, j)
                    if mat_link then
                        local mat_id = info.parse_link(mat_link)
                        local mat_vendor_price = get_vendor_price_for_item(mat_id, mat_link)
                        
                        tinsert(materials, {
                            item_id = mat_id,
                            name = mat_name,
                            quantity = mat_quantity,
                            base_value = mat_vendor_price,
                        })
                    end
                end
                
                -- Only store recipe if we have complete data
                if output_id and getn(materials) > 0 then
                    recipes[recipe_name] = {
                        output_id = output_id,
                        vendor_price = vendor_price,
                        output_quantity = output_quantity,
                        materials = materials,
                        profession = profession_name,
                        skill_type = skill_type,
                        scanned_at = time(),
                    }
                end
            end
        end
    end
    
    -- Store in cache
    aux.account_data.profession_cache[cache_key] = recipes
    
    aux.print(format('Scanned %d %s recipes', aux.size(recipes), profession_name))
    
    -- Notify Craft tab to update its UI
    if aux.tabs and aux.tabs.craft and aux.tabs.craft.update_cache_status then
        aux.tabs.craft.update_cache_status()
    end
end

-- Local helper to get cached recipes (used internally)
local function get_all_cached_recipes()
    local char_key = GetCVar("realmName") .. "|" .. UnitName("player")
    local all_recipes = {}
    
    if not aux.account_data or not aux.account_data.profession_cache then
        return all_recipes
    end
    
    for cache_key, recipes in pairs(aux.account_data.profession_cache) do
        -- Match recipes for this character
        if strfind(cache_key, "|" .. char_key) then
            for recipe_name, recipe_data in pairs(recipes) do
                all_recipes[recipe_name] = recipe_data
            end
        end
    end
    
    return all_recipes
end

-- Get all cached recipes for current character (exported)
function M.get_cached_recipes()
    return get_all_cached_recipes()
end

-- Get cached recipes for specific profession
function M.get_profession_recipes(profession_name)
    local char_key = GetCVar("realmName") .. "|" .. UnitName("player")
    local cache_key = profession_name .. "|" .. char_key
    
    if not aux.account_data or not aux.account_data.profession_cache then
        return {}
    end
    
    return aux.account_data.profession_cache[cache_key] or {}
end

-- Check if cache is empty
function M.has_cached_recipes()
    return aux.size(get_all_cached_recipes()) > 0
end

-- Clear cache (for debugging)
function M.clear_cache()
    aux.account_data.profession_cache = {}
    aux.print('Profession cache cleared')
end
