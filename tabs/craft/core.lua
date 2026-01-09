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

-- Ensure the shared search cache module is available
local function ensure_search_cache()
    if not search_cache then
        local success, module = pcall(require, 'aux.core.search_cache')
        if success then
            search_cache = module
        end
    end
    return search_cache
end

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
    if not (ensure_search_cache() and search_cache.get) then return nil end

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

    -- Fallback: if no full filter match, try a simpler cache keyed only by crafted item
    if not (cached_data and cached_data.auctions) and crafted_name and crafted_name ~= '' then
        cached_data = search_cache.get(crafted_name .. '/exact')
    end

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

-- Return min unit price and available quantity for a specific item from cache
local function get_cached_item_price(filter_key, item_id)
    if not (item_id and ensure_search_cache() and search_cache.get) then return nil, nil end
    local cached_data = search_cache.get(filter_key)
    if not (cached_data and cached_data.auctions) then return nil, nil end

    local min_price
    local total_available = 0
    for _, cached_auction in ipairs(cached_data.auctions) do
        if cached_auction.item_id == item_id and cached_auction.unit_buyout_price and cached_auction.unit_buyout_price > 0 then
            if not min_price or cached_auction.unit_buyout_price < min_price then
                min_price = cached_auction.unit_buyout_price
            end
            total_available = total_available + (cached_auction.aux_quantity or 0)
        end
    end
    return min_price, total_available
end

-- Calculate estimated scan time for uncached items only (4 seconds per page/item)
function update_scan_all_estimate()
    local recipes = craft_vendor.get_recipes() or {}
    local scanned_mats = {}
    local total_items = 0
    
    -- Count unique uncached items only (outputs + materials)
    for recipe_name, recipe in pairs(recipes) do
        if recipe then
            -- Count output if uncached
            local crafted_name = crafted_search_name(recipe, recipe_name)
            if crafted_name and crafted_name ~= '' and recipe.output_id then
                local key = crafted_name .. '/exact'
                local cached_price = get_cached_item_price(key, recipe.output_id)
                if not cached_price then
                    total_items = total_items + 1
                end
            end
            
            -- Count unique uncached materials
            if recipe.materials then
                for _, mat in ipairs(recipe.materials) do
                    local mname = strlower(mat.name)
                    local key = mname .. '/exact'
                    if mname ~= '' and not scanned_mats[key] then
                        scanned_mats[key] = true
                        local cached_price = get_cached_item_price(key, mat.item_id)
                        if not cached_price then
                            total_items = total_items + 1
                        end
                    end
                end
            end
        end
    end
    
    -- Each item takes 4 seconds per page, scan-all uses 1 page per item
    -- Time estimate only counts uncached items (cached ones are instant)
    local estimated_seconds = total_items * 4
    local text = total_items == 0 and 'Scan Missing Mats (all cached)' or format('Scan Missing Mats (%ds)', estimated_seconds)
    
    if scan_all_button then
        scan_all_button:SetText(text)
    end
end

-- Build and run a scan that includes all unique mats and outputs for this profession
-- Prioritizes uncached items first, then cached items
function scan_all_materials()
    local recipes = craft_vendor.get_recipes() or {}
    scan_all_targets = {}
    local recipe_names = {}
    local scanned_mats = {}
    
    -- Collect sorted recipe names for consistent ordering
    for name, _ in pairs(recipes) do
        tinsert(recipe_names, name)
    end
    table.sort(recipe_names)
    
    -- Separate items into uncached and cached lists
    local uncached_items = {}  -- {key, item_id}
    local cached_items = {}    -- {key, item_id}
    
    -- Build output set for categorization
    local output_set = {}
    for _, recipe_name in ipairs(recipe_names) do
        local recipe = recipes[recipe_name]
        if recipe and recipe.output_id then
            local crafted_name = crafted_search_name(recipe, recipe_name)
            if crafted_name and crafted_name ~= '' then
                output_set[crafted_name .. '/exact'] = true
            end
        end
    end
    
    -- Collect all unique items and categorize by cache status
    for _, recipe_name in ipairs(recipe_names) do
        local recipe = recipes[recipe_name]
        if recipe then
            -- Add output for this recipe
            local crafted_name = crafted_search_name(recipe, recipe_name)
            if crafted_name and crafted_name ~= '' and recipe.output_id then
                local key = crafted_name .. '/exact'
                if not scanned_mats[key] then
                    scanned_mats[key] = true
                    local cached_price = get_cached_item_price(key, recipe.output_id)
                    if cached_price then
                        tinsert(cached_items, {key, recipe.output_id})
                    else
                        tinsert(uncached_items, {key, recipe.output_id})
                    end
                end
            end
            
            -- Add materials for this recipe
            if recipe.materials then
                for _, mat in ipairs(recipe.materials) do
                    local mname = strlower(mat.name)
                    local key = mname .. '/exact'
                    if mname ~= '' and not scanned_mats[key] then
                        scanned_mats[key] = true
                        local cached_price = get_cached_item_price(key, mat.item_id)
                        if cached_price then
                            tinsert(cached_items, {key, mat.item_id})
                        else
                            tinsert(uncached_items, {key, mat.item_id})
                        end
                    end
                end
            end
        end
    end
    
    -- Build filter: uncached items first, then cached items
    local filter_parts = {}
    local total_outputs = 0
    local total_materials = 0
    
    -- Add uncached items first
    for _, item_data in ipairs(uncached_items) do
        tinsert(filter_parts, item_data[1])
        scan_all_targets[item_data[1]] = item_data[2]
        if output_set[item_data[1]] then
            total_outputs = total_outputs + 1
        else
            total_materials = total_materials + 1
        end
    end
    
    -- Add cached items after
    for _, item_data in ipairs(cached_items) do
        tinsert(filter_parts, item_data[1])
        scan_all_targets[item_data[1]] = item_data[2]
        if output_set[item_data[1]] then
            total_outputs = total_outputs + 1
        else
            total_materials = total_materials + 1
        end
    end

    local filter = table.concat(filter_parts, ';')
    if filter == '' then
        return
    end

    search_box:SetText(filter)
    first_page_input:SetText('1')
    last_page_input:SetText('1')
    execute_search()
end

function quick_scan_recipe(recipe_name, recipe_obj)
    -- Quick scan for a single recipe: scan only 1 page of each material + output
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
    status_bar:set_text('Loading cached prices for quick scan...')
    update_search_display()
    
    -- Build filter for this recipe's output + materials
    local filter_parts = {}
    local crafted_name = crafted_search_name(recipe, recipe_name)
    
    -- Always include crafted item
    if crafted_name and crafted_name ~= '' then
        tinsert(filter_parts, crafted_name .. '/exact')
    end
    
    -- Add all materials
    if recipe.materials then
        for _, mat in ipairs(recipe.materials) do
            tinsert(filter_parts, strlower(mat.name) .. '/exact')
        end
    end
    
    local filter = table.concat(filter_parts, ';')
    if filter == '' then
        return
    end
    
    search_box:SetText(filter)
    first_page_input:SetText('1')
    last_page_input:SetText('1')
    execute_search()
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
scan_all_targets = nil -- map of filter key -> item_id for scan-all runs
show_only_craftable = false  -- filter to show only recipes with sufficient materials

-- Persistent inventory cache for performance
local inventory_cache = nil
local inventory_cache_dirty = true  -- initially dirty, rebuild on first use

-- Item info cache (Optimization #3)
local item_info_cache = {}

-- Deferred update timer (Optimization #5)
local deferred_update_pending = false
local deferred_update_timer = 0
local DEFERRED_UPDATE_INTERVAL = 0.5  -- 500ms between deferred updates

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

-- Invalidate the inventory cache (mark as dirty)
function invalidate_inventory_cache()
    inventory_cache_dirty = true
end

-- Invalidate item info cache
function invalidate_item_info_cache()
    item_info_cache = {}
end

-- Get or build the inventory cache on-demand
function get_or_build_inventory_cache()
    if inventory_cache_dirty or not inventory_cache then
        inventory_cache = build_inventory_cache()
        inventory_cache_dirty = false
    end
    return inventory_cache
end

function tab.OPEN()
    frame:Show()
    tab_is_open = true
    -- Rebuild inventory cache on tab open (player may have moved items)
    invalidate_inventory_cache()
    update_recipe_listing()
    update_search_display()
    update_cache_status()
    update_no_recipe_message()  -- Show/hide message based on cache status
    
    -- Initialize page inputs
    if first_page_input:GetText() == '' then
        first_page_input:SetText('1')
    end
    if last_page_input:GetText() == '' then
        last_page_input:SetText('2')
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

    local start_query, start_page = 1, 1
    if resume and search_continuation then
        start_query, start_page = unpack(search_continuation)
        start_query = start_query or 1
        start_page = start_page or 1
        for i = 1, start_query - 1 do
            tremove(queries, 1)
        end
        first_page_input:SetText(tostring(start_page))
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
    
    local max_pages = 999
    local first_page = tonumber(first_page_input:GetText())
    first_page = first_page and max(1, math.floor(first_page)) or 1
    if resume and start_page then
        first_page = start_page
    end

    local user_last_page = tonumber(last_page_input:GetText())
    user_last_page = user_last_page and max(1, math.floor(user_last_page)) or nil

    local desired_last_page = user_last_page and max(user_last_page, first_page) or (first_page + max_pages - 1)
    local effective_last_page = min(desired_last_page, first_page + max_pages - 1)

    local first_page_index = max(first_page - 1, 0)
    local last_page_index = max(effective_last_page - 1, first_page_index)

    for _, query in ipairs(queries) do
        if query.blizzard_query then
            query.blizzard_query.first_page = first_page_index
            query.blizzard_query.last_page = last_page_index
        end
    end

    local last_page = effective_last_page
    
    local current_query = 0
    local current_page = 1
    local total_queries = getn(queries)
    local page_records = {}
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
            page_records = {}
            local q = current_query > 0 and current_query or 1
            local tq = total_queries > 0 and total_queries or 1

            total_scan_pages = max(total_scan_pages or 1, 1)
            page_progress = min(page_progress or 0, total_scan_pages)
            current_page = actual_page or page_progress or 1

            -- Progress bar shows overall scan progress through all items, not per-page progress
            status_bar:update_status(q / tq, 0)

            -- Get current query's prettified name for display
            local query_name = ''
            if queries and queries[q] then
                query_name = queries[q].prettified or ''
            end

            -- Display format: "Q/TQ ItemName(Page X/Y)"
            local display_page = max(current_page or 1, 1)
            local display_total = max(
                total_scan_pages,
                (last_page and (last_page + 1)) or 0,
                display_page,
                1
            )

            -- Show overall query progress with current item name and page info
            status_bar:set_text(format('%d/%d %s(Page %d/%d)', q, tq, query_name ~= '' and query_name or 'Scanning', display_page, display_total))
            -- Set tooltip to show current item being scanned (strip brackets from prettified name)
            if query_name and query_name ~= '' then
                local success, clean_name = pcall(function() return query_name:gsub('[%[%]]', '') end)
                if success and clean_name then
                    status_bar:set_tooltip_text('Scanning: ' .. clean_name)
                else
                    status_bar:set_tooltip_text('Scanning: ' .. query_name)
                end
            else
                status_bar:set_tooltip_text('Scanning...')
            end
        end,
        on_auction = function(auction_record)
            if auction_record.buyout_price > 0 then
                tinsert(scan_results, auction_record)
                tinsert(page_records, auction_record)
                
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
            end
        end,
        on_page_scanned = function()
            if not scan_filter then return end
            local cache_ready = ensure_search_cache() and search_cache.store
            if cache_ready then
                -- Store cumulative results so far for this filter (allows aborting mid-run and still reusing data)
                search_cache.store(scan_filter, scan_results)
            end

            -- Build per-item buckets from the current page only for efficiency
            local buckets = {}
            local item_keys = {}

            if selected_recipe then
                if selected_recipe.output_id then
                    local crafted_key = crafted_search_name(selected_recipe, selected_recipe_name) .. '/exact'
                    buckets[crafted_key] = {}
                    item_keys[crafted_key] = selected_recipe.output_id
                end
                if selected_recipe.materials then
                    for _, mat in ipairs(selected_recipe.materials) do
                        local key = strlower(mat.name) .. '/exact'
                        buckets[key] = {}
                        item_keys[key] = mat.item_id
                    end
                end
            end

            if scan_all_targets then
                for key, item_id in pairs(scan_all_targets) do
                    buckets[key] = buckets[key] or {}
                    item_keys[key] = item_id
                end
            end

            if cache_ready and next(item_keys) then
                local source_records = getn(page_records) > 0 and page_records or scan_results
                for _, record in ipairs(source_records) do
                    for key, target_id in pairs(item_keys) do
                        if record.item_id == target_id then
                            tinsert(buckets[key], record)
                        end
                    end
                end
                for key, records in pairs(buckets) do
                    if getn(records) > 0 then
                        search_cache.store(key, records)
                    end
                end
            end

            -- Refresh recipe list so Mats/AH/Profit reflect newly cached prices per page
            update_recipe_listing()
            -- Update material listing once per page (moved from on_auction for performance)
            update_material_listing()
        end,
        on_complete = function()
            local ran_scan_all = scan_all_targets ~= nil
            scanning = false
            search_continuation = nil
            status_bar:update_status(1, 1)
            status_bar:set_text('Scan complete - ' .. getn(scan_results) .. ' auctions found')
            
            -- Store results in search cache for instant display on future recipe selection
            if scan_filter and getn(scan_results) > 0 then
                if ensure_search_cache() and search_cache.store then
                    search_cache.store(scan_filter, scan_results)

                    -- Build per-item buckets either from the selected recipe or the scan-all target map
                    local buckets = {}
                    local item_keys = {}

                    if selected_recipe then
                        -- Crafted item bucket
                        if selected_recipe.output_id then
                            local crafted_key = crafted_search_name(selected_recipe, selected_recipe_name) .. '/exact'
                            buckets[crafted_key] = {}
                            item_keys[crafted_key] = selected_recipe.output_id
                        end
                        -- Material buckets
                        if selected_recipe.materials then
                            for _, mat in ipairs(selected_recipe.materials) do
                                local key = strlower(mat.name) .. '/exact'
                                buckets[key] = {}
                                item_keys[key] = mat.item_id
                            end
                        end
                    end
                    if scan_all_targets then
                        for key, item_id in pairs(scan_all_targets) do
                            buckets[key] = buckets[key] or {}
                            item_keys[key] = item_id
                        end
                    end

                    if next(item_keys) then
                        -- Partition scan results into buckets by item_id
                        for _, record in ipairs(scan_results) do
                            for key, target_id in pairs(item_keys) do
                                if record.item_id == target_id then
                                    tinsert(buckets[key], record)
                                end
                            end
                        end

                        -- Store each bucket under its simple key
                        for key, records in pairs(buckets) do
                            if getn(records) > 0 then
                                search_cache.store(key, records)
                            end
                        end
                    end

                    -- Clear scan-all target map after use
                    scan_all_targets = nil
                end
            end
            
            update_search_display()
            update_material_listing()
            results_listing:SetDatabase(scan_results)

            -- Refresh recipe list so AH Price / mats cost can reflect freshly cached data (e.g., after Scan All)
            if ran_scan_all then
                invalidate_inventory_cache()
                update_recipe_listing()
            end
        end,
        on_abort = function()
            scanning = false
            -- Resume from next page of the current query
            search_continuation = { current_query or 1, (current_page or 1) + 1 }
            status_bar:update_status(1, 1)
            if search_continuation then
                status_bar:set_text('Scan paused - click Resume')
            else
                status_bar:set_text('Scan aborted')
            end
            update_search_display()
            update_material_listing()
            results_listing:SetDatabase(scan_results)
            if scan_all_targets then
                update_recipe_listing()
            end
        end,
    }
end

-- Check if a recipe is craftable (has all materials in inventory) using cached inventory counts
function is_recipe_craftable(recipe, inventory_cache)
    if not recipe or not recipe.materials then
        return false
    end
    
    for _, mat in ipairs(recipe.materials) do
        local inventory_count = inventory_cache[mat.item_id] or 0
        if inventory_count < mat.quantity then
            return false
        end
    end
    
    return true
end

-- Build a cache of inventory item counts for efficient filtering
function build_inventory_cache()
    local cache = {}
    for slot in info.inventory() do
        local item_info = info.container_item(unpack(slot))
        if item_info then
            local item_id = item_info.item_id
            cache[item_id] = (cache[item_id] or 0) + (item_info.count or 1)
        end
    end
    return cache
end

-- Optimization #3: Cache item info lookups to avoid repeated info.item() calls
function get_cached_item_info(item_id)
    if not item_info_cache[item_id] then
        item_info_cache[item_id] = info.item(item_id)
    end
    return item_info_cache[item_id]
end

-- Optimization #2: Pre-compute recipe material search keys to avoid repeated string operations
function precompute_recipe_keys(recipe)
    if recipe and not recipe._material_keys then
        recipe._material_keys = {}
        if recipe.materials then
            for i, mat in ipairs(recipe.materials) do
                recipe._material_keys[i] = strlower(mat.name) .. '/exact'
            end
        end
    end
end

-- Build recipe list for display
function get_recipe_list()
    local recipes = {}
    
    -- Get recipes directly from M.get_recipes() instead of through metatable
    -- (Lua 5.0 doesn't support __pairs metamethod, so metatable iteration doesn't work)
    local all_recipes = craft_vendor.get_recipes()
    
    local recipe_count = aux.size(all_recipes)
    
    -- Use persistent cached inventory for efficient filtering
    local inventory_cache = show_only_craftable and get_or_build_inventory_cache() or nil
    
    for name, recipe in pairs(all_recipes) do
        local vendor_price = recipe.vendor_price or 1  -- Default to 1 copper if nil
        local vendor_total = vendor_price * recipe.output_quantity
        local mat_count = getn(recipe.materials or {})
        local is_safe = mat_count == 1 or (mat_count > 0 and craft_vendor.is_safe_material(recipe.materials[1].item_id))
        
        -- Apply craftability filter if enabled
        if show_only_craftable and not is_recipe_craftable(recipe, inventory_cache) then
            -- Skip this recipe if it's not craftable and filter is enabled
        else
            tinsert(recipes, {
                name = name,
                recipe = recipe,
                vendor_value = vendor_total,
                mat_count = mat_count,
                is_safe = is_safe,
            })
        end
    end
    
    -- Sort alphabetically for stable display
    table.sort(recipes, function(a, b) return a.name < b.name end)
    return recipes
end

function update_recipe_listing()
    local rows = T.acquire()
    local recipes = get_recipe_list()
    
    -- Use cached inventory instead of building it again
    local inventory_cache = get_or_build_inventory_cache()
    
    for i, r in ipairs(recipes) do
        -- Optimization #2: Use pre-computed keys if available
        precompute_recipe_keys(r.recipe)
        
        local name_display = r.is_safe and aux.color.green(r.name) or r.name
        local icon_texture
        if r.recipe.output_id then
            -- Optimization #3: Use cached item info
            local item_info = get_cached_item_info(r.recipe.output_id)
            icon_texture = item_info and item_info.texture
        end
        if not icon_texture then
            icon_texture = 'Interface\\Icons\\INV_Misc_QuestionMark'
        end
        local stats = (r.recipe.output_id and recipe_stats_by_id[r.recipe.output_id]) or recipe_stats[r.name] or {}

        -- If we lack stored mat cost, try to derive it from cached per-item search results
        if not stats.mat_cost and r.recipe and r.recipe.materials then
            local total_cost = 0
            local complete = true
            for _, mat in ipairs(r.recipe.materials) do
                local key = r.recipe._material_keys[_] or (strlower(mat.name) .. '/exact')
                local cached_price = get_cached_item_price(key, mat.item_id)
                if cached_price then
                    total_cost = total_cost + (cached_price * mat.quantity)
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
        local ah_str
        if ah_price then
            ah_str = money.to_string(ah_price, nil, true)
        else
            ah_str = '-'
        end

        local mat_str
        if r.recipe and r.recipe.materials then
            -- Calculate cost of missing materials only (using cached inventory)
            local missing_cost = 0
            local has_prices = true
            for _, mat in ipairs(r.recipe.materials) do
                local key = r.recipe._material_keys[_] or (strlower(mat.name) .. '/exact')
                local cached_price = get_cached_item_price(key, mat.item_id)
                if cached_price then
                    local inventory_count = inventory_cache[mat.item_id] or 0
                    local needed = math.max(0, mat.quantity - inventory_count)
                    missing_cost = missing_cost + (cached_price * needed)
                else
                    has_prices = false
                    break
                end
            end
            if has_prices then
                mat_str = money.to_string(missing_cost, nil, true)
            else
                mat_str = '-'
            end
        elseif mat_cost then
            mat_str = money.to_string(mat_cost, nil, true)
        else
            mat_str = '-'
        end
        local profit_str
        if profit then
            local color = profit > 0 and aux.color.green or aux.color.red
            profit_str = color(money.to_string(profit, nil, true))
        else
            profit_str = '-'
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
    
    -- Optimization #5: Defer non-critical update
    schedule_deferred_update()
end

-- Optimization #5: Schedule deferred updates for expensive calculations
function schedule_deferred_update()
    if not deferred_update_pending and tab_is_open then
        deferred_update_pending = true
        deferred_update_timer = 0
    end
end

-- Handle deferred updates on OnUpdate
function process_deferred_updates(elapsed)
    if not elapsed or type(elapsed) ~= 'number' then
        return  -- Skip if elapsed is invalid
    end
    
    if deferred_update_pending then
        deferred_update_timer = deferred_update_timer + elapsed
        if deferred_update_timer >= DEFERRED_UPDATE_INTERVAL then
            update_scan_all_estimate()  -- Run expensive calculation
            deferred_update_pending = false
            deferred_update_timer = 0
        end
    end
end

-- Calculate profit for a recipe based on scanned material prices
function calculate_recipe_profit(recipe)
    local vendor_total = recipe.vendor_price * recipe.output_quantity
    local total_cost = 0
    local all_found = true
    local mat_details = {}
    
    for _, mat in ipairs(recipe.materials) do
        -- Check session prices first (from current search), then fallback to cached per-item search cache
        local price_info = material_prices[mat.item_id]
        if not price_info then
            local key = strlower(mat.name) .. '/exact'
            local cached_price = get_cached_item_price(key, mat.item_id)
            if cached_price then
                price_info = { min_price = cached_price }
            end
        end
        
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
    
    -- Persist summary for recipe list (only when we have meaningful data)
    local mat_cost_for_stats = eval.all_found and eval.total_cost or nil
    local ah_price_for_stats = crafted_item_price
    local profit_for_stats = (mat_cost_for_stats and ah_price_for_stats) and (ah_price_for_stats * (selected_recipe.output_quantity or 1) - mat_cost_for_stats) or nil
    update_recipe_stats_cache(selected_recipe, mat_cost_for_stats, ah_price_for_stats, profit_for_stats)
    update_recipe_listing()
    update_buy_missing_button()
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
    
    -- Invalidate inventory cache since user might have crafted/bought items since last check
    invalidate_inventory_cache()
    
    -- Clear old results immediately for instant visual feedback
    scan.abort(scan_id)
    material_prices = {}
    crafted_item_price = nil
    scan_results = {}
    results_listing:SetDatabase({})
    results_listing:Reset()
    status_bar:set_text('Loading cached prices...')
    update_search_display()
    
    local crafted_name = crafted_search_name(recipe, recipe_name)
    
    -- Load cached prices per material from the shared search cache
    local cached_count = 0
    if recipe.materials and ensure_search_cache() then
        for _, mat in ipairs(recipe.materials) do
            local key = strlower(mat.name) .. '/exact'
            local min_price, total_available = get_cached_item_price(key, mat.item_id)
            if min_price then
                material_prices[mat.item_id] = { min_price = min_price, count = total_available }
                cached_count = cached_count + 1
            end
        end
    end

    -- Load cached auction records from search_cache for instant display
    if ensure_search_cache() and search_cache.get then
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
            -- Try per-item cache as a fallback for crafted price
            local fallback_price = get_cached_item_price(crafted_name .. '/exact', recipe.output_id)
            if fallback_price then
                crafted_item_price = fallback_price
            end
        end
    else
        scan_results = {}
    end
    
    -- Update profit display with cached prices before search
    update_material_listing()
    
    -- Build search filter: uncached items first, then cached items for refresh
    -- This matches scan_all_materials behavior
    local uncached_items = {}
    local cached_items = {}
    
    -- Add crafted item
    if crafted_name and crafted_name ~= '' then
        local key = crafted_name .. '/exact'
        local cached_price = get_cached_item_price(key, recipe.output_id)
        if cached_price then
            tinsert(cached_items, key)
        else
            tinsert(uncached_items, key)
        end
    end
    
    -- Add materials
    if recipe.materials then
        for _, mat in ipairs(recipe.materials) do
            local key = strlower(mat.name) .. '/exact'
            local cached_price = get_cached_item_price(key, mat.item_id)
            if cached_price then
                tinsert(cached_items, key)
            else
                tinsert(uncached_items, key)
            end
        end
    end
    
    -- Build filter: uncached items first, then cached items
    local filter_parts = {}
    for _, key in ipairs(uncached_items) do
        tinsert(filter_parts, key)
    end
    for _, key in ipairs(cached_items) do
        tinsert(filter_parts, key)
    end
    
    filter_string = table.concat(filter_parts, ';')
    
    -- Update search box
    search_box:SetText(filter_string)
    
    -- Set page range for full recipe scan (no page limit, like normal recipe clicks)
    first_page_input:SetText('1')
    last_page_input:SetText('2')
    
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

-- Helper function to count items in inventory by item_id
function count_inventory_items(item_id)
    local count = 0
    for slot in info.inventory() do
        local item_info = info.container_item(unpack(slot))
        if item_info and item_info.item_id == item_id then
            count = count + (item_info.count or 1)
        end
    end
    return count
end

-- Update "Buy Missing Materials" button with price and profit info
function update_buy_missing_button()
    if not buy_missing_button or not selected_recipe then
        if buy_missing_button then
            buy_missing_button:SetText('Buy Missing Materials')
            buy_missing_button:Disable()
        end
        return
    end
    
    local to_buy_cost = 0
    local total_mat_cost = 0
    local items_to_buy = 0
    local has_missing_prices = false
    
    -- Calculate costs for missing and total materials
    if selected_recipe.materials then
        for _, mat in ipairs(selected_recipe.materials) do
            local inventory_count = count_inventory_items(mat.item_id)
            local needed = mat.quantity - inventory_count
            local mat_unit_price = material_prices[mat.item_id] and material_prices[mat.item_id].min_price or 0
            
            -- Check if we have price for this material
            if mat_unit_price == 0 then
                has_missing_prices = true
            end
            
            local mat_total_cost = mat_unit_price * mat.quantity
            total_mat_cost = total_mat_cost + mat_total_cost
            
            if needed > 0 then
                to_buy_cost = to_buy_cost + (mat_unit_price * needed)
                items_to_buy = items_to_buy + needed
            end
        end
    end
    
    -- Check if we have the crafted item price
    if crafted_item_price == nil or crafted_item_price == 0 then
        has_missing_prices = true
    end
    
    -- Disable button if any prices are missing
    if has_missing_prices then
        buy_missing_button:SetText('Buy Missing Materials (scanning...)')
        buy_missing_button:Disable()
        return
    end
    
    -- Calculate profit
    local craft_price = crafted_item_price or 0
    local craft_qty = selected_recipe.output_quantity or 1
    local craft_total = craft_price * craft_qty
    local profit = craft_total - total_mat_cost
    
    -- Build button text
    local button_text = 'Buy Missing Materials'
    if items_to_buy > 0 then
        local cost_str = money.to_string(to_buy_cost, nil, true)
        local profit_str = ''
        if profit > 0 then
            profit_str = ' | Profit: ' .. aux.color.green(money.to_string(profit, nil, true))
        elseif profit < 0 then
            profit_str = ' | Profit: ' .. aux.color.red(money.to_string(profit, nil, true))
        else
            profit_str = ' | Profit: 0'
        end
        button_text = 'Buy Missing: ' .. cost_str .. profit_str
        buy_missing_button:Enable()
    else
        -- All materials already in inventory
        local profit_str = ''
        if profit > 0 then
            profit_str = ' | Profit: ' .. aux.color.green(money.to_string(profit, nil, true))
        elseif profit < 0 then
            profit_str = ' | Profit: ' .. aux.color.red(money.to_string(profit, nil, true))
        else
            profit_str = ' | Profit: 0'
        end
        local craft_qty = selected_recipe.output_quantity or 1
        button_text = 'Ready to Craft (x' .. craft_qty .. ')' .. profit_str
        buy_missing_button:Enable()
    end
    
    buy_missing_button:SetText(button_text)
end

-- Buy missing materials to craft 1 item
function buy_missing_materials()
    if not selected_recipe then
        return
    end
    
    local to_buy = {}
    local total_to_buy = 0
    
    -- Check each material against inventory
    if selected_recipe.materials then
        for _, mat in ipairs(selected_recipe.materials) do
            local inventory_count = count_inventory_items(mat.item_id)
            local needed = mat.quantity - inventory_count
            
            if needed > 0 then
                tinsert(to_buy, {
                    name = mat.name,
                    item_id = mat.item_id,
                    quantity = needed,
                    quantity_per_stack = info.item(mat.item_id).stack_count or 20
                })
                total_to_buy = total_to_buy + needed
            end
        end
    end
    
    if total_to_buy == 0 then
        return
    end
    
    -- Build search filter for missing materials
    local filter_parts = {}
    for _, item in ipairs(to_buy) do
        tinsert(filter_parts, strlower(item.name) .. '/exact')
    end
    
    local filter_string = table.concat(filter_parts, ';')
    
    -- Switch to Search tab and search for missing materials
    aux.set_tab(1)
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
