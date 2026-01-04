module 'aux.core.craft_vendor'

local T = require 'T'
local aux = require 'aux'
local info = require 'aux.util.info'
local money = require 'aux.util.money'

-- Craft-to-Vendor Recipe Database
-- For Mining + Engineering professions
-- Each recipe: materials needed, output item, vendor price (per unit), output quantity
-- base_value = opportunity cost of material (vendor sell price)
M.recipes = {
    -- ============ SMELTING (Mining) ============
    -- Only profitable conversions - buy ore cheap, smelt, vendor bars
    
    ["Copper Bar"] = {
        output_id = 2840,
        vendor_price = 10,  -- 10c
        output_quantity = 1,
        materials = {
            { item_id = 2770, name = "Copper Ore", quantity = 1, base_value = 5 },
        }
    },
    ["Tin Bar"] = {
        output_id = 3576,
        vendor_price = 25,  -- 25c
        output_quantity = 1,
        materials = {
            { item_id = 2771, name = "Tin Ore", quantity = 1, base_value = 25 },
        }
    },
    ["Bronze Bar"] = {
        output_id = 2841,
        vendor_price = 50,  -- 50c each, makes 2 = 1s total
        output_quantity = 2,
        materials = {
            { item_id = 2840, name = "Copper Bar", quantity = 1, base_value = 10 },
            { item_id = 3576, name = "Tin Bar", quantity = 1, base_value = 25 },
        }
    },
    ["Iron Bar"] = {
        output_id = 3575,
        vendor_price = 200,  -- 2s
        output_quantity = 1,
        materials = {
            { item_id = 2772, name = "Iron Ore", quantity = 1, base_value = 150 },
        }
    },
    ["Gold Bar"] = {
        output_id = 3577,
        vendor_price = 600,  -- 6s
        output_quantity = 1,
        materials = {
            { item_id = 2776, name = "Gold Ore", quantity = 1, base_value = 300 },
        }
    },
    ["Mithril Bar"] = {
        output_id = 3860,
        vendor_price = 400,  -- 4s
        output_quantity = 1,
        materials = {
            { item_id = 3858, name = "Mithril Ore", quantity = 1, base_value = 250 },
        }
    },
    ["Truesilver Bar"] = {
        output_id = 6037,
        vendor_price = 500,  -- 5s
        output_quantity = 1,
        materials = {
            { item_id = 7911, name = "Truesilver Ore", quantity = 1, base_value = 250 },
        }
    },
    ["Thorium Bar"] = {
        output_id = 12359,
        vendor_price = 600,  -- 6s
        output_quantity = 1,
        materials = {
            { item_id = 10620, name = "Thorium Ore", quantity = 1, base_value = 250 },
        }
    },
    
    -- ============ ENGINEERING - Blasting Powders ============
    -- Stone → Powder (all single-material, safe for auto-buy)
    
    ["Rough Blasting Powder"] = {
        output_id = 4357,
        vendor_price = 4,  -- 4c each, makes 2 = 8c total
        output_quantity = 2,
        materials = {
            { item_id = 2835, name = "Rough Stone", quantity = 1, base_value = 2 },
        }
    },
    ["Coarse Blasting Powder"] = {
        output_id = 4364,
        vendor_price = 12,  -- 12c each, makes 2 = 24c total
        output_quantity = 2,
        materials = {
            { item_id = 2836, name = "Coarse Stone", quantity = 1, base_value = 15 },
        }
    },
    ["Heavy Blasting Powder"] = {
        output_id = 4377,
        vendor_price = 150,  -- 1s50c each, makes 2 = 3s total
        output_quantity = 2,
        materials = {
            { item_id = 2838, name = "Heavy Stone", quantity = 1, base_value = 60 },
        }
    },
    ["Solid Blasting Powder"] = {
        output_id = 10505,
        vendor_price = 250,  -- 2s50c each, makes 2 = 5s total
        output_quantity = 2,
        materials = {
            { item_id = 7912, name = "Solid Stone", quantity = 1, base_value = 100 },
        }
    },
    ["Dense Blasting Powder"] = {
        output_id = 15992,
        vendor_price = 250,  -- 2s50c each, makes 2 = 5s total
        output_quantity = 2,
        materials = {
            { item_id = 12365, name = "Dense Stone", quantity = 1, base_value = 250 },
        }
    },
    
    -- ============ ENGINEERING - Components ============
    -- These can be profitable if materials are cheap
    
    ["Handful of Copper Bolts"] = {
        output_id = 4359,
        vendor_price = 12,  -- 12c each, makes 2 = 24c total
        output_quantity = 2,
        materials = {
            { item_id = 2840, name = "Copper Bar", quantity = 1, base_value = 10 },
        }
    },
    ["Copper Tube"] = {
        output_id = 4361,
        vendor_price = 120,  -- 1s20c
        output_quantity = 1,
        materials = {
            { item_id = 2840, name = "Copper Bar", quantity = 2, base_value = 10 },
            { item_id = 4357, name = "Rough Blasting Powder", quantity = 1, base_value = 1 },
        }
    },
    ["Bronze Tube"] = {
        output_id = 4371,
        vendor_price = 200,  -- 2s
        output_quantity = 1,
        materials = {
            { item_id = 2841, name = "Bronze Bar", quantity = 2, base_value = 50 },
            { item_id = 4357, name = "Rough Blasting Powder", quantity = 1, base_value = 1 },
        }
    },
    ["Whirring Bronze Gizmo"] = {
        output_id = 4375,
        vendor_price = 115,  -- 1s15c
        output_quantity = 1,
        materials = {
            { item_id = 2841, name = "Bronze Bar", quantity = 2, base_value = 50 },
            { item_id = 2592, name = "Wool Cloth", quantity = 1, base_value = 10 },
        }
    },
    ["Gyrochronatom"] = {
        output_id = 4389,
        vendor_price = 500,  -- 5s
        output_quantity = 1,
        materials = {
            { item_id = 3575, name = "Iron Bar", quantity = 1, base_value = 200 },
            { item_id = 10558, name = "Gold Power Core", quantity = 1, base_value = 100 },
        }
    },
    ["Mithril Tube"] = {
        output_id = 10559,
        vendor_price = 750,  -- 7s50c
        output_quantity = 1,
        materials = {
            { item_id = 3860, name = "Mithril Bar", quantity = 3, base_value = 400 },
        }
    },
    ["Unstable Trigger"] = {
        output_id = 10560,
        vendor_price = 1000,  -- 10s
        output_quantity = 1,
        materials = {
            { item_id = 3860, name = "Mithril Bar", quantity = 1, base_value = 400 },
            { item_id = 4338, name = "Mageweave Cloth", quantity = 1, base_value = 50 },
            { item_id = 10505, name = "Solid Blasting Powder", quantity = 1, base_value = 50 },
        }
    },
}

-- Build reverse lookup: material item_id -> list of recipes that use it
material_to_recipes = {}

-- Materials that are ONLY used in single-material recipes (safe to buy freely)
safe_materials = {}

function build_material_index()
    material_to_recipes = {}
    safe_materials = {}
    
    for recipe_name, recipe in pairs(recipes) do
        for _, mat in ipairs(recipe.materials) do
            if not material_to_recipes[mat.item_id] then
                material_to_recipes[mat.item_id] = {}
            end
            tinsert(material_to_recipes[mat.item_id], {
                recipe_name = recipe_name,
                recipe = recipe,
                mat_quantity = mat.quantity,
            })
        end
    end
    
    -- Identify "safe" materials: only used in single-material recipes
    -- These can be bought freely without worrying about ratio conflicts
    for item_id, recipe_list in pairs(material_to_recipes) do
        local is_safe = true
        for _, entry in ipairs(recipe_list) do
            -- Check if this recipe has multiple materials
            if getn(entry.recipe.materials) > 1 then
                is_safe = false
                break
            end
        end
        if is_safe then
            safe_materials[item_id] = true
        end
    end
end

-- Check if a material is "safe" (only used in single-material recipes)
function M.is_safe_material(item_id)
    return safe_materials[item_id] == true
end

-- Get the best available price for a material:
-- 1. Live market data from aux history (if available)
-- 2. Fall back to base_value (vendor sell price)
local function get_material_market_price(item_id, base_value)
    local history = require 'aux.core.history'
    local item_key = item_id .. ':0'  -- Most materials have suffix 0
    local market_price = history.value(item_key)
    
    if market_price and market_price > 0 then
        return market_price, true  -- Return price and "is_market_data" flag
    end
    
    -- Fall back to base_value if no market data
    return base_value or 0, false
end

-- Calculate the max price you should pay for a material to profit from crafting
-- Uses LIVE MARKET DATA for other materials when available
-- Returns: max_price per unit, recipe_name, profit_per_craft, uses_market_data
-- profit_margin: 0 = any profit (1c+), 0.5 = 50% margin, etc.
function M.get_max_mat_price(item_id, profit_margin)
    profit_margin = profit_margin or 0  -- Default: any profit (1c minimum)
    
    local recipe_list = material_to_recipes[item_id]
    if not recipe_list then return nil end
    
    local best_price = 0
    local best_recipe = nil
    local best_profit = 0
    local best_uses_market = false
    
    for _, entry in ipairs(recipe_list) do
        local recipe = entry.recipe
        local mat_qty = entry.mat_quantity
        
        -- Calculate total vendor value of output
        local total_vendor = recipe.vendor_price * recipe.output_quantity
        
        -- Calculate cost of OTHER materials using MARKET DATA when available
        local other_mats_cost = 0
        local all_have_market_data = true
        for _, mat in ipairs(recipe.materials) do
            if mat.item_id ~= item_id then
                -- Try to get market price, fall back to base_value
                local mat_cost, has_market = get_material_market_price(mat.item_id, mat.base_value)
                other_mats_cost = other_mats_cost + (mat_cost * mat.quantity)
                if not has_market then
                    all_have_market_data = false
                end
            end
        end
        
        -- Max we can pay for this material = (vendor_value - margin - other_costs) / quantity_needed
        local target_profit = total_vendor * profit_margin
        local available_for_mat = total_vendor - target_profit - other_mats_cost
        local max_price_per_unit = math.floor(available_for_mat / mat_qty)
        
        if max_price_per_unit > best_price then
            best_price = max_price_per_unit
            best_recipe = entry.recipe_name
            best_profit = total_vendor - other_mats_cost - (max_price_per_unit * mat_qty)
            best_uses_market = all_have_market_data
        end
    end
    
    return best_price, best_recipe, best_profit, best_uses_market
end

-- Evaluate a full recipe using current market prices for ALL materials
-- Returns: profit per craft, total_cost, uses_all_market_data
function M.evaluate_recipe(recipe_name)
    local recipe = recipes[recipe_name]
    if not recipe then return nil end
    
    local total_vendor = recipe.vendor_price * recipe.output_quantity
    local total_cost = 0
    local all_have_market_data = true
    local material_costs = {}
    
    for _, mat in ipairs(recipe.materials) do
        local mat_cost, has_market = get_material_market_price(mat.item_id, mat.base_value)
        local line_cost = mat_cost * mat.quantity
        total_cost = total_cost + line_cost
        
        material_costs[mat.name] = {
            unit_cost = mat_cost,
            quantity = mat.quantity,
            line_cost = line_cost,
            has_market_data = has_market,
        }
        
        if not has_market then
            all_have_market_data = false
        end
    end
    
    local profit = total_vendor - total_cost
    
    return {
        recipe_name = recipe_name,
        vendor_value = total_vendor,
        total_cost = total_cost,
        profit = profit,
        profit_margin = total_vendor > 0 and (profit / total_vendor) or 0,
        materials = material_costs,
        all_market_data = all_have_market_data,
    }
end

-- Find all profitable recipes based on current market data
-- Returns list of recipes sorted by profit
function M.find_profitable_recipes(min_profit)
    min_profit = min_profit or 1  -- Default: at least 1 copper profit
    
    local profitable = {}
    
    for recipe_name, _ in pairs(recipes) do
        local eval = M.evaluate_recipe(recipe_name)
        if eval and eval.profit >= min_profit then
            tinsert(profitable, eval)
        end
    end
    
    -- Sort by profit (highest first)
    table.sort(profitable, function(a, b) return a.profit > b.profit end)
    
    return profitable
end

-- Print profitable recipes using market data
function M.print_profitable()
    local money = require 'aux.util.money'
    aux.print(aux.color.gold('--- Profitable Crafts (Market Prices) ---'))
    
    local profitable = M.find_profitable_recipes(1)
    
    if getn(profitable) == 0 then
        aux.print('No profitable recipes found with current market data.')
        aux.print('Try scanning more items to build price history.')
        return
    end
    
    for i = 1, math.min(10, getn(profitable)) do
        local r = profitable[i]
        local profit_str = money.to_string(r.profit, nil, true)
        local cost_str = money.to_string(r.total_cost, nil, true)
        local vendor_str = money.to_string(r.vendor_value, nil, true)
        local data_flag = r.all_market_data and aux.color.green('✓') or aux.color.red('~')
        local safe_flag = ''
        -- Check if all materials are single-material (safe)
        local is_single_mat = getn(r.materials) == 1 or false
        for _, _ in pairs(r.materials) do
            -- Count materials
        end
        if is_single_mat then
            safe_flag = aux.color.blue('[S]') .. ' '
        end
        
        aux.print(format('%s%s %s: +%s profit (cost %s → vendor %s)',
            safe_flag,
            data_flag,
            r.recipe_name,
            profit_str,
            cost_str,
            vendor_str
        ))
    end
    
    aux.print(aux.color.green('✓') .. ' = market data | ' .. aux.color.red('~') .. ' = estimated | ' .. aux.color.blue('[S]') .. ' = single-material (safe)')
end

-- Print list of safe materials (only used in single-material recipes)
function M.print_safe_materials()
    aux.print(aux.color.gold('--- Safe Materials (No Leftover Risk) ---'))
    aux.print('These materials are only used in single-material recipes.')
    aux.print('Use filter: craft-safe/1c/sellable for auto-buy sniping')
    aux.print('')
    
    local safe_list = {}
    for item_id, _ in pairs(safe_materials) do
        local recipe_list = material_to_recipes[item_id]
        if recipe_list and getn(recipe_list) > 0 then
            local mat_name = recipe_list[1].recipe.materials[1].name
            local recipe_name = recipe_list[1].recipe_name
            tinsert(safe_list, { name = mat_name, recipe = recipe_name })
        end
    end
    
    table.sort(safe_list, function(a, b) return a.name < b.name end)
    
    for _, item in ipairs(safe_list) do
        aux.print(format('  %s → %s', item.name, item.recipe))
    end
end

-- Session tracking for material purchases
M.craft_session = {}

function M.reset_session()
    M.craft_session = {}
end

function M.add_to_session(item_id, item_name, quantity, cost)
    if not M.craft_session[item_id] then
        M.craft_session[item_id] = {
            name = item_name,
            quantity = 0,
            total_cost = 0,
        }
    end
    M.craft_session[item_id].quantity = M.craft_session[item_id].quantity + quantity
    M.craft_session[item_id].total_cost = M.craft_session[item_id].total_cost + cost
end

-- Check what can be crafted with current session materials
function M.get_craftable()
    local craftable = {}
    
    for recipe_name, recipe in pairs(recipes) do
        -- Check if we have all materials
        local can_craft = true
        local max_crafts = 999999
        
        for _, mat in ipairs(recipe.materials) do
            local have = M.craft_session[mat.item_id]
            if not have or have.quantity < mat.quantity then
                can_craft = false
                break
            end
            local possible = math.floor(have.quantity / mat.quantity)
            if possible < max_crafts then
                max_crafts = possible
            end
        end
        
        if can_craft and max_crafts > 0 then
            -- Calculate profit
            local mat_cost = 0
            for _, mat in ipairs(recipe.materials) do
                local have = M.craft_session[mat.item_id]
                local avg_cost = have.total_cost / have.quantity
                mat_cost = mat_cost + (avg_cost * mat.quantity)
            end
            
            local vendor_value = recipe.vendor_price * recipe.output_quantity
            local profit_per_craft = vendor_value - mat_cost
            
            tinsert(craftable, {
                name = recipe_name,
                quantity = max_crafts,
                profit_each = profit_per_craft,
                total_profit = profit_per_craft * max_crafts,
                vendor_value = vendor_value,
            })
        end
    end
    
    -- Sort by total profit
    table.sort(craftable, function(a, b) return a.total_profit > b.total_profit end)
    
    return craftable
end

-- Print session status
function M.print_session()
    aux.print(aux.color.gold('--- Craft Materials Session ---'))
    
    local has_mats = false
    for item_id, data in pairs(M.craft_session) do
        has_mats = true
        local avg = data.total_cost / data.quantity
        aux.print(format('%s: %d (avg: %s)', 
            data.name, 
            data.quantity, 
            money.to_string(avg, nil, true)
        ))
    end
    
    if not has_mats then
        aux.print('No materials collected yet.')
        return
    end
    
    aux.print('')
    aux.print(aux.color.gold('--- Can Craft ---'))
    
    local craftable = M.get_craftable()
    if getn(craftable) == 0 then
        aux.print('Nothing craftable with current materials.')
    else
        for _, item in ipairs(craftable) do
            local profit_str = money.to_string(item.profit_each, nil, true)
            local total_str = money.to_string(item.total_profit, nil, true)
            aux.print(format('%dx %s → +%s each (total: +%s)',
                item.quantity,
                item.name,
                profit_str,
                total_str
            ))
        end
    end
end

-- Check what recipes we're close to completing (have some materials)
function M.get_partial_recipes()
    local partial = {}
    
    for recipe_name, recipe in pairs(recipes) do
        local have_any = false
        local missing = {}
        local have = {}
        
        for _, mat in ipairs(recipe.materials) do
            local session_mat = M.craft_session[mat.item_id]
            if session_mat and session_mat.quantity > 0 then
                have_any = true
                have[mat.name] = session_mat.quantity
            else
                missing[mat.name] = {
                    item_id = mat.item_id,
                    quantity = mat.quantity,
                }
            end
        end
        
        if have_any and next(missing) then
            tinsert(partial, {
                name = recipe_name,
                recipe = recipe,
                have = have,
                missing = missing,
            })
        end
    end
    
    return partial
end

-- Calculate how many more of a material we need to balance with what we have
-- Returns: quantity still needed, or 0 if we have enough
-- This prevents buying excess materials that won't match other materials
function M.get_needed_quantity(item_id, target_crafts)
    target_crafts = target_crafts or 1  -- Default: aim for 1 craft
    
    local recipe_list = material_to_recipes[item_id]
    if not recipe_list then return 0 end
    
    local max_needed = 0
    
    for _, entry in ipairs(recipe_list) do
        local recipe = entry.recipe
        local mat_qty_per_craft = entry.mat_quantity
        
        -- How many crafts can we do with current materials?
        local min_crafts = 999999
        local have_this = 0
        
        for _, mat in ipairs(recipe.materials) do
            local session_mat = M.craft_session[mat.item_id]
            local have = session_mat and session_mat.quantity or 0
            
            if mat.item_id == item_id then
                have_this = have
            end
            
            local crafts_possible = math.floor(have / mat.quantity)
            if crafts_possible < min_crafts then
                min_crafts = crafts_possible
            end
        end
        
        -- How many of THIS item do we need to reach target_crafts?
        local target = math.max(target_crafts, min_crafts + 1)  -- At least one more craft
        local total_needed = target * mat_qty_per_craft
        local still_need = total_needed - have_this
        
        if still_need > max_needed then
            max_needed = still_need
        end
    end
    
    return math.max(0, max_needed)
end

-- Check if buying more of this material makes sense (ratio-aware)
-- Returns true if we need more to balance our materials
function M.should_buy_material(item_id)
    return M.get_needed_quantity(item_id, 1) > 0
end

-- Print what materials are still needed
function M.print_missing()
    aux.print(aux.color.gold('--- Missing Materials ---'))
    
    local partial = M.get_partial_recipes()
    
    if getn(partial) == 0 then
        aux.print('No partial recipes. Buy some materials first!')
        return
    end
    
    for _, p in ipairs(partial) do
        local missing_str = ''
        for name, data in pairs(p.missing) do
            if missing_str ~= '' then missing_str = missing_str .. ', ' end
            missing_str = missing_str .. data.quantity .. 'x ' .. name
        end
        aux.print(format('%s: Need %s', p.name, missing_str))
    end
end

-- Called when a craft material is auto-bought - checks if we can now craft something
function M.on_material_bought(item_id, item_name, quantity, cost)
    -- Add to session
    M.add_to_session(item_id, item_name, quantity, cost)
    
    -- Check if this completes any recipes
    local craftable = M.get_craftable()
    
    if getn(craftable) > 0 then
        -- Play a sound and notify
        PlaySound("QUESTCOMPLETE")
        aux.print(aux.color.green('=== CRAFT READY ==='))
        for _, item in ipairs(craftable) do
            local profit_str = money.to_string(item.profit_each, nil, true)
            local total_str = money.to_string(item.total_profit, nil, true)
            aux.print(format('  %dx %s → +%s profit!',
                item.quantity,
                item.name,
                total_str
            ))
        end
    end
end

-- Print all profitable recipes
function M.print_recipes()
    aux.print(aux.color.gold('--- Craft-to-Vendor Recipes ---'))
    
    local sorted = {}
    for name, recipe in pairs(recipes) do
        local vendor_total = recipe.vendor_price * recipe.output_quantity
        tinsert(sorted, {
            name = name,
            vendor = vendor_total,
            mats = recipe.materials,
        })
    end
    
    table.sort(sorted, function(a, b) return a.vendor > b.vendor end)
    
    for i = 1, math.min(15, getn(sorted)) do
        local r = sorted[i]
        local mat_str = ''
        for _, mat in ipairs(r.mats) do
            if mat_str ~= '' then mat_str = mat_str .. ' + ' end
            mat_str = mat_str .. mat.quantity .. 'x ' .. mat.name
        end
        aux.print(format('%s → %s | Needs: %s',
            r.name,
            money.to_string(r.vendor, nil, true),
            mat_str
        ))
    end
end

-- Initialize on addon load
function aux.handle.LOAD()
    build_material_index()
end
