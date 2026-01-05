module 'aux.tabs.craft'

local T = require 'T'
local aux = require 'aux'
local info = require 'aux.util.info'
local money = require 'aux.util.money'
local filter_util = require 'aux.util.filter'
local scan = require 'aux.core.scan'
local craft_vendor = require 'aux.core.craft_vendor'
local search_tab = require 'aux.tabs.search'

-- Lazy load modules
local profession_scanner
local search_cache

local tab = aux.tab 'Craft'

-- Forward declarations
local update_recipe_stats_cache

-- Prefer crafted item name over spell name when building search filters
local function crafted_search_name(recipe, recipe_name)
    if recipe and recipe.output_id then
        local item_info = info.item(recipe.output_id)
        if item_info and item_info.name then
            return strlower(item_info.name)
        end
    end
    return strlower(recipe_name or '')
end

local function get_cached_output_price(recipe, recipe_name)
    if not (recipe and recipe.output_id) then return nil end
    if not search_cache then
        local success, module = pcall(require, 'aux.core.search_cache')
        if success then
            search_cache = module
        end
    end
    if not (search_cache and search_cache.get) then return nil end

    local filter_parts = {}
    local crafted_name = crafted_search_name(recipe, recipe_name)
    if crafted_name and crafted_name ~= '' then
        tinsert(filter_parts, crafted_name .. '/exact')
    end
    if recipe and recipe.materials then
        for _, mat in ipairs(recipe.materials) do
            tinsert(filter_parts, strlower(mat.name) .. '/exact')
        end
    end
    local complete_filter = table.concat(filter_parts, ';')
    local cached_data = search_cache.get(complete_filter)
    if not (cached_data and cached_data.auctions) then return nil end

    local min_price
    for _, cached_auction in ipairs(cached_data.auctions) do
        if cached_auction.item_id == recipe.output_id and cached_auction.unit_buyout_price and cached_auction.unit_buyout_price > 0 then
            if not min_price or cached_auction.unit_buyout_price < min_price then
                min_price = cached_auction.unit_buyout_price
            end
        end
    end
    return min_price
end

-- Current scan state
scan_id = 0
scanning = false
selected_recipe = nil
selected_recipe_name = nil
material_prices = {}  -- item_id -> {min_price, count}
crafted_item_price = nil  -- lowest auction price for the crafted item
scan_results = {}  -- auction records for display
search_continuation = nil
real_time = false
filter_string = nil  -- current search filter for caching
recipe_stats = nil  -- per-recipe cached summary (ah price, mats cost, profit)
recipe_stats_by_id = nil -- keyed by output_id

-- Flag to track if tab is open
local tab_is_open = false

-- Initialize recipe stats storage (realm-scoped)
local realm_data = aux.realm_data
if not realm_data then
    realm_data = {}
    aux.realm_data = realm_data
end
if not realm_data.craft_recipe_stats then
    realm_data.craft_recipe_stats = {}
end
if not realm_data.craft_recipe_stats_by_id then
    realm_data.craft_recipe_stats_by_id = {}
end
recipe_stats = realm_data.craft_recipe_stats
recipe_stats_by_id = realm_data.craft_recipe_stats_by_id

function tab.OPEN()
    frame:Show()
    tab_is_open = true
    update_recipe_listing()
    update_search_display()
    update_cache_status()
    update_no_recipe_message()  -- Show/hide message based on cache status
    
    -- Initialize page inputs
    if first_page_input:GetText() == '' then
        first_page_input:SetText('1')
    end
end

function tab.CLOSE()
    frame:Hide()
    tab_is_open = false
    scan.abort(scan_id)
end

-- Event handler to refresh UI after profession scan
function profession_cache_updated()
    -- Safely refresh UI when new profession data is available
    update_cache_status()
    if tab_is_open then
        update_recipe_listing()
        update_no_recipe_message()
    end
end

-- Event handler to refresh UI after profession scan
local function on_profession_close()
    profession_cache_updated()
end

-- Refresh as soon as a profession window opens (so data shows without closing)
local function on_profession_show()
    profession_cache_updated()
end

-- Register event listeners
aux.event_listener('TRADE_SKILL_CLOSE', on_profession_close)
aux.event_listener('CRAFT_CLOSE', on_profession_close)
aux.event_listener('TRADE_SKILL_SHOW', on_profession_show)
aux.event_listener('CRAFT_SHOW', on_profession_show)

-- Execute search from search box
function execute_search(resume)
    local filter_string = search_box:GetText()
    if filter_string == '' and not resume then return end
    -- Capture the filter for this specific scan so tab switches won't overwrite it mid-scan
    local scan_filter = filter_string
    
    local queries, error = filter_util.queries(filter_string)
    if not queries and not resume then
        status_bar:set_text('Filter error: ' .. (error or 'unknown'))
        return
    end
    
    scan.abort(scan_id)
    
    local continuation = resume and search_continuation or nil
    search_continuation = nil
    
    -- Don't clear results - let cached data stay visible while we scan
    -- (This matches Search tab behavior)
    
    scanning = true
    update_search_display()
    status_bar:update_status(0, 0)
    status_bar:set_text('Scanning...')
    
    local first_page = tonumber(first_page_input:GetText())
    local last_page = tonumber(last_page_input:GetText())
    
    local current_query = 0
    local total_queries = getn(queries)
    scan_id = scan.start{
        type = 'list',
        queries = queries,
        continuation = continuation,
        start_page = not continuation and first_page or nil,
        end_page = last_page,
        on_scan_start = function()
            status_bar:update_status(0, 0)
            if continuation then
                status_bar:set_text('Resuming scan...')
            else
                status_bar:set_text('Scanning materials...')
            end
        end,
        on_start_query = function(index)
            current_query = index or 1
        end,
        on_page_loaded = function(page_progress, total_scan_pages, last_page, actual_page)
            local q = current_query > 0 and current_query or 1
            local tq = total_queries > 0 and total_queries or 1
            total_scan_pages = max(total_scan_pages or 1, 1)
            page_progress = min(page_progress or 0, total_scan_pages)
            
            status_bar:update_status((q - 1) / tq, page_progress / total_scan_pages)
            
            -- Use actual_page for display (shows real AH page number)
            local display_page = actual_page or page_progress
            local display_total = (last_page or 0) + 1
            
                -- Always show scan progress (materials + crafted item = always multiple queries)
            status_bar:set_text(format('Scanning %d / %d (Page %d / %d)', q, tq, display_page, display_total))
        end,
        on_auction = function(auction_record)
            if auction_record.buyout_price > 0 then
                tinsert(scan_results, auction_record)
                
                -- Update display progressively (like Search tab)
                results_listing:SetDatabase(scan_results)
                
                -- Track material prices
                local item_id = auction_record.item_id
                local unit_price = auction_record.unit_buyout_price
                
                -- Track crafted item auction price separately
                if selected_recipe and item_id == selected_recipe.output_id then
                    if not crafted_item_price or unit_price < crafted_item_price then
                        crafted_item_price = unit_price
                    end
                end
                
                if not material_prices[item_id] then
                    material_prices[item_id] = { min_price = unit_price, count = auction_record.aux_quantity }
                else
                    if unit_price < material_prices[item_id].min_price then
                        material_prices[item_id].min_price = unit_price
                    end
                    material_prices[item_id].count = material_prices[item_id].count + auction_record.aux_quantity
                end
                
                -- Update profit calculations as prices come in
                update_material_listing()
            end
        end,
        on_complete = function()
            scanning = false
            search_continuation = nil
            status_bar:update_status(1, 1)
            status_bar:set_text('Scan complete - ' .. getn(scan_results) .. ' auctions found')
            
            -- Store results in search cache for instant display on future recipe selection
            if scan_filter and getn(scan_results) > 0 then
                if search_cache and search_cache.store then
                    search_cache.store(scan_filter, scan_results)
                end
            end
            
            -- Save material prices to realm data for instant feedback on future searches
            if selected_recipe and selected_recipe_name then
                if not aux.realm_data.craft_material_prices then
                    aux.realm_data.craft_material_prices = {}
                end
                
                local profession = selected_recipe.profession or 'Unknown'
                if not aux.realm_data.craft_material_prices[profession] then
                    aux.realm_data.craft_material_prices[profession] = {}
                end
                
                -- Save all material prices we found
                for item_id, price_info in pairs(material_prices) do
                    aux.realm_data.craft_material_prices[profession][item_id] = {
                        price = price_info.min_price,
                        count = price_info.count,
                        scanned_at = time(),
                    }
                end
            end
            
            update_search_display()
            update_material_listing()
            results_listing:SetDatabase(scan_results)
        end,
        on_abort = function(continuation)
            scanning = false
            search_continuation = continuation
            status_bar:update_status(1, 1)
            if continuation then
                status_bar:set_text('Scan paused - click Resume')
            else
                status_bar:set_text('Scan aborted')
            end
            update_search_display()
            update_material_listing()
            results_listing:SetDatabase(scan_results)
        end,
    }
end

-- Build recipe list for display
function get_recipe_list()
    local recipes = {}
    
    -- Get recipes directly from M.get_recipes() instead of through metatable
    -- (Lua 5.0 doesn't support __pairs metamethod, so metatable iteration doesn't work)
    local all_recipes = craft_vendor.get_recipes()
    
    local recipe_count = aux.size(all_recipes)
    
    for name, recipe in pairs(all_recipes) do
        local vendor_price = recipe.vendor_price or 1  -- Default to 1 copper if nil
        local vendor_total = vendor_price * recipe.output_quantity
        local mat_count = getn(recipe.materials or {})
        local is_safe = mat_count == 1 or (mat_count > 0 and craft_vendor.is_safe_material(recipe.materials[1].item_id))
        
        tinsert(recipes, {
            name = name,
            recipe = recipe,
            vendor_value = vendor_total,
            mat_count = mat_count,
            is_safe = is_safe,
        })
    end
    
    -- Sort alphabetically for stable display
    table.sort(recipes, function(a, b) return a.name < b.name end)
    return recipes
end

function update_recipe_listing()
    local rows = T.acquire()
    local recipes = get_recipe_list()
    local cached_material_prices = aux.realm_data.craft_material_prices or {}
    
    for i, r in ipairs(recipes) do
        local name_display = r.is_safe and aux.color.green(r.name) or r.name
        local icon_texture
        if r.recipe.output_id then
            local item_info = info.item(r.recipe.output_id)
            icon_texture = item_info and item_info.texture
        end
        if not icon_texture then
            icon_texture = 'Interface\\Icons\\INV_Misc_QuestionMark'
        end
        local stats = (r.recipe.output_id and recipe_stats_by_id[r.recipe.output_id]) or recipe_stats[r.name] or {}

        -- If we lack stored mat cost, try to derive it from cached material prices for this profession
        if not stats.mat_cost and r.recipe and r.recipe.materials then
            local profession = r.recipe.profession or 'Unknown'
            local cached_prices = cached_material_prices[profession]
            if cached_prices then
                local total_cost = 0
                local complete = true
                for _, mat in ipairs(r.recipe.materials) do
                    local cached = cached_prices[mat.item_id]
                    if cached and cached.price then
                        total_cost = total_cost + (cached.price * mat.quantity)
                    else
                        complete = false
                        break
                    end
                end
                if complete then
                    stats.mat_cost = total_cost
                    update_recipe_stats_cache(r.recipe, total_cost, stats.ah_unit_price, stats.profit)
                end
            end
        end

        -- If we lack AH unit price, try to derive it from cached search results for this recipe
        if not stats.ah_unit_price and r.recipe then
            local cached_price = get_cached_output_price(r.recipe, r.name)
            if cached_price then
                stats.ah_unit_price = cached_price
                update_recipe_stats_cache(r.recipe, stats.mat_cost, cached_price, stats.profit)
            end
        end

        -- If we have both AH unit price and derived mat cost but missing profit, compute it
        if stats.ah_unit_price and stats.mat_cost and not stats.profit then
            local unit_price = stats.ah_unit_price
            local out_qty = r.recipe.output_quantity or 1
            stats.profit = unit_price * out_qty - stats.mat_cost
            update_recipe_stats_cache(r.recipe, stats.mat_cost, unit_price, stats.profit)
        end
        local ah_price = stats.ah_unit_price
        local mat_cost = stats.mat_cost
        local profit = stats.profit
        local ah_str = ah_price and money.to_string(ah_price, nil, true) or 'unknown'
        local mat_str = mat_cost and money.to_string(mat_cost, nil, true) or 'unknown'
        local profit_str
        if profit then
            local color = profit > 0 and aux.color.green or aux.color.red
            profit_str = color(money.to_string(profit, nil, true))
        elseif mat_cost or ah_price then
            profit_str = aux.color.gray('pending')
        else
            profit_str = 'unknown'
        end
        
        tinsert(rows, T.map(
            'cols', T.list(
                T.map('value', name_display, 'texture', icon_texture),
                T.map('value', mat_str),
                T.map('value', ah_str),
                T.map('value', profit_str)
            ),
            'recipe_name', r.name,
            'recipe', r.recipe,
            'item_id', r.recipe.item_id,
            'index', i
        ))
    end
    
    recipe_listing:SetData(rows)
end

-- Calculate profit for a recipe based on scanned material prices
function calculate_recipe_profit(recipe)
    local vendor_total = recipe.vendor_price * recipe.output_quantity
    local total_cost = 0
    local all_found = true
    local mat_details = {}
    
    -- Load cached prices from realm data if available
    local profession = recipe.profession or 'Unknown'
    local cached_prices = aux.realm_data.craft_material_prices and aux.realm_data.craft_material_prices[profession] or {}
    
    for _, mat in ipairs(recipe.materials) do
        -- Check session prices first (from current search), then fallback to cached prices
        local price_info = material_prices[mat.item_id] or (cached_prices[mat.item_id] and {min_price = cached_prices[mat.item_id].price, count = cached_prices[mat.item_id].count})
        
        if price_info and price_info.min_price then
            local line_cost = price_info.min_price * mat.quantity
            total_cost = total_cost + line_cost
            tinsert(mat_details, {
                name = mat.name,
                quantity = mat.quantity,
                unit_price = price_info.min_price,
                line_cost = line_cost,
                available = price_info.count,
            })
        else
            all_found = false
            tinsert(mat_details, {
                name = mat.name,
                quantity = mat.quantity,
                unit_price = nil,
                line_cost = nil,
                available = 0,
            })
        end
    end
    
    local profit = all_found and (vendor_total - total_cost) or nil
    
    return {
        vendor_value = vendor_total,
        total_cost = total_cost,
        profit = profit,
        all_found = all_found,
        materials = mat_details,
    }
end

-- Persist lightweight per-recipe stats for list display
update_recipe_stats_cache = function(recipe, mat_cost, ah_unit_price, profit)
    if not recipe then return end
    local key = recipe.name
    local id = recipe.output_id
    if key then
        local stats = recipe_stats[key] or {}
        if mat_cost then stats.mat_cost = mat_cost end
        if ah_unit_price then stats.ah_unit_price = ah_unit_price end
        if profit then stats.profit = profit end
        stats.output_quantity = recipe.output_quantity or stats.output_quantity or 1
        stats.timestamp = time()
        recipe_stats[key] = stats
    end
    if id then
        local stats = recipe_stats_by_id[id] or {}
        if mat_cost then stats.mat_cost = mat_cost end
        if ah_unit_price then stats.ah_unit_price = ah_unit_price end
        if profit then stats.profit = profit end
        stats.output_quantity = recipe.output_quantity or stats.output_quantity or 1
        stats.timestamp = time()
        recipe_stats_by_id[id] = stats
    end
end

-- Update material listing after scan
function update_material_listing()
    if not selected_recipe then return end
    
    local eval = calculate_recipe_profit(selected_recipe)
    
    -- Update profit display with vendor and auction profit
    if eval.all_found then
        local profit_color = eval.profit > 0 and aux.color.green or aux.color.red
        cost_label:SetText('Mats Cost: ' .. money.to_string(eval.total_cost, nil, true))
        profit_label:SetText('Vendor Profit: ' .. profit_color(money.to_string(eval.profit, nil, true)))
        
        -- Show auction profit if we have auction data
        if crafted_item_price then
            local auction_total = crafted_item_price * selected_recipe.output_quantity
            local auction_profit = auction_total - eval.total_cost
            local auction_color = auction_profit > 0 and aux.color.green or aux.color.red
            auction_profit_label:SetText('AH Profit: ' .. auction_color(money.to_string(auction_profit, nil, true)))
        else
            auction_profit_label:SetText('AH Profit: ' .. aux.color.gray('No data'))
        end
    else
        cost_label:SetText('Mats Cost: -')
        profit_label:SetText('Vendor Profit: ' .. aux.color.red('Missing materials'))
        auction_profit_label:SetText('AH Profit: -')
    end

    -- Persist summary for recipe list (only when we have meaningful data)
    local mat_cost_for_stats = eval.all_found and eval.total_cost or nil
    local ah_price_for_stats = crafted_item_price
    local profit_for_stats = (mat_cost_for_stats and ah_price_for_stats) and (ah_price_for_stats * (selected_recipe.output_quantity or 1) - mat_cost_for_stats) or nil
    update_recipe_stats_cache(selected_recipe, mat_cost_for_stats, ah_price_for_stats, profit_for_stats)
    update_recipe_listing()
end

-- Scan for materials of selected recipe
function scan_recipe_materials(recipe_name, recipe_obj)
    -- Use passed recipe object if available, otherwise look it up
    local recipe = recipe_obj or craft_vendor.recipes[recipe_name]
    if not recipe then 
        aux.print('ERROR: Recipe not found: ' .. recipe_name)
        return 
    end
    
    selected_recipe = recipe
    selected_recipe_name = recipe_name
    
    -- Clear old results immediately for instant visual feedback
    scan.abort(scan_id)
    material_prices = {}
    crafted_item_price = nil
    scan_results = {}
    results_listing:SetDatabase({})
    results_listing:Reset()
    status_bar:set_text('Loading cached prices...')
    update_search_display()
    
    -- Load cached prices for this profession immediately
    local profession = recipe.profession or 'Unknown'
    local cached_count = 0
    if aux.realm_data.craft_material_prices and aux.realm_data.craft_material_prices[profession] then
        local cached = aux.realm_data.craft_material_prices[profession]
        for item_id, price_data in pairs(cached) do
            material_prices[item_id] = { min_price = price_data.price, count = price_data.count }
            cached_count = cached_count + 1
        end
        -- cached prices loaded
    end
    
    local crafted_name = crafted_search_name(recipe, recipe_name)

    -- Load cached auction records from search_cache for instant display
    if not search_cache then
        local success, module = pcall(require, 'aux.core.search_cache')
        if success then
            search_cache = module
        end
    end
    
    if search_cache and search_cache.get then
        -- Build the same filter string that will be used for the search
        local filter_parts = {}
        tinsert(filter_parts, crafted_name .. '/exact')
        if recipe.materials then
            for _, mat in ipairs(recipe.materials) do
                tinsert(filter_parts, strlower(mat.name) .. '/exact')
            end
        end
        local complete_filter = table.concat(filter_parts, ';')
        
        -- Try to load cached results for this complete search
        local cached_data = search_cache.get(complete_filter)
        if cached_data and cached_data.auctions and getn(cached_data.auctions) > 0 then
            scan_results = {}
            for _, cached_auction in ipairs(cached_data.auctions) do
                tinsert(scan_results, cached_auction)
            end
            -- Derive crafted item price from cached results
            crafted_item_price = nil
            for _, cached_auction in ipairs(scan_results) do
                if cached_auction.item_id == recipe.output_id and cached_auction.unit_buyout_price and cached_auction.unit_buyout_price > 0 then
                    if not crafted_item_price or cached_auction.unit_buyout_price < crafted_item_price then
                        crafted_item_price = cached_auction.unit_buyout_price
                    end
                end
            end
            results_listing:SetDatabase(scan_results)
        else
            scan_results = {}
        end
    else
        scan_results = {}
    end
    
    -- Update profit display with cached prices before search
    update_material_listing()
    
    -- Build search filter: materials + crafted item
    local filter_parts = {}
    
    -- Add the crafted item first (so icon loads)
    tinsert(filter_parts, crafted_name .. '/exact')
    
    -- Add all materials
    if recipe.materials then
        for _, mat in ipairs(recipe.materials) do
            tinsert(filter_parts, strlower(mat.name) .. '/exact')
        end
    else
        aux.print('ERROR: Recipe has no materials: ' .. recipe_name)
    end
    
    filter_string = table.concat(filter_parts, ';')
    
    -- Update search box
    search_box:SetText(filter_string)
    
    -- Set page range to scan all pages
    first_page_input:SetText('1')
    last_page_input:SetText('')
    
    -- Execute search - cached results already loaded and visible
    execute_search()
end

-- Quick buy materials at profitable prices
function buy_profitable_materials()
    if not selected_recipe then return end
    
    -- Build filter for profitable materials
    local filter_string = 'for-craft/' .. strlower(selected_recipe_name) .. '/craft-profit/1c'
    
    aux.set_tab(1)  -- Switch to Search tab
    search_tab.set_filter(filter_string)
    search_tab.execute(nil, false)
end

-- Update cache status display
function update_cache_status()
    -- Lazy load profession_scanner
    if not profession_scanner then
        local success, module = pcall(require, 'aux.core.profession_scanner')
        if success then
            profession_scanner = module
        end
    end
    
    local has_cache = false
    if profession_scanner and profession_scanner.has_cached_recipes then
        local success, result = pcall(profession_scanner.has_cached_recipes)
        if success then
            has_cache = result
        end
    end
    
    local recipes = craft_vendor.get_recipes()
    local recipe_count = recipes and aux.size(recipes) or 0
    
    if cache_status_label then
        if has_cache then
            cache_status_label:SetText(aux.color.green(format('Recipes: %d (cached)', recipe_count)))
        elseif recipe_count > 0 then
            cache_status_label:SetText(aux.color.yellow(format('Recipes: %d (hardcoded)', recipe_count)))
        else
            cache_status_label:SetText(aux.color.red('No recipes - open profession window'))
        end
    end
    
    -- Update the compact message too
    update_no_recipe_message()
end

-- Show/hide the prominent message based on recipe cache status
function update_no_recipe_message()
    if not no_recipe_message then return end
    
    -- Lazy load profession_scanner
    if not profession_scanner then
        profession_scanner = require 'aux.core.profession_scanner'
    end
    
    local has_cache = profession_scanner and profession_scanner.has_cached_recipes and profession_scanner.has_cached_recipes()
    local recipes = craft_vendor.get_recipes()
    local recipe_count = recipes and aux.size(recipes) or 0
    
    -- Show message only if we have zero recipes (not even hardcoded)
    if recipe_count == 0 and not has_cache then
        no_recipe_message:Show()
        frame.recipes:ClearAllPoints()
        frame.recipes:SetPoint('TOPLEFT', no_recipe_message, 'BOTTOMLEFT', 0, -5)
        frame.recipes:SetPoint('BOTTOMLEFT', aux.frame.content, 'BOTTOMLEFT', 0, 40)
    else
        no_recipe_message:Hide()
        frame.recipes:ClearAllPoints()
        frame.recipes:SetPoint('TOPLEFT', aux.frame.content, 'TOPLEFT', 0, 0)
        frame.recipes:SetPoint('BOTTOMLEFT', aux.frame.content, 'BOTTOMLEFT', 0, 40)
    end
end
