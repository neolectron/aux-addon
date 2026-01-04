module 'aux.core.craft_vendor'

local T = require 'T'
local aux = require 'aux'
local info = require 'aux.util.info'
local money = require 'aux.util.money'

-- Craft-to-Vendor Recipe Database
-- Prices verified from database.turtlecraft.gg
-- Each recipe: materials needed, output item, vendor price (per unit), output quantity
-- base_value = opportunity cost of material (vendor sell price, or craft cost for intermediates)
M.recipes = {
    -- ============ SMELTING (Mining) ============
    -- Ore vendor prices: Copper 5c, Tin 25c, Iron 1s50c, Mithril 2s50c, Thorium 2s50c
    -- Bar vendor prices: Copper 10c, Bronze 50c, Iron 2s, Steel 60c, Mithril 4s, Thorium 6s
    
    ["Copper Bar"] = {
        output_id = 2840,
        vendor_price = 10,  -- 10c (from DB)
        output_quantity = 1,
        materials = {
            { item_id = 2770, name = "Copper Ore", quantity = 1, base_value = 5 },  -- vendor sell 5c
        }
    },
    ["Tin Bar"] = {
        output_id = 3576,
        vendor_price = 25,  -- 25c estimate (same as ore)
        output_quantity = 1,
        materials = {
            { item_id = 2771, name = "Tin Ore", quantity = 1, base_value = 25 },  -- vendor sell 25c
        }
    },
    ["Bronze Bar"] = {
        output_id = 2841,
        vendor_price = 50,  -- 50c each (from DB)
        output_quantity = 2,  -- Makes 2 bars = 1s total
        materials = {
            { item_id = 2840, name = "Copper Bar", quantity = 1, base_value = 10 },  -- vendor sell 10c
            { item_id = 3576, name = "Tin Bar", quantity = 1, base_value = 25 },     -- vendor sell 25c
        }
    },
    ["Silver Bar"] = {
        output_id = 2842,
        vendor_price = 150,  -- 1s50c estimate
        output_quantity = 1,
        materials = {
            { item_id = 2775, name = "Silver Ore", quantity = 1, base_value = 75 },  -- estimate
        }
    },
    ["Iron Bar"] = {
        output_id = 3575,
        vendor_price = 200,  -- 2s (from DB)
        output_quantity = 1,
        materials = {
            { item_id = 2772, name = "Iron Ore", quantity = 1, base_value = 150 },  -- vendor sell 1s50c
        }
    },
    ["Gold Bar"] = {
        output_id = 3577,
        vendor_price = 600,  -- 6s estimate
        output_quantity = 1,
        materials = {
            { item_id = 2776, name = "Gold Ore", quantity = 1, base_value = 300 },  -- estimate
        }
    },
    ["Steel Bar"] = {
        output_id = 3859,
        vendor_price = 60,  -- 60c (from DB) - Note: worse than Iron Bar!
        output_quantity = 1,
        materials = {
            { item_id = 3575, name = "Iron Bar", quantity = 1, base_value = 200 },   -- vendor sell 2s
            { item_id = 3857, name = "Coal", quantity = 1, base_value = 5 },  -- vendor buy ~5c
        }
    },
    ["Mithril Bar"] = {
        output_id = 3860,
        vendor_price = 400,  -- 4s (from DB)
        output_quantity = 1,
        materials = {
            { item_id = 3858, name = "Mithril Ore", quantity = 1, base_value = 250 },  -- vendor sell 2s50c
        }
    },
    ["Truesilver Bar"] = {
        output_id = 6037,
        vendor_price = 500,  -- 5s estimate
        output_quantity = 1,
        materials = {
            { item_id = 7911, name = "Truesilver Ore", quantity = 1, base_value = 250 },  -- estimate
        }
    },
    ["Thorium Bar"] = {
        output_id = 12359,
        vendor_price = 600,  -- 6s (from DB)
        output_quantity = 1,
        materials = {
            { item_id = 10620, name = "Thorium Ore", quantity = 1, base_value = 250 },  -- vendor sell 2s50c
        }
    },
    
    -- ============ ENGINEERING - Blasting Powders ============
    -- Stone vendor prices: Rough 2c, Coarse 15c, Heavy 60c, Solid 1s, Dense 2s50c
    
    ["Rough Blasting Powder"] = {
        output_id = 4357,
        vendor_price = 4,  -- 4c each (from DB), makes 2 = 8c total
        output_quantity = 2,
        materials = {
            { item_id = 2835, name = "Rough Stone", quantity = 1, base_value = 2 },  -- vendor sell 2c
        }
    },
    ["Coarse Blasting Powder"] = {
        output_id = 4364,
        vendor_price = 12,  -- 12c each (from DB), makes 2 = 24c total
        output_quantity = 2,
        materials = {
            { item_id = 2836, name = "Coarse Stone", quantity = 1, base_value = 15 },  -- vendor sell 15c
        }
    },
    ["Heavy Blasting Powder"] = {
        output_id = 4377,
        vendor_price = 150,  -- 1s50c each (from DB), makes 2 = 3s total
        output_quantity = 2,
        materials = {
            { item_id = 2838, name = "Heavy Stone", quantity = 1, base_value = 60 },  -- vendor sell 60c
        }
    },
    ["Solid Blasting Powder"] = {
        output_id = 10505,
        vendor_price = 250,  -- 2s50c each (from DB), makes 2 = 5s total
        output_quantity = 2,
        materials = {
            { item_id = 7912, name = "Solid Stone", quantity = 1, base_value = 100 },  -- vendor sell 1s
        }
    },
    ["Dense Blasting Powder"] = {
        output_id = 15992,
        vendor_price = 250,  -- 2s50c each (from DB), makes 2 = 5s total
        output_quantity = 2,
        materials = {
            { item_id = 12365, name = "Dense Stone", quantity = 1, base_value = 250 },  -- vendor sell 2s50c
        }
    },
    
    -- ============ ENGINEERING - Components ============
    ["Handful of Copper Bolts"] = {
        output_id = 4359,
        vendor_price = 12,  -- 12c each (from DB), makes 2 = 24c total
        output_quantity = 2,
        materials = {
            { item_id = 2840, name = "Copper Bar", quantity = 1, base_value = 10 },  -- vendor sell 10c
        }
    },
    ["Copper Tube"] = {
        output_id = 4361,
        vendor_price = 120,  -- 1s20c (from DB)
        output_quantity = 1,
        materials = {
            { item_id = 2840, name = "Copper Bar", quantity = 2, base_value = 10 },  -- vendor sell 10c each
            { item_id = 4357, name = "Rough Blasting Powder", quantity = 1, base_value = 1 },  -- craft cost: 1c (half a 2c stone)
        }
    },
    ["Bronze Tube"] = {
        output_id = 4371,
        vendor_price = 200,  -- 2s (from DB)
        output_quantity = 1,
        materials = {
            { item_id = 2841, name = "Bronze Bar", quantity = 2, base_value = 50 },  -- vendor sell 50c each
            { item_id = 4357, name = "Rough Blasting Powder", quantity = 1, base_value = 1 },  -- craft cost 1c
        }
    },
    ["Whirring Bronze Gizmo"] = {
        output_id = 4375,
        vendor_price = 115,  -- 1s15c (from DB)
        output_quantity = 1,
        materials = {
            { item_id = 2841, name = "Bronze Bar", quantity = 2, base_value = 50 },  -- vendor sell 50c each
            { item_id = 2592, name = "Wool Cloth", quantity = 1, base_value = 10 },  -- vendor sell ~10c
        }
    },
    ["Iron Strut"] = {
        output_id = 4387,
        vendor_price = 4,  -- 4c (from DB) - terrible ratio!
        output_quantity = 1,
        materials = {
            { item_id = 3575, name = "Iron Bar", quantity = 2, base_value = 200 },  -- vendor sell 2s each
        }
    },
    ["Gyrochronatom"] = {
        output_id = 4389,
        vendor_price = 500,  -- 5s estimate
        output_quantity = 1,
        materials = {
            { item_id = 3575, name = "Iron Bar", quantity = 1, base_value = 200 },  -- vendor sell 2s
            { item_id = 10558, name = "Gold Power Core", quantity = 1, base_value = 100 },  -- estimate
        }
    },
    ["Mithril Tube"] = {
        output_id = 10559,
        vendor_price = 750,  -- 7s50c (from DB)
        output_quantity = 1,
        materials = {
            { item_id = 3860, name = "Mithril Bar", quantity = 3, base_value = 400 },  -- vendor sell 4s each
        }
    },
    ["Unstable Trigger"] = {
        output_id = 10560,
        vendor_price = 1000,  -- 10s (from DB)
        output_quantity = 1,
        materials = {
            { item_id = 3860, name = "Mithril Bar", quantity = 1, base_value = 400 },  -- vendor sell 4s
            { item_id = 4338, name = "Mageweave Cloth", quantity = 1, base_value = 50 },  -- vendor sell ~50c
            { item_id = 10505, name = "Solid Blasting Powder", quantity = 1, base_value = 50 },  -- craft cost: 50c (half a 1s stone)
        }
    },
    ["Thorium Widget"] = {
        output_id = 15994,
        vendor_price = 2500,  -- 25s (from DB)
        output_quantity = 1,
        materials = {
            { item_id = 12359, name = "Thorium Bar", quantity = 3, base_value = 600 },  -- vendor sell 6s each
            { item_id = 14047, name = "Runecloth", quantity = 1, base_value = 100 },  -- vendor sell ~1s
        }
    },
}

-- Build reverse lookup: material item_id -> list of recipes that use it
M.material_to_recipes = {}

function M.build_material_index()
    M.material_to_recipes = {}
    for recipe_name, recipe in pairs(recipes) do
        for _, mat in ipairs(recipe.materials) do
            if not M.material_to_recipes[mat.item_id] then
                M.material_to_recipes[mat.item_id] = {}
            end
            tinsert(M.material_to_recipes[mat.item_id], {
                recipe_name = recipe_name,
                recipe = recipe,
                mat_quantity = mat.quantity,
            })
        end
    end
end

-- Calculate the max price you should pay for a material to profit from crafting
-- Returns: max_price per unit, recipe_name, profit_per_craft
-- profit_margin: 0 = any profit (1c+), 0.5 = 50% margin, etc.
function M.get_max_mat_price(item_id, profit_margin)
    profit_margin = profit_margin or 0  -- Default: any profit (1c minimum)
    
    local recipe_list = M.material_to_recipes[item_id]
    if not recipe_list then return nil end
    
    local best_price = 0
    local best_recipe = nil
    local best_profit = 0
    
    for _, entry in ipairs(recipe_list) do
        local recipe = entry.recipe
        local mat_qty = entry.mat_quantity
        
        -- Calculate total vendor value of output
        local total_vendor = recipe.vendor_price * recipe.output_quantity
        
        -- Calculate cost of OTHER materials using their base_value (opportunity cost)
        -- This is what you'd get if you vendored them, or their craft cost
        local other_mats_cost = 0
        for _, mat in ipairs(recipe.materials) do
            if mat.item_id ~= item_id then
                -- Use base_value from recipe database (vendor sell or craft cost)
                local mat_cost = mat.base_value or 0
                other_mats_cost = other_mats_cost + (mat_cost * mat.quantity)
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
        end
    end
    
    return best_price, best_recipe, best_profit
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

-- Initialize immediately so filter can use it
build_material_index()
