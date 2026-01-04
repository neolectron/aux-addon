module 'aux.util.purchase_summary'

local T = require 'T'
local aux = require 'aux'
local gui = require 'aux.gui'
local money = require 'aux.util.money'
local info = require 'aux.util.info'
local craft_vendor = require 'aux.core.craft_vendor'

-- Purchase summary data storage (session only)
local purchase_summaries = {}

-- Session start time (for gold/hour calculation)
local session_start_time = nil

-- Purchase summary display frame
local purchase_summary_frame

function M.get_summaries()
	return purchase_summaries
end

function M.clear_summaries()
	T.wipe(purchase_summaries)
	session_start_time = nil
end

-- Get vendor price for an item (handles charges for items like wands)
local function get_vendor_price(item_id)
	local vendor_price = info.merchant_info(item_id)
	if not vendor_price and ShaguTweaks then
		vendor_price = ShaguTweaks.SellValueDB[item_id]
		if vendor_price then
			local charges = info.max_item_charges(item_id)
			if charges then
				vendor_price = vendor_price / charges
			end
		end
	end
	return vendor_price
end

-- Save profit to persistent storage with timestamp and item stats
local function save_profit(cost, vendor_value, quantity, item_id, item_name)
	if not aux.character_data or not aux.character_data.profit_history then return end
	local history = aux.character_data.profit_history
	local current_time = time()
	
	history.total_spent = (history.total_spent or 0) + cost
	history.total_vendor_value = (history.total_vendor_value or 0) + vendor_value
	history.total_items = (history.total_items or 0) + quantity
	
	-- Track time for gold/hour calculation
	if not history.first_purchase_time then
		history.first_purchase_time = current_time
	end
	history.last_purchase_time = current_time
	
	-- Track per-item statistics
	if item_id and item_name then
		history.item_stats = history.item_stats or {}
		local item_key = tostring(item_id)
		if not history.item_stats[item_key] then
			history.item_stats[item_key] = {
				name = item_name,
				count = 0,
				total_profit = 0,
				total_spent = 0,
				total_vendor = 0,
			}
		end
		local stats = history.item_stats[item_key]
		stats.name = item_name  -- Update name in case it changed
		stats.count = stats.count + quantity
		stats.total_spent = stats.total_spent + cost
		stats.total_vendor = stats.total_vendor + vendor_value
		stats.total_profit = stats.total_vendor - stats.total_spent
	end
end

-- Get all-time profit stats
function M.get_alltime_profit()
	if not aux.character_data or not aux.character_data.profit_history then 
		return 0, 0, 0 
	end
	local history = aux.character_data.profit_history
	return history.total_spent or 0, history.total_vendor_value or 0, history.total_items or 0
end

-- Get gold per hour (all-time)
function M.get_gold_per_hour()
	if not aux.character_data or not aux.character_data.profit_history then return 0 end
	local history = aux.character_data.profit_history
	
	local first_time = history.first_purchase_time
	local last_time = history.last_purchase_time
	if not first_time or not last_time then return 0 end
	
	local elapsed_seconds = last_time - first_time
	if elapsed_seconds < 60 then return 0 end  -- Need at least 1 minute of data
	
	local profit = (history.total_vendor_value or 0) - (history.total_spent or 0)
	local hours = elapsed_seconds / 3600
	
	return profit / hours
end

-- Get session gold per hour
function M.get_session_gold_per_hour()
	if not session_start_time then return 0 end
	
	local elapsed_seconds = time() - session_start_time
	if elapsed_seconds < 60 then return 0 end  -- Need at least 1 minute
	
	local total_vendor = 0
	local total_spent = 0
	for _, summary in purchase_summaries do
		total_spent = total_spent + (summary.total_cost or 0)
		total_vendor = total_vendor + (summary.total_vendor_value or 0)
	end
	
	local profit = total_vendor - total_spent
	local hours = elapsed_seconds / 3600
	
	return profit / hours
end

-- Reset all-time profit tracking
function M.reset_alltime_profit()
	if not aux.character_data or not aux.character_data.profit_history then return end
	aux.character_data.profit_history.total_spent = 0
	aux.character_data.profit_history.total_vendor_value = 0
	aux.character_data.profit_history.total_items = 0
	aux.character_data.profit_history.first_purchase_time = nil
	aux.character_data.profit_history.last_purchase_time = nil
	aux.character_data.profit_history.item_stats = {}
end

-- Get top profitable items sorted by total profit
function M.get_top_items(limit)
	limit = limit or 10
	if not aux.character_data or not aux.character_data.profit_history then return {} end
	local item_stats = aux.character_data.profit_history.item_stats
	if not item_stats then return {} end
	
	-- Convert to array for sorting
	local items = {}
	for item_id, stats in pairs(item_stats) do
		tinsert(items, {
			item_id = tonumber(item_id),
			name = stats.name,
			count = stats.count or 0,
			total_profit = stats.total_profit or 0,
			total_spent = stats.total_spent or 0,
			total_vendor = stats.total_vendor or 0,
			avg_profit = (stats.count and stats.count > 0) and ((stats.total_profit or 0) / stats.count) or 0,
		})
	end
	
	-- Sort by total profit descending
	table.sort(items, function(a, b) return a.total_profit > b.total_profit end)
	
	-- Return top N
	local result = {}
	for i = 1, min(limit, getn(items)) do
		result[i] = items[i]
	end
	return result
end

-- Print top items to chat
function M.print_top_items(limit)
	limit = limit or 10
	local items = M.get_top_items(limit)
	
	if getn(items) == 0 then
		aux.print('No item statistics yet. Start auto-buying!')
		return
	end
	
	aux.print(aux.color.gold('--- Top ' .. limit .. ' Profitable Items ---'))
	for i, item in ipairs(items) do
		local profit_gold = item.total_profit / 10000
		local avg_gold = item.avg_profit / 10000
		local color = item.total_profit >= 0 and aux.color.green or aux.color.red
		aux.print(format('%d. %s - %s (x%d, avg: %.1fg)', 
			i, 
			item.name or 'Unknown', 
			color(format('%.1fg', profit_gold)),
			item.count,
			avg_gold
		))
	end
end

function M.add_purchase(name, texture, quantity, cost, item_id)
	if not name then return end

	-- Start session timer on first purchase
	if not session_start_time then
		session_start_time = time()
	end

	if not purchase_summaries[name] then
		purchase_summaries[name] = {
			item_name = name,
			texture = texture or '',
			item_id = item_id,
			total_quantity = 0,
			total_cost = 0,
			total_vendor_value = 0,
			purchase_count = 0
		}
	end

	local qty = quantity or 0
	local item_cost = cost or 0
	
	purchase_summaries[name].total_quantity = purchase_summaries[name].total_quantity + qty
	purchase_summaries[name].total_cost = purchase_summaries[name].total_cost + item_cost
	purchase_summaries[name].purchase_count = purchase_summaries[name].purchase_count + 1
	
	-- Track vendor value for profit calculation
	local vendor_value = 0
	if item_id then
		purchase_summaries[name].item_id = item_id
		local vendor_price = get_vendor_price(item_id)
		if vendor_price then
			vendor_value = vendor_price * qty
			purchase_summaries[name].total_vendor_value = purchase_summaries[name].total_vendor_value + vendor_value
		end
		
		-- Track for craft-to-vendor system - check if material is for a recipe
		if craft_vendor and craft_vendor.material_to_recipes and craft_vendor.material_to_recipes[item_id] then
			-- This is a craft material! Use on_material_bought for notifications
			craft_vendor.on_material_bought(item_id, name, qty, item_cost)
		elseif craft_vendor and craft_vendor.add_to_session then
			-- Not a craft material, just track normally
			craft_vendor.add_to_session(item_id, name, qty, item_cost)
		end
	end
	
	-- Save to persistent storage (including per-item stats)
	save_profit(item_cost, vendor_value, qty, item_id, name)
end

local ROW_HEIGHT = 14
local PANEL_WIDTH = 340

function create_purchase_summary_frame()
	if purchase_summary_frame then return purchase_summary_frame end
	
	-- Safety check: aux.frame must exist
	if not aux.frame then return nil end

	-- Parent to UIParent so it's not hidden when aux.frame is hidden
	-- Anchor to RIGHT side of aux.frame as a side panel
	purchase_summary_frame = CreateFrame('Frame', 'AuxPurchaseSummary', UIParent)
	purchase_summary_frame:SetWidth(PANEL_WIDTH)
	purchase_summary_frame:SetHeight(300)  -- Will be dynamically resized to match aux.frame
	-- Position to the right of aux frame with small gap
	purchase_summary_frame:SetPoint('TOPLEFT', aux.frame, 'TOPRIGHT', 4, 0)
	purchase_summary_frame:SetPoint('BOTTOMLEFT', aux.frame, 'BOTTOMRIGHT', 4, 0)
	purchase_summary_frame:SetFrameStrata('HIGH')
	purchase_summary_frame:SetFrameLevel(aux.frame:GetFrameLevel() + 5)

	-- Use aux's standard panel styling
	gui.set_panel_style(purchase_summary_frame, 2, 2, 2, 2)
	purchase_summary_frame:Hide()

	-- Title
	local title = purchase_summary_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
	title:SetPoint('TOPLEFT', 8, -8)
	title:SetText('Purchases')
	title:SetTextColor(aux.color.label.enabled())
	purchase_summary_frame.title = title

	-- Session g/h (line 1)
	local session_gph_text = purchase_summary_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	session_gph_text:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -8)
	session_gph_text:SetJustifyH('LEFT')
	session_gph_text:SetTextColor(0.7, 0.7, 0.7) -- Gray
	purchase_summary_frame.session_gph_text = session_gph_text

	-- Session profit (line 2)
	local session_label = purchase_summary_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	session_label:SetPoint('TOPLEFT', session_gph_text, 'BOTTOMLEFT', 0, -2)
	session_label:SetText('Session:')
	session_label:SetTextColor(aux.color.label.enabled())
	purchase_summary_frame.session_label = session_label

	local session_profit_text = purchase_summary_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	session_profit_text:SetPoint('LEFT', session_label, 'RIGHT', 5, 0)
	session_profit_text:SetJustifyH('LEFT')
	session_profit_text:SetTextColor(0, 1, 0) -- Green
	purchase_summary_frame.session_profit_text = session_profit_text

	-- All-time g/h (line 3)
	local alltime_gph_text = purchase_summary_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	alltime_gph_text:SetPoint('TOPLEFT', session_label, 'BOTTOMLEFT', 0, -6)
	alltime_gph_text:SetJustifyH('LEFT')
	alltime_gph_text:SetTextColor(0.7, 0.7, 0.7) -- Gray
	purchase_summary_frame.alltime_gph_text = alltime_gph_text

	-- All-time profit (line 4)
	local alltime_label = purchase_summary_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	alltime_label:SetPoint('TOPLEFT', alltime_gph_text, 'BOTTOMLEFT', 0, -2)
	alltime_label:SetText('All-Time:')
	alltime_label:SetTextColor(aux.color.label.enabled())
	purchase_summary_frame.alltime_label = alltime_label

	local alltime_profit_text = purchase_summary_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	alltime_profit_text:SetPoint('LEFT', alltime_label, 'RIGHT', 5, 0)
	alltime_profit_text:SetJustifyH('LEFT')
	alltime_profit_text:SetTextColor(1, 0.82, 0) -- Gold
	purchase_summary_frame.alltime_profit_text = alltime_profit_text

	-- Separator line
	local separator = purchase_summary_frame:CreateTexture(nil, 'ARTWORK')
	separator:SetTexture(1, 1, 1, 0.3)
	separator:SetHeight(1)
	separator:SetPoint('TOPLEFT', alltime_label, 'BOTTOMLEFT', 0, -6)
	separator:SetPoint('RIGHT', purchase_summary_frame, 'RIGHT', -8, 0)
	purchase_summary_frame.separator = separator

	-- Column headers
	local header_item = purchase_summary_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	header_item:SetPoint('TOPLEFT', separator, 'BOTTOMLEFT', 0, -4)
	header_item:SetWidth(140)
	header_item:SetJustifyH('LEFT')
	header_item:SetText('Item')
	header_item:SetTextColor(aux.color.label.enabled())
	purchase_summary_frame.header_item = header_item

	local header_count = purchase_summary_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	header_count:SetPoint('LEFT', header_item, 'RIGHT', 2, 0)
	header_count:SetWidth(30)
	header_count:SetJustifyH('RIGHT')
	header_count:SetText('Qty')
	header_count:SetTextColor(aux.color.label.enabled())
	purchase_summary_frame.header_count = header_count

	local header_cost = purchase_summary_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	header_cost:SetPoint('LEFT', header_count, 'RIGHT', 2, 0)
	header_cost:SetWidth(70)
	header_cost:SetJustifyH('RIGHT')
	header_cost:SetText('Price')
	header_cost:SetTextColor(aux.color.label.enabled())
	purchase_summary_frame.header_cost = header_cost

	local header_profit = purchase_summary_frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	header_profit:SetPoint('LEFT', header_cost, 'RIGHT', 2, 0)
	header_profit:SetWidth(70)
	header_profit:SetJustifyH('RIGHT')
	header_profit:SetText('Profit')
	header_profit:SetTextColor(0, 1, 0)
	purchase_summary_frame.header_profit = header_profit

	-- Create scroll frame for item rows (takes remaining vertical space)
	local scroll_frame = CreateFrame('ScrollFrame', 'AuxPurchaseSummaryScroll', purchase_summary_frame)
	scroll_frame:SetPoint('TOPLEFT', header_item, 'BOTTOMLEFT', 0, -2)
	scroll_frame:SetPoint('BOTTOMRIGHT', purchase_summary_frame, 'BOTTOMRIGHT', -8, 8)
	scroll_frame:EnableMouseWheel(true)
	scroll_frame:SetScript('OnMouseWheel', function()
		local scroll_child = this:GetScrollChild()
		if not scroll_child then return end
		local current = this:GetVerticalScroll()
		local max_scroll = math.max(0, scroll_child:GetHeight() - this:GetHeight())
		local new_scroll = current - (arg1 * ROW_HEIGHT * 2)  -- Scroll 2 rows at a time
		new_scroll = math.max(0, math.min(new_scroll, max_scroll))
		this:SetVerticalScroll(new_scroll)
	end)
	purchase_summary_frame.scroll_frame = scroll_frame

	-- Create scroll child (content frame)
	local scroll_child = CreateFrame('Frame', nil, scroll_frame)
	scroll_child:SetWidth(PANEL_WIDTH - 16)
	scroll_child:SetHeight(1)  -- Will be resized dynamically
	scroll_frame:SetScrollChild(scroll_child)
	purchase_summary_frame.scroll_child = scroll_child

	-- Storage for row frames
	purchase_summary_frame.rows = {}
	purchase_summary_frame.scroll_offset = 0
	return purchase_summary_frame
end

function M.update_display()
	local frame = create_purchase_summary_frame()
	
	-- Frame couldn't be created (aux.frame doesn't exist yet)
	if not frame then return end

	-- Check if purchase summary is disabled
	if not aux.account_data or not aux.account_data.purchase_summary then
		frame:Hide()
		return
	end

	if not purchase_summaries or aux.size(purchase_summaries) == 0 then
		frame:Hide()
		return
	end

	-- Calculate session totals across all purchases
	local total_spent = 0
	local total_vendor = 0
	for item_name, summary in purchase_summaries do
		total_spent = total_spent + (summary.total_cost or 0)
		total_vendor = total_vendor + (summary.total_vendor_value or 0)
	end
	local session_profit = total_vendor - total_spent

	-- Session gold/hour (shown above the session label)
	local session_gph = get_session_gold_per_hour()
	local session_gph_gold = math.floor(session_gph / 10000)
	frame.session_gph_text:SetText('Session Rate: ' .. session_gph_gold .. 'g/h')
	frame.session_gph_text:Show()

	-- Update session profit display
	if session_profit ~= 0 then
		local profit_string = money.to_string(math.abs(session_profit), nil, true)
		if session_profit > 0 then
			frame.session_profit_text:SetText('+' .. profit_string)
			frame.session_profit_text:SetTextColor(0, 1, 0) -- Green
		else
			frame.session_profit_text:SetText('-' .. profit_string)
			frame.session_profit_text:SetTextColor(1, 0, 0) -- Red
		end
	else
		frame.session_profit_text:SetText('+0')
	end
	frame.session_profit_text:Show()

	-- Update all-time profit display
	local alltime_spent, alltime_vendor = get_alltime_profit()
	local alltime_profit = alltime_vendor - alltime_spent
	if alltime_profit ~= 0 then
		local alltime_string = money.to_string(math.abs(alltime_profit), nil, true)
		if alltime_profit > 0 then
			frame.alltime_profit_text:SetText('+' .. alltime_string)
			frame.alltime_profit_text:SetTextColor(1, 0.82, 0) -- Gold
		else
			frame.alltime_profit_text:SetText('-' .. alltime_string)
			frame.alltime_profit_text:SetTextColor(1, 0, 0) -- Red
		end
	else
		frame.alltime_profit_text:SetText('+0')
		frame.alltime_profit_text:SetTextColor(1, 0.82, 0) -- Gold
	end
	frame.alltime_profit_text:Show()

	-- All-time gold/hour (shown above the all-time label)
	local alltime_gph = get_gold_per_hour()
	local gph_gold = math.floor(alltime_gph / 10000)
	frame.alltime_gph_text:SetText('All-Time Rate: ' .. gph_gold .. 'g/h')
	frame.alltime_gph_text:Show()

	-- Clear existing row frames
	for _, row in frame.rows do
		row:Hide()
	end

	-- Get scroll child for row placement
	local scroll_child = frame.scroll_child

	-- Create rows for each item
	local row_count = 0
	for item_name, summary in purchase_summaries do
		row_count = row_count + 1

		-- Create new row frame if needed (parent is scroll_child now)
		if not frame.rows[row_count] then
			local row = CreateFrame('Frame', nil, scroll_child)
			row:SetHeight(ROW_HEIGHT)
			row:SetWidth(PANEL_WIDTH - 16)

			-- Item name column - use a Button for hover/click support
			local item_button = CreateFrame('Button', nil, row)
			item_button:SetPoint('TOPLEFT', row, 'TOPLEFT', 0, 0)
			item_button:SetWidth(140)
			item_button:SetHeight(ROW_HEIGHT)
			
			local item_text = item_button:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
			item_text:SetPoint('LEFT', item_button, 'LEFT', 0, 0)
			item_text:SetWidth(140)
			item_text:SetJustifyH('LEFT')
			item_text:SetTextColor(aux.color.text.enabled())
			item_button.text = item_text
			
			-- Hover handlers for item tooltip
			item_button:SetScript('OnEnter', function()
				local item_id = this:GetParent().item_id
				if item_id then
					GameTooltip:SetOwner(this, 'ANCHOR_RIGHT')
					GameTooltip:SetHyperlink('item:' .. item_id)
					GameTooltip:Show()
				end
			end)
			item_button:SetScript('OnLeave', function()
				GameTooltip:Hide()
			end)
			
			row.item_button = item_button
			row.item_text = item_text

			-- Count column
			local count_text = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
			count_text:SetPoint('TOPLEFT', row, 'TOPLEFT', 142, 0)
			count_text:SetWidth(30)
			count_text:SetJustifyH('RIGHT')
			count_text:SetTextColor(aux.color.text.enabled())
			row.count_text = count_text

			-- Cost/Price column
			local cost_text = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
			cost_text:SetPoint('TOPLEFT', row, 'TOPLEFT', 174, 0)
			cost_text:SetWidth(70)
			cost_text:SetJustifyH('RIGHT')
			cost_text:SetTextColor(aux.color.text.enabled())
			row.cost_text = cost_text

			-- Profit column
			local profit_text = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
			profit_text:SetPoint('TOPLEFT', row, 'TOPLEFT', 246, 0)
			profit_text:SetWidth(70)
			profit_text:SetJustifyH('RIGHT')
			row.profit_text = profit_text
			frame.rows[row_count] = row
		end

		local row = frame.rows[row_count]

		-- Position the row relative to scroll_child top
		row:ClearAllPoints()
		row:SetPoint('TOPLEFT', scroll_child, 'TOPLEFT', 0, -((row_count - 1) * ROW_HEIGHT))

		-- Store item_id on the row for tooltip
		row.item_id = summary.item_id

		-- Set item name (no truncation - let FontString clip naturally)
		row.item_text:SetText(item_name)
		row.count_text:SetText(summary.total_quantity .. 'x')

		-- Calculate and display cost/price for this item
		local cost = summary.total_cost or 0
		local cost_string
		if cost >= 10000 then
			local rounded_cost = aux.round(cost / 100) * 100
			cost_string = money.to_string(rounded_cost, nil, true)
		else
			cost_string = money.to_string(cost, nil, true)
		end
		row.cost_text:SetText(cost_string)

		-- Calculate and display profit for this item
		local vendor_value = summary.total_vendor_value or 0
		local item_profit = vendor_value - cost
		if vendor_value > 0 then
			local profit_string
			if math.abs(item_profit) >= 10000 then
				local rounded_profit = aux.round(math.abs(item_profit) / 100) * 100
				profit_string = money.to_string(rounded_profit, nil, true)
			else
				profit_string = money.to_string(math.abs(item_profit), nil, true)
			end
			if item_profit >= 0 then
				row.profit_text:SetText('+' .. profit_string)
				row.profit_text:SetTextColor(0, 1, 0) -- Green
			else
				row.profit_text:SetText('-' .. profit_string)
				row.profit_text:SetTextColor(1, 0, 0) -- Red
			end
		else
			row.profit_text:SetText('?')
			row.profit_text:SetTextColor(0.5, 0.5, 0.5) -- Gray for unknown vendor price
		end

		row:Show()
	end

	-- Update scroll child height to fit all rows
	local total_content_height = row_count * ROW_HEIGHT
	frame.scroll_child:SetHeight(math.max(1, total_content_height))

	-- Reset scroll position when content changes significantly
	if row_count <= 1 then
		frame.scroll_frame:SetVerticalScroll(0)
	end

	-- Ensure scroll components are visible
	frame.scroll_frame:Show()
	frame.scroll_child:Show()

	-- Make sure frame is visible and properly positioned
	if aux.frame and aux.frame:IsShown() then
		frame:Show()
	end
end

function M.hide()
	if purchase_summary_frame then
		purchase_summary_frame:Hide()
	end
end

-- Set up handlers - use direct function references instead of M.
function aux.handle.CLOSE()
	if purchase_summary_frame then
		purchase_summary_frame:Hide()
	end
	T.wipe(purchase_summaries)
end