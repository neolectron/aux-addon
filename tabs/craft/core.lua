module 'aux.tabs.craft'

local T = require 'T'
local aux = require 'aux'
local info = require 'aux.util.info'
local money = require 'aux.util.money'
local filter_util = require 'aux.util.filter'
local scan = require 'aux.core.scan'
local craft_vendor = require 'aux.core.craft_vendor'
local search_tab = require 'aux.tabs.search'

local tab = aux.tab 'Craft'

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

function tab.OPEN()
    frame:Show()
    update_recipe_listing()
    update_search_display()
    
    -- Initialize page inputs
    if first_page_input:GetText() == '' then
        first_page_input:SetText('1')
    end
end

function tab.CLOSE()
    frame:Hide()
    scan.abort(scan_id)
end

-- Execute search from search box
function execute_search(resume)
    local filter_string = search_box:GetText()
    if filter_string == '' and not resume then return end
    
    local queries, error = filter_util.queries(filter_string)
    if not queries and not resume then
        status_bar:set_text('Filter error: ' .. (error or 'unknown'))
        return
    end
    
    scan.abort(scan_id)
    
    local continuation = resume and search_continuation or nil
    search_continuation = nil
    
    if not resume then
        scan_results = {}
        material_prices = {}
        crafted_item_price = nil
        results_listing:SetDatabase()
        results_listing:Reset()
    end
    
    scanning = true
    update_search_display()
    status_bar:update_status(0, 0)
    status_bar:set_text('Scanning...')
    
    local first_page = tonumber(first_page_input:GetText())
    local last_page = tonumber(last_page_input:GetText())
    
    scan_id = scan.start{
        type = 'list',
        queries = queries,
        continuation = continuation,
        start_page = not continuation and first_page or nil,
        end_page = last_page,
        on_page_loaded = function(page, total_pages)
            status_bar:update_status(page / total_pages, 0)
            status_bar:set_text(format('Scanning (Page %d / %d)', page, total_pages))
        end,
        on_auction = function(auction_record)
            if auction_record.buyout_price > 0 then
                tinsert(scan_results, auction_record)
                
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
        on_complete = function()
            scanning = false
            search_continuation = nil
            status_bar:update_status(1, 1)
            status_bar:set_text('Scan complete - ' .. getn(scan_results) .. ' auctions found')
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
    for name, recipe in pairs(craft_vendor.recipes) do
        local vendor_total = recipe.vendor_price * recipe.output_quantity
        local mat_count = getn(recipe.materials)
        local is_safe = mat_count == 1 or craft_vendor.is_safe_material(recipe.materials[1].item_id)
        
        tinsert(recipes, {
            name = name,
            recipe = recipe,
            vendor_value = vendor_total,
            mat_count = mat_count,
            is_safe = is_safe,
        })
    end
    
    -- Sort by vendor value descending
    table.sort(recipes, function(a, b) return a.vendor_value > b.vendor_value end)
    return recipes
end

function update_recipe_listing()
    local rows = T.acquire()
    local recipes = get_recipe_list()
    
    for i, r in ipairs(recipes) do
        local name_display = r.is_safe and aux.color.green(r.name) or r.name
        local vendor_str = money.to_string(r.vendor_value, nil, true)
        
        tinsert(rows, T.map(
            'cols', T.list(
                T.map('value', name_display),
                T.map('value', vendor_str)
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
    
    for _, mat in ipairs(recipe.materials) do
        local price_info = material_prices[mat.item_id]
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

-- Update material listing after scan
function update_material_listing()
    if not selected_recipe then return end
    
    local eval = calculate_recipe_profit(selected_recipe)
    
    -- Update profit display with vendor and auction profit
    if eval.all_found then
        local profit_color = eval.profit > 0 and aux.color.green or aux.color.red
        profit_label:SetText('Profit: ' .. profit_color(money.to_string(eval.profit, nil, true)))
        cost_label:SetText('Cost: ' .. money.to_string(eval.total_cost, nil, true))
        vendor_label:SetText('Vendor: ' .. money.to_string(eval.vendor_value, nil, true))
        
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
        profit_label:SetText('Profit: ' .. aux.color.red('Missing materials'))
        cost_label:SetText('Cost: -')
        vendor_label:SetText('Vendor: ' .. money.to_string(eval.vendor_value, nil, true))
        auction_profit_label:SetText('AH Profit: -')
    end
end

-- Scan for materials of selected recipe
function scan_recipe_materials(recipe_name)
    local recipe = craft_vendor.recipes[recipe_name]
    if not recipe then return end
    
    selected_recipe = recipe
    selected_recipe_name = recipe_name
    
    -- Build search filter: materials + crafted item
    local filter_parts = {}
    
    -- Add the crafted item first (so icon loads)
    tinsert(filter_parts, strlower(recipe_name) .. '/exact')
    
    -- Add all materials
    for _, mat in ipairs(recipe.materials) do
        tinsert(filter_parts, strlower(mat.name) .. '/exact')
    end
    local filter_string = table.concat(filter_parts, ';')
    
    -- Update search box
    search_box:SetText(filter_string)
    
    -- Set page range to scan all pages
    first_page_input:SetText('1')
    last_page_input:SetText('')
    
    -- Execute search
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
