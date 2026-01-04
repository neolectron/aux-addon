# Aux Addon Modifications - Development Log

This document tracks all modifications made to the aux-addon for Turtle WoW (Vanilla 1.12.1). It's intended for future LLM agents and developers to understand the codebase structure, patterns, and customizations.

## Project Context

**Game Version**: Turtle WoW - Vanilla 1.12.1  
**Addon**: aux-addon (OldManAlpha fork, auxfix branch)  
**UI Theme**: Blizzard skin (default)  
**Primary Goal**: Add crafting profitability analysis tools

## Understanding the Aux Module System

### Module Declaration Pattern

```lua
module 'aux.tabs.craft'  -- Declares module namespace

local T = require 'T'
local aux = require 'aux'
-- ... other requires

-- Module-level variables (shared across files with same module declaration)
scan_id = 0
scanning = false

-- Exported function via M. prefix (if needed)
function M.exported_function()
end

-- Local function (not exported)
local function helper()
end
```

**CRITICAL**: Variables declared without `local` in a module are **module-level** and shared across all files that declare the same `module`. This is different from standard Lua modules.

### Module-Level vs M. Exports

When multiple files share the same `module` declaration:

- Variables without `local` are **shared module state**
- Functions prefixed with `M.` are **exported** to other modules
- Plain functions (no M.) are **internal to the module but shared across files**

Example from our implementation:

```lua
-- In craft_vendor.lua
material_to_recipes = {}  -- Module-level, accessible from craft/core.lua
safe_materials = {}       -- Module-level, accessible from craft/core.lua

function M.is_safe_material(item_id)  -- Exported to other modules
    return safe_materials[item_id]
end
```

## Feature Additions

### 1. Craft-Safe Filter (`/craft-safe`)

**Location**: `aux-addon/core/filter.lua` (lines ~520-534)

**Purpose**: Identifies materials that are "safe" to buy because they're only used in one recipe (won't decrease profitability of other recipes).

**Implementation**:

```lua
do
    local filter = T.map(
        'title', 'craft-safe',
        'validator', T.set{''}
    )
    function filter.refine(self, search)
        return T.map('predicate', function(auction_record)
            local item_id = auction_record.item_id
            return craft_vendor.is_safe_material(item_id)
        end)
    end
    tinsert(M.filter_specs, filter)
end
```

**Usage**: Add `/craft-safe` to any search filter to only show materials that are safe to buy in bulk.

### 2. New "Craft" Tab

**Files Created**:

- `aux-addon/tabs/craft/core.lua` - Tab logic, scanning, profit calculations
- `aux-addon/tabs/craft/frame.lua` - UI layout and controls

**Added to**: `aux-addon/aux-addon.toc` (lines added at end)

#### Tab Structure

**Left Panel**: Recipe list

- Shows all craftable recipes with vendor value
- Green text = "safe" recipes (materials only used in this recipe)
- Click to scan materials

**Top Bar**: Search controls (matching Search tab)

- Filter text box with auto-complete
- Range: page inputs (1-5, etc.) / Real Time toggle
- Search / Resume / Stop buttons

**Right Panel - Top**: Material costs

- Qty | Material | Price | Cost | Avail
- Shows current AH prices for materials
- Red text = not found on AH

**Right Panel - Middle**: Profit summary

- Vendor: total vendor value of crafted item(s)
- Cost: total cost of materials from AH
- Profit: vendor - cost (green if positive, red if negative)

**Right Panel - Bottom**: Auction results

- Standard aux auction listing
- Alt+Click to buy
- Right-click to search in Search tab

**Bottom Bar**: Status bar and Bid/Buyout buttons (matching Search tab pattern)

### 3. Recipe Database Enhancement

**Location**: `aux-addon/core/craft_vendor.lua`

**Key Changes**:

- Changed `M.material_to_recipes` → `material_to_recipes` (module-level variable)
- Changed `M.safe_materials` → `safe_materials` (module-level variable)
- Moved `build_material_index()` initialization to `aux.handle.LOAD()` event

**Why**: The module system requires these to be module-level (not M. prefixed) to be accessible from `tabs/craft/core.lua` which shares the same module namespace indirectly through requires.

## Code Patterns & Best Practices

### 1. Event Handlers

Aux uses specific event handlers for initialization:

- `aux.handle.LOAD()` - Called once when addon loads (use for data initialization)
- `aux.handle.LOAD2()` - Called after LOAD (use for secondary init)
- `aux.handle.INIT_UI()` - Called to create UI frames (use for frame creation)

### 2. Tab Registration

```lua
local tab = aux.tab 'TabName'

function tab.OPEN()
    frame:Show()
    -- Initialize tab state
end

function tab.CLOSE()
    frame:Hide()
    -- Cleanup, abort scans, etc.
end
```

### 3. GUI Components

**Panels**:

```lua
local panel = gui.panel(parent)
panel:SetWidth(280)
panel:SetHeight(180)
panel:SetPoint('TOPLEFT', ...)
```

**Listings** (simple scrollable lists):

```lua
local listing = listing.new(parent_panel)
listing:SetColInfo{
    {name='Column1', width=.50, align='LEFT'},
    {name='Column2', width=.50, align='RIGHT'},
}
-- Listings auto-fill parent, don't call SetPoint
```

**Auction Listings** (with aux-specific columns):

```lua
local auction_listing = auction_listing.new(parent, num_rows, auction_listing.search_columns)
auction_listing:SetDatabase(auction_records_array)
```

**Buttons**:

```lua
local btn = gui.button(parent, font_size)
btn:SetPoint('TOPLEFT', ...)
btn:SetText('Label')
btn:SetScript('OnClick', function() ... end)
```

**Edit Boxes**:

```lua
local editbox = gui.editbox(parent)
editbox:SetPoint('LEFT', ...)
editbox.enter = function() ... end  -- Called on Enter key
editbox.change = function() ... end -- Called when text changes
```

### 4. Scanning Pattern

```lua
scan_id = scan.start{
    type = 'list',  -- or 'query'
    queries = filter_util.queries(filter_string),
    start_page = 1,
    end_page = 5,  -- optional
    continuation = saved_continuation,  -- for resume
    on_page_loaded = function(page, total_pages)
        -- Update progress
    end,
    on_auction = function(auction_record)
        -- Process each auction
        tinsert(results, auction_record)
    end,
    on_complete = function()
        -- Scan finished
        scanning = false
    end,
    on_abort = function(continuation)
        -- Scan stopped (continuation = state for resume)
        scanning = false
    end,
}

-- To stop: scan.abort(scan_id)
```

### 5. Filter System

Filters use `/` separators and are case-insensitive:

- `iron ore/exact` - exact item name match
- `iron;copper` - multiple items (semicolon separator)
- `for-craft/recipe name/craft-profit/1c` - materials for recipe with min profit
- `usable/armor/cloth` - usable cloth armor
- `/left/min-profit/10g` - items with tooltip "Equip: ..." and 10g+ profit

Filter specs in `core/filter.lua` define custom filters via:

```lua
local filter = T.map(
    'title', 'filter-name',
    'validator', T.set{'param1', 'param2'}  -- valid parameters
)
function filter.refine(self, search)
    return T.map('predicate', function(auction_record)
        return true_or_false  -- Include auction or not
    end)
end
```

## File Structure

```
aux-addon/
├── core/
│   ├── filter.lua          # Filter system, added /craft-safe
│   ├── craft_vendor.lua    # Recipe database, material safety checks
│   └── scan.lua            # AH scanning engine
├── tabs/
│   ├── search/             # Search tab (reference for patterns)
│   │   ├── core.lua
│   │   ├── frame.lua
│   │   └── results.lua
│   └── craft/              # NEW - Craft tab
│       ├── core.lua        # Logic, scanning, profit calculations
│       └── frame.lua       # UI layout
├── gui/
│   ├── core.lua            # GUI utilities (panel, button, label, etc.)
│   ├── listing.lua         # Simple scrollable list widget
│   └── auction_listing.lua # Auction-specific listing widget
└── aux-addon.toc           # Addon manifest (added craft files)
```

## Known Issues & Limitations

1. **Material Listing Scrollbar**: Hidden to avoid Blizzard skin overlap. If a recipe has >10 materials, they won't all be visible. (No known recipes exceed this.)

2. **Profit Calculation**: Uses minimum buyout price from AH. Doesn't account for:

   - AH fees (5% deposit, potential loss if doesn't sell)
   - Time value (materials may be cheaper later)
   - Competition (other players buying same materials)

3. **Real-Time Mode**: Not yet implemented in Craft tab. Range mode works (scans specified pages).

4. **Saved Searches**: Craft tab doesn't save search history like Search tab does.

## Future Improvements

### High Priority

1. **Historical Price Data**: Track material prices over time to identify trends
2. **Bulk Buying**: Add "Buy All Materials" button with quantity validation
3. **Recipe Filtering**: Filter recipes by profession, level, profit threshold
4. **Material Availability Alert**: Notify when all materials for a recipe are available below threshold

### Medium Priority

1. **Real-Time Scanning**: Implement continuous scanning mode
2. **Search History**: Save and restore craft searches
3. **Multi-Recipe View**: Show profit for multiple recipes simultaneously
4. **Export Data**: Export recipe profitability to CSV/text

### Low Priority

1. **Crafting Queue**: Build a queue of profitable recipes to craft
2. **Material Sourcing**: Show alternative sources (farming, vendors, quests)
3. **Guild Integration**: Share profitable recipes with guild
4. **Market Analysis**: Identify market trends and opportunities

## Technical Debt

1. **Code Duplication**: `execute_search()` in craft/core.lua duplicates logic from search/results.lua. Could refactor to shared module.

2. **Magic Numbers**: Panel sizes (180, 280, etc.) are hardcoded. Should use constants or calculate from aux.frame dimensions.

3. **Global State**: `scan_id`, `scanning`, etc. are module-level globals. Could encapsulate in state object.

4. **Error Handling**: Minimal error handling for edge cases (invalid filters, AH disconnects, etc.)

5. **Documentation**: No in-code documentation for complex functions like `calculate_recipe_profit()`.

## API Reference

### craft_vendor Module

```lua
-- Check if material is safe to buy (only used in one recipe)
craft_vendor.is_safe_material(item_id) -> boolean

-- Get recipe database
craft_vendor.recipes[recipe_name] = {
    name = "Recipe Name",
    item_id = 12345,
    vendor_price = 5000,  -- copper
    output_quantity = 1,
    materials = {
        {item_id = 2318, name = "Light Leather", quantity = 4},
        ...
    }
}
```

### Craft Tab Functions (internal)

```lua
-- Execute search from search box
execute_search(resume) -> nil

-- Scan materials for a recipe
scan_recipe_materials(recipe_name) -> nil

-- Calculate profit for a recipe
calculate_recipe_profit(recipe) -> {
    vendor_value = number,
    total_cost = number,
    profit = number or nil,
    all_found = boolean,
    materials = { ... }
}

-- Update UI displays
update_recipe_listing() -> nil
update_material_listing() -> nil
update_search_display() -> nil
```

## Debugging Tips

1. **Enable Lua Errors**: Use `/console scriptErrors 1` or install BugSack addon

2. **Module Variables**: To check module-level variables, add debug prints:

   ```lua
   DEFAULT_CHAT_FRAME:AddMessage("Debug: " .. tostring(variable_name))
   ```

3. **Scan States**: Monitor `scanning` and `scan_id` to debug scan lifecycle

4. **Filter Parsing**: Test filters in Search tab first to verify syntax

5. **Frame Anchoring**: Use `/framestack` command to visualize frame hierarchy

## Change Log

**2026-01-04**: Initial Craft tab implementation

- Added `/craft-safe` filter to filter.lua
- Created tabs/craft/core.lua and tabs/craft/frame.lua
- Modified core/craft_vendor.lua for module-level variables
- Fixed scrollbar overlap issue on Blizzard skin
- Added search controls matching Search tab
- Documented all changes in this README

---

**Last Updated**: 2026-01-04  
**Maintainer**: neolectron (via LLM)  
**Version**: 1.0.0
