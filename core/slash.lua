module 'aux.core.slash'

local T = require 'T'
local aux = require 'aux'
local info = require 'aux.util.info'
local post = require 'aux.tabs.post'
local purchase_summary = require 'aux.util.purchase_summary'
local craft_vendor = require 'aux.core.craft_vendor'

function status(enabled)
	return (enabled and aux.color.green'on' or aux.color.red'off')
end

function warn_reload()
    aux.print(aux.color.orange('A relog or reload is required for this change to take effect.'))
end

_G.SLASH_AUX1 = '/aux'
function SlashCmdList.AUX(command)
	if not command then return end
	local arguments = aux.tokenize(command)
    local tooltip_settings = aux.character_data.tooltip
    if arguments[1] == 'scale' and tonumber(arguments[2]) then
    	local scale = tonumber(arguments[2])
	    aux.frame:SetScale(scale)
	    aux.account_data.scale = scale
    elseif arguments[1] == 'uc' then
        aux.account_data.undercut = not aux.account_data.undercut
	    aux.print('undercutting ' .. status(aux.account_data.undercut))
    elseif arguments[1] == 'ignore' and arguments[2] == 'owner' then
	    aux.account_data.ignore_owner = not aux.account_data.ignore_owner
        aux.print('ignore owner ' .. status(aux.account_data.ignore_owner))
	elseif arguments[1] == 'post' and arguments[2] == 'stack' then
        aux.account_data.post_stack = not aux.account_data.post_stack
	    aux.print('post stack ' .. status(aux.account_data.post_stack))
    elseif arguments[1] == 'post' and arguments[2] == 'bid' then
        aux.account_data.post_bid = not aux.account_data.post_bid
	    aux.print('post bid ' .. status(aux.account_data.post_bid))
        warn_reload()
    elseif arguments[1] == 'post' and arguments[2] == 'duration' and  T.map('6', post.DURATION_2, '24', post.DURATION_8, '72', post.DURATION_24)[arguments[3]] then
        aux.account_data.post_duration = T.map('6', post.DURATION_2, '24', post.DURATION_8, '72', post.DURATION_24)[arguments[3]]
        aux.print('post duration ' .. aux.color.blue(aux.account_data.post_duration / 60 * 3 .. 'h'))
    elseif arguments[1] == 'crafting' and arguments[2] == 'cost' then
		aux.account_data.crafting_cost = not aux.account_data.crafting_cost
		aux.print('crafting cost ' .. status(aux.account_data.crafting_cost))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'value' then
	    tooltip_settings.value = not tooltip_settings.value
        aux.print('tooltip value ' .. status(tooltip_settings.value))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'daily' then
	    tooltip_settings.daily = not tooltip_settings.daily
        aux.print('tooltip daily ' .. status(tooltip_settings.daily))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'merchant' and arguments[3] == 'buy' then
	    tooltip_settings.merchant_buy = not tooltip_settings.merchant_buy
        aux.print('tooltip merchant buy ' .. status(tooltip_settings.merchant_buy))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'merchant' and arguments[3] == 'sell' then
	    tooltip_settings.merchant_sell = not tooltip_settings.merchant_sell
        aux.print('tooltip merchant sell ' .. status(tooltip_settings.merchant_sell))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'value' then
	    tooltip_settings.disenchant_value = not tooltip_settings.disenchant_value
        aux.print('tooltip disenchant value ' .. status(tooltip_settings.disenchant_value))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'distribution' then
	    tooltip_settings.disenchant_distribution = not tooltip_settings.disenchant_distribution
        aux.print('tooltip disenchant distribution ' .. status(tooltip_settings.disenchant_distribution))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'wowauctions' then
	    tooltip_settings.wowauctions = not tooltip_settings.wowauctions
        aux.print('tooltip wowauctions ' .. status(tooltip_settings.wowauctions))
    elseif arguments[1] == 'clear' and arguments[2] == 'item' and arguments[3] == 'cache' then
	    aux.account_data.items = {}
        aux.account_data.item_ids = {}
        aux.account_data.auctionable_items = {}
        aux.print('Item cache cleared.')
    elseif arguments[1] == 'populate' and arguments[2] == 'wdb' then
	    info.populate_wdb()
	elseif arguments[1] == 'sharing' then
		aux.account_data.sharing = not aux.account_data.sharing
		aux.print('sharing ' .. status(aux.account_data.sharing))
    elseif arguments[1] == 'theme' and (arguments[2] == nil or (arguments[2] == 'modern' or arguments[2] == 'blizzard')) then
        aux.account_data.theme = arguments[2] or (aux.account_data.theme == 'blizzard' and 'modern' or 'blizzard')
        aux.print('theme ' .. aux.color.blue(aux.account_data.theme))
        warn_reload()
	elseif arguments[1] == 'show' and arguments[2] == 'hidden' then
		aux.account_data.showhidden = not aux.account_data.showhidden
		aux.print('show hidden ' .. status(aux.account_data.showhidden))
	elseif arguments[1] == 'purchase' and arguments[2] == 'summary' then
		aux.account_data.purchase_summary = not aux.account_data.purchase_summary
		aux.print('purchase summary ' .. status(aux.account_data.purchase_summary))
		-- Hide the frame if disabled
		if not aux.account_data.purchase_summary then
			purchase_summary.hide()
		end
	elseif arguments[1] == 'reset' and arguments[2] == 'profit' then
		purchase_summary.reset_alltime_profit()
		aux.print('All-time profit tracking has been reset.')
	elseif arguments[1] == 'top' then
		local limit = tonumber(arguments[2]) or 10
		purchase_summary.print_top_items(limit)
	elseif arguments[1] == 'wowauction' or arguments[1] == 'wa' then
		-- Build item name from remaining arguments
		local item_name = ''
		for i = 2, getn(arguments) do
			if i > 2 then item_name = item_name .. ' ' end
			item_name = item_name .. arguments[i]
		end
		if item_name == '' then
			aux.print('Usage: /aux wowauction <item name>')
			aux.print('Example: /aux wowauction Silk Cloth')
		else
			-- Try to find item ID from name
			local item_id = nil
			for id = 1, 30000 do
				local name = GetItemInfo(id)
				if name and strlower(name) == strlower(item_name) then
					item_id = id
					break
				end
			end
			-- Generate URL
			local url_name = gsub(strlower(item_name), ' ', '-')
			url_name = gsub(url_name, "'", '')
			local url = 'https://www.wowauctions.net/auctionHouse/turtle-wow/ambershire/mergedAh/' .. url_name
			if item_id then
				url = url .. '-' .. item_id
			end
			aux.print(aux.color.gold('WoWAuctions: ') .. url)
		end
	-- Craft-to-vendor commands
	elseif arguments[1] == 'craft' then
		if arguments[2] == 'status' or arguments[2] == nil then
			craft_vendor.print_session()
		elseif arguments[2] == 'recipes' then
			craft_vendor.print_recipes()
		elseif arguments[2] == 'reset' or arguments[2] == 'clear' then
			craft_vendor.reset_session()
			aux.print('Craft session cleared.')
		elseif arguments[2] == 'maxprice' then
			-- Show max prices for materials (default: any profit)
			local margin = tonumber(arguments[3]) or 0
			margin = margin / 100
			local margin_text = margin == 0 and 'any profit' or (margin * 100) .. '% margin'
			aux.print(aux.color.gold('--- Max Material Prices (' .. margin_text .. ') ---'))
			local shown = {}
			for mat_id, recipe_list in pairs(craft_vendor.material_to_recipes) do
				if not shown[mat_id] then
					shown[mat_id] = true
					local max_price, recipe_name = craft_vendor.get_max_mat_price(mat_id, margin)
					if max_price and max_price > 0 then
						local mat_name = recipe_list[1].recipe.materials[1].name
						for _, mat in ipairs(recipe_list[1].recipe.materials) do
							if mat.item_id == mat_id then
								mat_name = mat.name
								break
							end
						end
						local money = require 'aux.util.money'
						aux.print(format('%s: max %s (for %s)',
							mat_name,
							money.to_string(max_price, nil, true),
							recipe_name
						))
					end
				end
			end
		elseif arguments[2] == 'profitable' then
			craft_vendor.print_profitable()
		elseif arguments[2] == 'safe' then
			craft_vendor.print_safe_materials()
		elseif arguments[2] == 'ready' then
			-- Show what can be crafted with bought materials
			local craftable = craft_vendor.get_craftable()
			if getn(craftable) == 0 then
				aux.print('No recipes ready. Keep buying materials!')
				craft_vendor.print_missing()
			else
				aux.print(aux.color.green('=== READY TO CRAFT ==='))
				local total_profit = 0
				for _, item in ipairs(craftable) do
					local profit_str = money.to_string(item.profit_each, nil, true)
					local total_str = money.to_string(item.total_profit, nil, true)
					aux.print(format('  %dx %s → +%s each (total: +%s)',
						item.quantity,
						item.name,
						profit_str,
						total_str
					))
					total_profit = total_profit + item.total_profit
				end
				aux.print(aux.color.gold('Total potential profit: +' .. money.to_string(total_profit, nil, true)))
			end
		elseif arguments[2] == 'missing' then
			craft_vendor.print_missing()
		else
			aux.print('Craft commands:')
			aux.print('- craft status - Show collected materials')
			aux.print('- craft ready - Show what you can craft NOW')
			aux.print('- craft missing - Show what materials you still need')
			aux.print('- craft safe - List safe materials (no leftover risk)')
			aux.print('- craft recipes - List all recipes')
			aux.print('- craft maxprice [margin%] - Show max prices for materials')
			aux.print('- craft profitable - Show profitable crafts (uses market data)')
			aux.print('- craft reset - Clear session')
		end
	else
		aux.print('Usage:')
		aux.print('- scale [' .. aux.color.blue(aux.account_data.scale) .. ']')
		aux.print('- ignore owner [' .. status(aux.account_data.ignore_owner) .. ']')
		aux.print('- uc [' .. status(aux.account_data.undercut) .. ']')
		aux.print('- post bid [' .. status(aux.account_data.post_bid) .. ']')
        aux.print('- post duration [' .. aux.color.blue(aux.account_data.post_duration / 60 * 3 .. 'h') .. ']')
		aux.print('- post stack [' .. status(aux.account_data.post_stack) .. ']')
        aux.print('- crafting cost [' .. status(aux.account_data.crafting_cost) .. ']')
		aux.print('- tooltip value [' .. status(tooltip_settings.value) .. ']')
		aux.print('- tooltip daily [' .. status(tooltip_settings.daily) .. ']')
		aux.print('- tooltip merchant buy [' .. status(tooltip_settings.merchant_buy) .. ']')
		aux.print('- tooltip merchant sell [' .. status(tooltip_settings.merchant_sell) .. ']')
		aux.print('- tooltip disenchant value [' .. status(tooltip_settings.disenchant_value) .. ']')
		aux.print('- tooltip disenchant distribution [' .. status(tooltip_settings.disenchant_distribution) .. ']')
		aux.print('- tooltip wowauctions [' .. status(tooltip_settings.wowauctions) .. ']')
		aux.print('- clear item cache')
		aux.print('- populate wdb')
		aux.print('- sharing [' .. status(aux.account_data.sharing) .. ']')
        aux.print('- theme [' .. aux.color[aux.account_data.theme == 'blizzard' and 'green' or 'red']('blizzard') .. ' | ' .. 
            aux.color[aux.account_data.theme == 'modern' and 'green' or 'red']('modern') .. ']')
		aux.print('- show hidden [' .. status(aux.account_data.showhidden) .. ']')
		aux.print('- purchase summary [' .. status(aux.account_data.purchase_summary) .. ']')
		aux.print('- reset profit')
		aux.print('- top [N] - Show top N profitable items')
		aux.print('- wowauction <item> - Get WoWAuctions.net link')
		aux.print('- craft <status|ready|missing|safe|recipes|profitable|reset>')
    end
end
