module 'aux.core.scan'

local T = require 'T'
local aux = require 'aux'
local info = require 'aux.util.info'
local history = require 'aux.core.history'
local money = require 'aux.util.money'

local PAGE_SIZE = 50

function aux.handle.CLOSE()
	abort()
end

do
	local scan_states = {}

	function M.start(params)
		local old_state = scan_states[params.type]
		if old_state then
			abort(old_state.id)
		end
		do (params.on_scan_start or pass)() end
		local thread_id = aux.thread(scan)
		scan_states[params.type] = {
			id = thread_id,
			params = params,
		}
		return thread_id
	end

	function M.abort(scan_id)
		local aborted = T.acquire()
		for type, state in scan_states do
			if not scan_id or state.id == scan_id then
				aux.kill_thread(state.id)
				scan_states[type] = nil
				tinsert(aborted, state)
			end
		end
		for _, state in aborted do
			do (state.params.on_abort or pass)() end
		end
	end

	function M.stop()
		get_state().stopped = true
	end

	function complete()
		local on_complete = get_state().params.on_complete
		scan_states[get_state().params.type] = nil
		do (on_complete or pass)() end
	end

	function get_state()
		for _, state in scan_states do
			if state.id == aux.thread_id() then
				return state
			end
		end
	end
end

function get_query()
	return get_state().params.queries[get_state().query_index]
end

function total_pages(total_auctions)
    return ceil(total_auctions / PAGE_SIZE)
end

function last_page(total_auctions)
    local last_page = max(total_pages(total_auctions) - 1, 0)
    local last_page_limit = get_query().blizzard_query.last_page or last_page
    return min(last_page_limit, last_page)
end

function scan()
	get_state().query_index = get_state().query_index and get_state().query_index + 1 or 1
	if get_query() and not get_state().stopped then
		do (get_state().params.on_start_query or pass)(get_state().query_index) end
		if get_query().blizzard_query then
			if (get_query().blizzard_query.first_page or 0) <= (get_query().blizzard_query.last_page or aux.huge) then
				-- Support reverse scanning
				if get_state().params.reverse and not get_state().reverse_initialized then
					-- Start at page 0 to get total auctions, will switch to last page after
					get_state().page = 0
					get_state().reverse_initialized = true
					get_state().finding_last_page = true
				else
					get_state().page = get_query().blizzard_query.first_page or 0
				end
				return submit_query()
			end
		else
			get_state().page = nil
			return scan_page()
		end
	end
	return complete()
end

do
	local function submit()
		if get_state().params.type == 'bidder' then
			GetBidderAuctionItems(get_state().page)
		elseif get_state().params.type == 'owner' then
			GetOwnerAuctionItems(get_state().page)
		else
			get_state().last_list_query = GetTime()
			local blizzard_query = get_query().blizzard_query or T.acquire()
			QueryAuctionItems(
				blizzard_query.name,
				blizzard_query.min_level,
				blizzard_query.max_level,
				blizzard_query.slot,
				blizzard_query.class,
				blizzard_query.subclass,
				get_state().page,
				blizzard_query.usable,
				blizzard_query.quality
			)
		end
		return wait_for_results()
	end
	function submit_query()
		if get_state().stopped then return end
		if get_state().params.type ~= 'list' then
			return submit()
		else
			return aux.when(CanSendAuctionQuery, submit)
		end
	end
end

function scan_page(i)
	i = i or 1
	local pages

	if i > PAGE_SIZE then
		do (get_state().params.on_page_scanned or pass)() end
		if get_query().blizzard_query then
			local last = last_page(get_state().total_auctions)
			local first = get_query().blizzard_query.first_page or 0
			
			if get_state().params.reverse then
				-- Reverse: go from last page to first
				if get_state().page > first then
					get_state().page = get_state().page - 1
					return submit_query()
				else
					return scan()
				end
			else
				-- Normal: go from first to last
				if get_state().page < last then
					get_state().page = get_state().page + 1
					return submit_query()
				else
					return scan()
				end
			end
		else
			return scan()
		end
	end

	local auction_info = info.auction(i, get_state().params.type)
	if auction_info and (auction_info.owner or get_state().params.ignore_owner or aux.account_data.ignore_owner) then
		auction_info.index = i
		auction_info.page = get_state().page
		auction_info.blizzard_query = get_query().blizzard_query
		auction_info.query_type = get_state().params.type
		if get_query().blizzard_query and get_state().page then
			pages = last_page(get_state().total_auctions)
		end
		
		history.process_auction(auction_info, pages)
		
		-- Use centralized vendor price helper
		

-- Check if buying at a specific price would be vendor-profitable
local function is_vendor_profitable(record, price)
    if not price or price <= 0 then return false end
    local vendor_price = info.get_vendor_price(record.item_id, record.aux_quantity)
    if vendor_price and vendor_price > 0 then
        return vendor_price * record.aux_quantity - price >= 0
    end
    -- If no vendor price known, allow (other filters may apply)
    return true
end
		
		-- Auto-buy logic: buy at buyout if profitable, else try bid if profitable
		if (get_state().params.auto_buy_validator or pass)(auction_info) and auction_info.owner ~= UnitName("player") then
			local buyout_profitable = auction_info.buyout_price > 0 and is_vendor_profitable(auction_info, auction_info.buyout_price)
			local bid_profitable = auction_info.high_bidder == nil and is_vendor_profitable(auction_info, auction_info.bid_price)
			
			if buyout_profitable then
				-- Buyout is profitable - instant buy
				local success, reason = aux.place_bid(auction_info.query_type, auction_info.index, auction_info.buyout_price, pass, true)
				if success then
					PlaySound("LEVELUP")
					aux.print(aux.color.green("AUTO-BUY: ") .. (auction_info.name or "item") .. " for " .. money.to_string(auction_info.buyout_price, true))
				elseif reason == 'gold' then
					aux.print(aux.color.red("AUTO-BUY SKIPPED (not enough gold): ") .. (auction_info.name or "item"))
				end
			elseif bid_profitable then
				-- Buyout not profitable, but bid is - place bid instead
				local success, reason = aux.place_bid(auction_info.query_type, auction_info.index, auction_info.bid_price, pass, false)
				if success then
					PlaySound("igQuestListOpen")
					aux.print(aux.color.blue("AUTO-BID (buyout unprofitable): ") .. (auction_info.name or "item") .. " for " .. money.to_string(auction_info.bid_price, true))
				elseif reason == 'gold' then
					aux.print(aux.color.red("AUTO-BID SKIPPED (not enough gold): ") .. (auction_info.name or "item"))
				end
			end
			-- If neither profitable, skip silently
		elseif (get_state().params.auto_bid_validator or pass)(auction_info) and auction_info.owner ~= UnitName("player") and auction_info.high_bidder == nil then
			-- Instant bid: place bid and continue scanning immediately (don't wait)
			local success, reason = aux.place_bid(auction_info.query_type, auction_info.index, auction_info.bid_price, pass, false)
			if success then
				-- Play alert sound for auto-bid deal found
				PlaySound("igQuestListOpen")
				aux.print(aux.color.blue("AUTO-BID: ") .. (auction_info.name or "item") .. " for " .. money.to_string(auction_info.bid_price, true))
			elseif reason == 'gold' then
				aux.print(aux.color.red("AUTO-BID SKIPPED (not enough gold): ") .. (auction_info.name or "item"))
			end
		elseif not get_query().validator or get_query().validator(auction_info) then
			do (get_state().params.on_auction or pass)(auction_info) end
		end
	end

	return scan_page(i + 1)
end

function wait_for_results()
    if get_state().params.type == 'bidder' then
        return aux.when(function() return aux.bids_loaded() end, accept_results)
    elseif get_state().params.type == 'owner' then
        return wait_for_owner_results()
    elseif get_state().params.type == 'list' then
        return wait_for_list_results()
    end
end

function accept_results()
	_,  get_state().total_auctions = GetNumAuctionItems(get_state().params.type)
	
	-- Handle reverse scan: after first query, jump to last page
	if get_state().finding_last_page then
		get_state().finding_last_page = false
		local last = last_page(get_state().total_auctions)
		get_state().page = last
		return submit_query()
	end
	
	do
		local current, total_display
		if get_state().params.reverse then
			-- Reverse: show countdown
			local last = last_page(get_state().total_auctions)
			local first = get_query().blizzard_query.first_page or 0
			current = last - get_state().page + 1
			total_display = last - first + 1
		else
			current = get_state().page - (get_query().blizzard_query.first_page or 0) + 1
			total_display = last_page(get_state().total_auctions) - (get_query().blizzard_query.first_page or 0) + 1
		end
		(get_state().params.on_page_loaded or pass)(
			current,
			total_display,
			total_pages(get_state().total_auctions) - 1,
			get_state().page + 1  -- actual AH page number (1-based for display)
		)
	end
	return scan_page()
end

function wait_for_owner_results()
    if get_state().page == aux.current_owner_page() then
	    return accept_results()
    else
	    local updated
        aux.on_next_event('AUCTION_OWNED_LIST_UPDATE', function() updated = true end)
	    return aux.when(function() return updated end, accept_results)
    end
end

function wait_for_list_results()
    local updated, last_update
    local listener_id = aux.event_listener('AUCTION_ITEM_LIST_UPDATE', function()
        last_update = GetTime()
        updated = true
    end)
    local timeout = aux.later(5, get_state().last_list_query)
    local ignore_owner = get_state().params.ignore_owner or aux.account_data.ignore_owner
	return aux.when(function()
		if not last_update and timeout() then
			return true
		end
		if last_update and GetTime() - last_update > 5 then
			return true
		end
		-- short circuiting order important, owner_data_complete must be called iif an update has happened.
		if updated and (ignore_owner or owner_data_complete()) then
			return true
		end
		updated = false
	end, function()
		aux.kill_listener(listener_id)
		if not last_update and timeout() then
			return submit_query()
		else
			return accept_results()
		end
	end)
end

function owner_data_complete()
    for i = 1, PAGE_SIZE do
        local auction_info = info.auction(i, 'list')
        if auction_info and not auction_info.owner then
	        return false
        end
    end
    return true
end