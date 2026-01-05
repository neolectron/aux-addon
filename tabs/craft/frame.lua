module 'aux.tabs.craft'

local T = require 'T'
local aux = require 'aux'
local info = require 'aux.util.info'
local money = require 'aux.util.money'
local gui = require 'aux.gui'
local listing = require 'aux.gui.listing'
local auction_listing = require 'aux.gui.auction_listing'
local search_tab = require 'aux.tabs.search'
local craft_vendor = require 'aux.core.craft_vendor'
local scan = require 'aux.core.scan'
local filter_util = require 'aux.util.filter'
local completion = require 'aux.util.completion'

function aux.handle.INIT_UI()
    frame = CreateFrame('Frame', nil, aux.frame)
    frame:SetAllPoints()
    frame:Hide()

    -- Search bar at top (similar to Search tab)
    do
        local btn = gui.button(frame, gui.font_size.small)
        btn:SetPoint('TOPLEFT', 5, -8)
        btn:SetHeight(25)
        btn:SetWidth(60)
        btn:SetText(aux.color.label.enabled'Range:')
        btn:SetScript('OnClick', function()
            update_real_time(true)
        end)
        range_button = btn
    end
    do
        local btn = gui.button(frame, gui.font_size.small)
        btn:SetPoint('TOPLEFT', 5, -8)
        btn:SetHeight(25)
        btn:SetWidth(gui.is_blizzard() and 70 or 60)
        btn:Hide()
        btn:SetText(aux.color.label.enabled'Real Time')
        btn:SetScript('OnClick', function()
            update_real_time(false)
        end)
        real_time_button = btn
    end
    do
        local function change()
            local page = tonumber(this:GetText())
            local valid_input = page and tostring(max(1, page)) or ''
            if this:GetText() ~= valid_input then
                this:SetText(valid_input)
            end
        end
        do
            local editbox = gui.editbox(range_button)
            editbox:SetPoint('LEFT', range_button, 'RIGHT', gui.is_blizzard() and 8 or 4, 0)
            editbox:SetWidth(40)
            editbox:SetHeight(25)
            editbox:SetAlignment('CENTER')
            editbox:SetNumeric(true)
            editbox:SetScript('OnTabPressed', function()
                if not IsShiftKeyDown() then
                    last_page_input:SetFocus()
                end
            end)
            editbox.enter = execute_search
            editbox.change = change
            local label = gui.label(editbox, gui.font_size.medium)
            label:SetPoint('LEFT', editbox, 'RIGHT', 0, 0)
            label:SetTextColor(aux.color.label.enabled())
            label:SetText('-')
            first_page_input = editbox
        end
        do
            local editbox = gui.editbox(range_button)
            editbox:SetPoint('LEFT', first_page_input, 'RIGHT', gui.is_blizzard() and 11 or 5.8, 0)
            editbox:SetWidth(40)
            editbox:SetHeight(25)
            editbox:SetAlignment('CENTER')
            editbox:SetNumeric(true)
            editbox:SetScript('OnTabPressed', function()
                if IsShiftKeyDown() then
                    first_page_input:SetFocus()
                else
                    search_box:SetFocus()
                end
            end)
            editbox.enter = execute_search
            editbox.change = change
            last_page_input = editbox
        end
    end
    do
        local btn = gui.button(frame)
        btn:SetHeight(25)
        btn:SetPoint('TOPRIGHT', -5, -8)
        btn:SetText('Search')
        btn:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
        btn:SetScript('OnClick', function()
            execute_search()
        end)
        start_button = btn
    end
    do
        local btn = gui.button(frame)
        btn:SetHeight(25)
        btn:SetPoint('TOPRIGHT', -5, -8)
        btn:SetText('Stop')
        btn:SetScript('OnClick', function()
            scan.abort(scan_id)
        end)
        stop_button = btn
    end
    do
        local btn = gui.button(frame)
        btn:SetHeight(25)
        btn:SetPoint('RIGHT', start_button, 'LEFT', -4, 0)
        btn:SetBackdropColor(aux.color.state.enabled())
        btn:SetText('Resume')
        btn:SetScript('OnClick', function()
            execute_search(true)
        end)
        resume_button = btn
    end
    do
        local editbox = gui.editbox(frame)
        editbox:EnableMouse(1)
        editbox.formatter = function(str)
            local queries = filter_util.queries(str)
            return queries and aux.join(aux.map(aux.copy(queries), function(query) return query.prettified end), ';') or aux.color.red(str)
        end
        editbox.complete = completion.complete_filter
        editbox.escape = function() this:SetText('') end
        editbox:SetHeight(25)
        editbox.char = function()
            this:complete()
        end
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                last_page_input:SetFocus()
            else
                this:HighlightText(0, 0)
            end
        end)
        editbox.enter = execute_search
        search_box = editbox
    end
    do
        gui.horizontal_line(frame, -40)
    end

    -- Prominent message when no recipes are cached
    do
        local msg_frame = CreateFrame('Frame', nil, frame)
        msg_frame:SetPoint('TOPLEFT', aux.frame.content, 'TOPLEFT', 0, -45)
        msg_frame:SetPoint('TOPRIGHT', aux.frame.content, 'TOPRIGHT', 0, -45)
        msg_frame:SetHeight(80)
        msg_frame:Hide()  -- Hidden by default
        
        -- Background (WoW 1.12 compatible)
        local bg = msg_frame:CreateTexture(nil, 'BACKGROUND')
        bg:SetAllPoints()
        bg:SetTexture(0.1, 0.1, 0.1)
        bg:SetAlpha(0.8)
        
        -- Icon
        local icon = msg_frame:CreateTexture(nil, 'ARTWORK')
        icon:SetWidth(32)
        icon:SetHeight(32)
        icon:SetPoint('LEFT', 15, 0)
        icon:SetTexture('Interface\\Icons\\INV_Misc_QuestionMark')
        
        -- Title
        local title = msg_frame:CreateFontString(nil, 'OVERLAY')
        title:SetFont(STANDARD_TEXT_FONT, 13, 'BOLD')
        title:SetPoint('TOPLEFT', icon, 'TOPRIGHT', 10, 5)
        title:SetPoint('RIGHT', -15, 0)
        title:SetTextColor(1, 0.82, 0)
        title:SetText('No Profession Data Found')
        title:SetJustifyH('LEFT')
        
        -- Instructions
        local text = msg_frame:CreateFontString(nil, 'OVERLAY')
        text:SetFont(STANDARD_TEXT_FONT, 11)
        text:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -5)
        text:SetPoint('RIGHT', -15, 0)
        text:SetTextColor(1, 1, 1)
        text:SetText('Open your profession windows (Mining, Engineering, etc.) to automatically scan and cache recipes.|n|nRecipes will persist across sessions for instant access.')
        text:SetJustifyH('LEFT')
        
        no_recipe_message = msg_frame
    end

    -- Left panel: Recipe list
    frame.recipes = gui.panel(frame)
    frame.recipes:SetWidth(240)
    frame.recipes:SetPoint('TOPLEFT', aux.frame.content, 'TOPLEFT', 0, 0)
    frame.recipes:SetPoint('BOTTOMLEFT', aux.frame.content, 'BOTTOMLEFT', 0, 40)

    recipe_listing = listing.new(frame.recipes)
    recipe_listing:SetColInfo{
        {name='Recipe', width=.70, align='LEFT'},    -- Recipe name (with safe indicator)
        {name='Vendor', width=.30, align='RIGHT'},   -- Vendor value
    }
    recipe_listing:SetSelection(function(data)
        return data and data.recipe_name and data.recipe_name == selected_recipe_name
    end)
    recipe_listing:SetHandler('OnClick', function(st, data, self, button)
        if data and data.recipe_name and data.recipe then
            selected_recipe_name = data.recipe_name
            selected_recipe = data.recipe  -- Use the recipe object directly
            scan_recipe_materials(data.recipe_name, data.recipe)
            st:Update()  -- Refresh to show selection highlight
        end
    end)
    recipe_listing:SetHandler('OnEnter', function(st, data, self)
        if not data or not data.recipe then return end
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
        GameTooltip:AddLine(data.recipe_name, 1, 1, 1)
        GameTooltip:AddLine(' ')
        GameTooltip:AddLine('Materials:', 1, 0.82, 0)
        for _, mat in ipairs(data.recipe.materials) do
            GameTooltip:AddLine('  ' .. mat.quantity .. 'x ' .. mat.name, 1, 1, 1)
        end
        GameTooltip:AddLine(' ')
        GameTooltip:AddLine('Left-click to scan for materials', 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    recipe_listing:SetHandler('OnLeave', function(st, data, self)
        GameTooltip:ClearLines()
        GameTooltip:Hide()
    end)

    -- Right side: Profit info at bottom, results fill the rest
    -- Profit info panel (bottom right, above status bar)
    frame.profit_info = CreateFrame('Frame', nil, frame)
    frame.profit_info:SetHeight(22)
    frame.profit_info:SetPoint('BOTTOMLEFT', aux.frame.content, 'BOTTOMLEFT', 245, 40)
    frame.profit_info:SetPoint('BOTTOMRIGHT', aux.frame.content, 'BOTTOMRIGHT', 0, 40)
    
    do
        vendor_label = gui.label(frame.profit_info, gui.font_size.small)
        vendor_label:SetPoint('LEFT', 8, 0)
        vendor_label:SetText('Vendor: -')
    end
    do
        cost_label = gui.label(frame.profit_info, gui.font_size.small)
        cost_label:SetPoint('LEFT', vendor_label, 'RIGHT', 8, 0)
        cost_label:SetText('Cost: -')
    end
    do
        profit_label = gui.label(frame.profit_info, gui.font_size.small)
        profit_label:SetPoint('LEFT', cost_label, 'RIGHT', 8, 0)
        profit_label:SetText('Profit: -')
    end
    do
        auction_profit_label = gui.label(frame.profit_info, gui.font_size.small)
        auction_profit_label:SetPoint('LEFT', profit_label, 'RIGHT', 8, 0)
        auction_profit_label:SetText('AH Profit: -')
    end

    -- Results panel (fills space from top to profit info)
    frame.results = gui.panel(frame)
    frame.results:SetPoint('TOPLEFT', frame.recipes, 'TOPRIGHT', 5, 0)
    frame.results:SetPoint('TOPRIGHT', aux.frame.content, 'TOPRIGHT', 0, 0)
    frame.results:SetPoint('BOTTOMLEFT', frame.profit_info, 'TOPLEFT', 0, 3)
    frame.results:SetPoint('BOTTOMRIGHT', frame.profit_info, 'TOPRIGHT', 0, 3)

    results_listing = auction_listing.new(frame.results, 16, auction_listing.search_columns)
    results_listing:SetSort(1, 2, 3, 4, 5, 6, 7, 8)
    results_listing:Reset()
    results_listing:SetHandler('OnClick', function(row, button)
        if IsAltKeyDown() and button == 'LeftButton' then
            -- Buy on alt-click
            buyout_auction(row.record)
        elseif button == 'RightButton' then
            -- Search in Search tab
            aux.set_tab(1)
            search_tab.set_filter(strlower(info.item(row.record.item_id).name) .. '/exact')
            search_tab.execute(nil, false)
        end
    end)

    -- Bottom bar: Status
    do
        status_bar = gui.status_bar(frame)
        status_bar:SetWidth(265)
        status_bar:SetHeight(25)
        status_bar:SetPoint('TOPLEFT', aux.frame.content, 'BOTTOMLEFT', 0, -6)
        status_bar:update_status(1, 0)
        status_bar:set_text('Select a recipe to scan')
        status_bar_frame = status_bar
    end
    
    -- Cache status label
    do
        local label = gui.label(frame, gui.font_size.small)
        label:SetPoint('LEFT', status_bar, 'RIGHT', 8, 0)
        label:SetText('No recipes')
        cache_status_label = label
    end
    
    -- Rescan button (force open profession windows)
    do
        local btn = gui.button(frame, gui.font_size.small)
        btn:SetHeight(25)
        btn:SetWidth(60)
        btn:SetPoint('LEFT', cache_status_label, 'RIGHT', 8, 0)
        btn:SetText('Rescan')
        btn:SetScript('OnClick', function()
            aux.print('Please open your profession windows to scan recipes.')
            aux.print('Recipes will be automatically cached for future use.')
        end)
    end
    
    do
        local btn = gui.button(frame)
        btn:SetPoint('TOPLEFT', status_bar, 'TOPRIGHT', 5, 0)
        btn:SetText('Bid')
        btn:Disable()
        bid_button = btn
    end
    do
        local btn = gui.button(frame)
        btn:SetPoint('TOPLEFT', bid_button, 'TOPRIGHT', 5, 0)
        btn:SetText('Buyout')
        btn:Disable()
        buyout_button = btn
    end
    
    -- Initial state
    update_search_display()
end

function update_real_time(enable)
    if enable then
        range_button:Hide()
        real_time_button:Show()
        search_box:SetPoint('LEFT', real_time_button, 'RIGHT', gui.is_blizzard() and 8 or 4, 0)
    else
        real_time_button:Hide()
        range_button:Show()
        search_box:SetPoint('LEFT', last_page_input, 'RIGHT', gui.is_blizzard() and 8 or 4, 0)
    end
    real_time = enable
end

function update_search_display()
    -- Position search box
    if real_time then
        search_box:SetPoint('LEFT', real_time_button, 'RIGHT', gui.is_blizzard() and 8 or 4, 0)
    else
        search_box:SetPoint('LEFT', last_page_input, 'RIGHT', gui.is_blizzard() and 8 or 4, 0)
    end
    
    if scanning then
        start_button:Hide()
        stop_button:Show()
        resume_button:Hide()
        search_box:SetPoint('RIGHT', stop_button, 'LEFT', -4, 0)
    else
        stop_button:Hide()
        if search_continuation then
            start_button:Hide()
            resume_button:Show()
            search_box:SetPoint('RIGHT', resume_button, 'LEFT', -4, 0)
        else
            start_button:Show()
            resume_button:Hide()
            search_box:SetPoint('RIGHT', start_button, 'LEFT', -4, 0)
        end
    end
end

-- Buy an auction from results
function buyout_auction(record)
    if not record or record.buyout_price == 0 then return end
    
    local scan_util = require 'aux.util.scan'
    scan_util.find(
        record,
        status_bar,
        function() end,  -- not found
        function()  -- removed
            results_listing:RemoveAuctionRecord(record)
        end,
        function(index)  -- found
            aux.place_bid('list', index, record.buyout_price, function()
                results_listing:RemoveAuctionRecord(record)
                -- Update material prices after purchase
                local item_id = record.item_id
                if material_prices[item_id] then
                    material_prices[item_id].count = material_prices[item_id].count - record.aux_quantity
                end
                update_material_listing()
            end)
        end
    )
end
