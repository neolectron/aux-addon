module 'aux.core.search_cache'

-- Search cache module for stale-while-revalidate pattern
-- This module stores search results for fast retrieval on subsequent searches

local T = require 'T'

-- Debug: confirm module is loading
DEFAULT_CHAT_FRAME:AddMessage('[SearchCache] Module file executing...')

-- Cache configuration
local CACHE_TTL = 30 * 60  -- 30 minutes default TTL
local MAX_CACHE_ENTRIES = 50  -- Maximum number of cached searches

-- Get aux reference lazily (avoid require at module load time)
local function get_aux()
    return require 'aux'
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
    
    -- Count entries
    local entries = {}
    for key, data in pairs(cache) do
        tinsert(entries, {key = key, timestamp = data.timestamp})
    end
    
    -- If under limit, no pruning needed
    if getn(entries) <= MAX_CACHE_ENTRIES then return end
    
    -- Sort by timestamp (oldest first)
    table.sort(entries, function(a, b) return a.timestamp < b.timestamp end)
    
    -- Remove oldest entries until under limit
    local to_remove = getn(entries) - MAX_CACHE_ENTRIES
    for i = 1, to_remove do
        cache[entries[i].key] = nil
    end
    
    aux.print(format('[SearchCache] Pruned %d old entries', to_remove))
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
    if key == '' then return end  -- Don't cache empty searches
    
    -- Serialize minimal auction data (not full records - too large)
    local cached_auctions = {}
    for i, record in ipairs(records) do
        -- Store only essential fields for display
        tinsert(cached_auctions, {
            item_key = record.item_key,
            name = record.name,
            texture = record.texture,
            aux_quantity = record.aux_quantity,
            buyout_price = record.buyout_price,
            unit_buyout_price = record.unit_buyout_price,
            bid_price = record.bid_price,
            unit_bid_price = record.unit_bid_price,
            owner = record.owner,
            duration = record.duration,
            quality = record.quality,
            level = record.level,
            item_id = record.item_id,
            suffix_id = record.suffix_id,
            enchant_id = record.enchant_id,
            unique_id = record.unique_id,
        })
        -- Limit stored auctions per search
        if i >= 500 then break end
    end
    
    -- Store with timestamp
    cache[key] = {
        timestamp = time(),
        count = getn(records),
        auctions = cached_auctions,
    }
    
    -- Prune old entries if cache is too large
    prune()
    
    aux.print(format('[SearchCache] Stored %d auctions for "%s"', getn(cached_auctions), filter_string))
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
