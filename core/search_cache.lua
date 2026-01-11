module 'aux.core.search_cache'

-- Search cache module for stale-while-revalidate pattern
-- This module stores search results for fast retrieval on subsequent searches

local T = require 'T'

-- Cache configuration defaults
local DEFAULT_MAX_ENTRIES = 200
local CACHE_TTL = 30 * 60  -- 30 minutes default TTL

-- Get aux reference lazily (avoid require at module load time)
local function get_aux()
    return require 'aux'
end

-- Get configured max entries (from account_data or default)
local function get_max_entries()
    local aux = get_aux()
    return aux.account_data.search_cache_max_entries or DEFAULT_MAX_ENTRIES
end

-- Lazy initialization - ensures cache exists
local function ensure_cache()
    local aux = get_aux()
    if aux.faction_data and not aux.faction_data.search_cache then
        aux.faction_data.search_cache = {}
    end
    return aux.faction_data and aux.faction_data.search_cache
end

-- Local function definitions (for internal use)

local function normalize_key(filter_string)
    if not filter_string then return '' end
    -- Trim whitespace and lowercase for consistent matching
    local key = strlower(gsub(filter_string or '', '^%s*(.-)%s*$', '%1'))
    return key
end

local function get(filter_string)
    local cache = ensure_cache()
    if not cache then return nil, 0 end
    
    local key = normalize_key(filter_string)
    local cached = cache[key]
    
    if not cached then return nil, 0 end
    
    local age = time() - cached.timestamp
    return cached, age
end

local function get_age_text(filter_string)
    local cached, age = get(filter_string)
    if not cached then return nil end
    
    if age < 60 then
        return format('%ds ago', age)
    elseif age < 3600 then
        return format('%dm ago', math.floor(age / 60))
    else
        return format('%dh ago', math.floor(age / 3600))
    end
end

local function prune()
    local aux = get_aux()
    local cache = ensure_cache()
    if not cache then return end
    
    local max_entries = get_max_entries()
    
    -- Count entries
    local entries = {}
    for key, data in pairs(cache) do
        tinsert(entries, {key = key, timestamp = data.timestamp})
    end
    
    -- If under limit, no pruning needed
    if getn(entries) <= max_entries then return end
    
    -- Sort by timestamp (oldest first)
    table.sort(entries, function(a, b) return a.timestamp < b.timestamp end)
    
    -- Remove oldest entries until under limit
    local to_remove = getn(entries) - max_entries
    for i = 1, to_remove do
        cache[entries[i].key] = nil
    end
end

local function stats()
    local cache = ensure_cache()
    if not cache then 
        return {entries = 0, total_auctions = 0, oldest_age = 0}
    end
    
    local entries_count = 0
    local total_auctions = 0
    local oldest_age = 0
    
    for key, data in pairs(cache) do
        entries_count = entries_count + 1
        total_auctions = total_auctions + (data.count or 0)
        local age = time() - data.timestamp
        if age > oldest_age then oldest_age = age end
    end
    
    return {
        entries = entries_count,
        total_auctions = total_auctions,
        oldest_age = oldest_age,
    }
end

-- Store search results in cache
-- @param filter_string: The search query used
-- @param records: Array of auction records
local function store(filter_string, records)
	local aux = get_aux()
	local cache = ensure_cache()
	if not cache then return end
	if not records or getn(records) == 0 then return end
	
	local key = normalize_key(filter_string)
	if key == '' then return end
	
	local cached_auctions = {}
	for i, record in ipairs(records) do
		local blizzard_query_copy = record.blizzard_query and aux.copy(record.blizzard_query) or nil
		tinsert(cached_auctions, {
			item_key = record.item_key,
			search_signature = record.search_signature,
			item_id = record.item_id,
			suffix_id = record.suffix_id,
			enchant_id = record.enchant_id,
			unique_id = record.unique_id,
			link = record.link,
			itemstring = record.itemstring,
			name = record.name,
			texture = record.texture,
			quality = record.quality,
			level = record.level,
			aux_quantity = record.aux_quantity,
			count = record.count,
			buyout_price = record.buyout_price,
			unit_buyout_price = record.unit_buyout_price,
			bid_price = record.bid_price,
			unit_bid_price = record.unit_bid_price,
			start_price = record.start_price,
			high_bid = record.high_bid,
			high_bidder = record.high_bidder,
			owner = record.owner,
			duration = record.duration,
			query_type = record.query_type,
			blizzard_query = blizzard_query_copy,
			page = record.page,
		})
		if i >= 500 then break end
	end
	
	cache[key] = {
		timestamp = time(),
		count = getn(records),
		auctions = cached_auctions,
	}
	
	prune()
end

local function is_stale(filter_string, ttl)
    ttl = ttl or CACHE_TTL
    local cached, age = get(filter_string)
    if not cached then return true end
    return age > ttl
end

local function clear()
    local aux = get_aux()
    if aux.faction_data then
        aux.faction_data.search_cache = {}
    end
    aux.print('[SearchCache] Cache cleared')
end

local function debug()
    local aux = get_aux()
    local cache = ensure_cache()
    aux.print('[SearchCache] === Cache Contents ===')
    local s = stats()
    aux.print(format('Entries: %d, Total auctions: %d', s.entries, s.total_auctions))
    
    if cache then
        for key, data in pairs(cache) do
            aux.print(format('  "%s": %d auctions, %s', key, data.count or 0, get_age_text(key) or '?'))
        end
    end
end

local function set_limit(limit)
    local aux = get_aux()
    if limit and limit > 0 then
        aux.account_data.search_cache_max_entries = limit
        aux.print(format('[SearchCache] Max entries set to %d', limit))
        -- Prune immediately if over new limit
        prune()
    else
        aux.print(format('[SearchCache] Current limit: %d searches', get_max_entries()))
    end
end

-- Export functions to module interface
M.normalize_key = normalize_key
M.store = store
M.get = get
M.is_stale = is_stale
M.get_age_text = get_age_text
M.prune = prune
M.clear = clear
M.stats = stats
M.debug = debug
M.set_limit = set_limit
M.get_limit = get_max_entries
