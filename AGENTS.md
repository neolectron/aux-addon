# AGENTS.md - Agentic Coding Guidelines for aux-addon

_Last updated: 2026-01-09_

## Project Context
**Game Version:** Turtle WoW (Vanilla 1.12.1)
**Addon:** aux-addon
**Primary Maintainers:** shirsig, neolectron, Oldmanalpha, Geojak
**Primary Goal:** Auction House replacement, crafting profitability analysis
**UI Theme:** Retail TSM-inspired, Blizzard skin default

## 1. Development Workflow

### Running the Addon
- Install addon in TurtleWoW `Interface/AddOns/aux-addon`.
- Add/modify files listed in `aux-addon.toc` for new features.
- Use `/console reloadui` in-game to reload after changes.

### Build, Lint & Test Commands
- **No automated build/lint/test scripts.**
- All development/testing is manual, via game client:
  - **To verify changes:** `/console reloadui`
  - **Enable Lua error reporting:** `/console scriptErrors 1` (shows errors)
  - **Use BugSack addon** for error collection (recommended for debugging).
- **Single test case:** Replicate game scenario, trigger game events/commands, observe output/errors.
- Errors surface in default chat frame or Lua error window.

### Debugging
- Insert debug prints:
  ```lua
  DEFAULT_CHAT_FRAME:AddMessage("Debug: " .. tostring(var))
  ```
- Monitor variables (e.g., `scanning`, `scan_id`) for lifecycle clarity.
- Use `/framestack` command to view UI hierarchy.

## 2. Code Style Guidelines

### Module System
- Declare modules with:  
  `module 'aux.tabs.craft'`
- Use `local` for private variables/functions; omit for shared state within a module namespace.
- Export functions via `M.` prefix (e.g., `function M.exported()`), share internal utility functions without prefix.
- Do not use Lua's default `require` module system; follow aux's custom pattern.
- Shared variables (unscoped, non-local) treated as module-level and visible across same module.

### Imports
- Lua `require 'T'`, `'aux'` for utilities.
- Import order: standard library, aux libraries, core, then tab-specific files.
- Prefer explicit relative imports.

### Naming Conventions
- Module names: lowercase, underscores as separator (`aux.tabs.craft`, `core/crafting.lua`).
- Variable names: `snake_case` for locals and module-level, UPPERCASE for constants.
- Function names: `snake_case`; exported (agent-usable) via `M.` prefix.
- Event handler functions: Capitalized (`OPEN`, `CLOSE`).

### Formatting
- Indentation: **Tabs only** for code indentation. Do not mix with spaces.
- Line length limit: _Soft_ at 100chars (no enforced tooling).
- Whitespace: Use single blank lines between functions, within control blocks (if/for/while).
- Multi-line comments: Use double-hyphen `--` for comments, block-style for documentation.
  ```lua
  -- This is a comment
  --[[
    This is a block comment
  ]]--
  ```

### Types
- Lua is dynamically typed. Type hints via comments are OK but not required.
- Prefer descriptive variable naming, document data structures at top of file or in README.
- Record types, arrays, dictionaries: comment above representative functions.

### Error Handling
- Validate user input (e.g., filter strings, slash command args) via pattern match, validator sets.
- Always check for `nil` or empty table before iterating.
- Use defensive programming for Auction House events and UI interactions.
- Print warnings to chat if action is potentially detrimental (e.g., mispricing auction, failed scan).
- Fail gracefully; do not abort unless action is unsafe.

## 3. Aux Patterns & Best Practices

### State Management
- Persistent module-level state is shared automatically (`scanning`, `scan_id`). Do not use globals outside module context.
- Prefer stateless utilities for reusable logic.

### Scanning & Filter System
- Implement filters with `/` separators, semicolon `;` for OR logic.
  - Blizzard query first, post-processing second(s).
- Polish notation supported for logical operators (AND, OR, NOT).
- Custom filter specs added via map/object system:
  ```lua
  local filter = T.map('title','craft-safe','validator',T.set{''})
  function filter.refine(self,search)
      return T.map('predicate', function(auction)
        return craft_vendor.is_safe_material(auction.item_id)
      end)
  end
  tinsert(M.filter_specs,filter)
  ```

### Event Handlers & UI
- Initialize via `aux.handle.LOAD()` and `aux.handle.LOAD2()` (for multi-phase setup).
- Create UI frames via `aux.handle.INIT_UI()`; destroy/cleanup via Close handlers.
- Panels, listings, auction_listing, buttons, editboxes used as main GUI widgets.

### Key Files
```
aux-addon/
├── core/ (shared system logic)
│   ├── crafting.lua
│   ├── filter.lua
│   ├── craft_vendor.lua
│   └── ...
├── util/ (utility functions)
├── gui/ (GUI widgets)
├── tabs/ (distinct tab logic, such as search, craft, post)
├── aux-addon.toc (manifest)
```

## 4. Testing & Verification
- **Manual testing only**: in-game execution via `/console reloadui`.
- Use `/aux` slash commands for settings, `/aux theme` for UI theme toggle.
- Trigger scenarios as described in README.md and README_Geojak.md.
- Errors must be visible in chat frame or collected via BugSack.
- For single file/feature tests: Change one file, reload UI, run scenario; check for new issues or expected improvement.

## 5. Contribution Guidelines for Agentic Coding
- Make modular, isolated changes where possible; prefer extending via new tabs, filters, or modules.
- Update manifest (`aux-addon.toc`) if new files are added.
- Document major changes in README_Geojak.md or as dedicated changelog block in README.md.
- Avoid hardcoded values; add comments for 'magic numbers'.
- Use agentic principles: test before/after change, document reasoning, maintain changelog, check for regressions.
- Prefer minimal global changes unless refactoring shared logic.

## 6. Known Issues & Limitations
- No automated tests, all QA manual.
- Complex filter logic/parsing may fail; test in Search tab first for syntax verification.
- Real-time scanning not available in Craft tab (as of 2026-01-09).
- Material listing UI may hide scrollbar when Blizzard skin is active.

## 7. Maintainers
- neolectron (agentic LLM, 2026), shirsig, Oldmanalpha, Geojak

---
For further details see README.md and README_Geojak.md. Agents should strive to follow the stated patterns, adapt for new WoW versions, and document new best practices as the codebase evolves.


## 8. Empirical Addon Design Patterns Across Vanilla/TurtleWoW

This section provides precise technical rules collected from deep analysis of the following major Vanilla/TurtleWoW addons: BigWigs, BugSack, ItemRack, SuperAPI, pfUI, Atlas. Each rule is traced to concrete examples for feature addition, debugging, extensibility, and robustness.

- **Module Loading**: Declare all modules and SavedVariables in .toc. Use Ace2 (BigWigs, BugSack, Atlas, SuperAPI) or custom registry (pfUI) for feature/skin modularity. Ace2 modules mix in features via `SetModuleMixins` and use prototypes for boss/event logic (BigWigs). pfUI uses dynamic environment injection and central registries (pfUI.module).
- **Event Handling**: Always use event-driven registration for initialization, updates, and teardown. Prefer AceEvent (`RegisterEvent`, Buckets: BugSack, BigWigs) for complex logic; pfUI and ItemRack demonstrate custom event bootstraps where needed. Events should be bucketed if error-prone or expensive.
- **SavedVariables Patterns**: Persistent data always goes through TOC, partitioned by profile/char/realm/server as needed. Use AceDB for multi-profile support (BigWigs, BugSack, Atlas), pfUI for comprehensive config/migration, ItemRack for slotwise/user/event data.
- **Global/UI Frame Patterns**: Create UI frames from code, attach via explicit global or namespaced table, use UISpecialFrames for ESC/docking capability (Atlas, ItemRack, pfUI, BigWigs).
- **Slash Commands**: Register via AceConsole or direct SLASH/SlashCmdList pattern; must expose config, debug, and show/hide features (pfUI, Atlas, BugSack, BigWigs).
- **Localization**: Use AceLocale or custom locale/translation tables; register all languages up front.
- **Error Handling & Debugging**: Integrate error bucket collection, session rotation, and GUI display. Reference BugSack/BugGrabber for best-of-breed error handling. pfUI employs a custom error handler and debug messaging system. Always provide debug toggles via slash command or config option.
- **LoD / Feature Packs**: Supplement core addon with zone-feature LoD packs (BigWigs example: `X-BigWigs-LoadInZone`, event-driven loading based on context).
- **Extensibility/Plugin Systems**: Register third-party features via registry and hooks (pfUI, Atlas, BigWigs, SuperAPI). Provide `RegisterModule`, `RegisterSkin`, `RegisterPlugin` clearly.
- **Option & UI Persistence**: Robust config via SavedVariables, option tables, and explicit migration/reset code (`AtlasOptions`, pfUI's migration, ItemRack's menu/data tables).
- **Memory/Performance Patterns**: Reuse tables for UI elements and item lists, avoid unnecessary GC (ItemRack, pfUI, Atlas). Bucket or schedule events to avoid excessive runtime impact (BugSack session, BigWigs repeating event).

### Reference Table: Best Practices Linked to Addons
| Addon         | Module | LoD | Registry | Plugin | Ace2 | Custom | Error Model | SlashCmd | UI Frame | Example Feature |
|---------------|--------|-----|----------|--------|------|--------|-------------|----------|---------|----------------|
| BigWigs       | Ace2   | Yes | No       | Yes    | Yes  | No     | Yes         | Yes      | Yes     | Raid mods, LoD |
| BugSack       | Ace2   | No  | No       | Yes    | Yes  | No     | Yes         | Yes      | No      | Error catch    |
| ItemRack      | No     | No  | No       | Plugins| No   | No     | No          | Partial  | Yes     | Equip manager  |
| SuperAPI      | Ace2   | No  | No       | No     | Yes  | No     | No          | No       | No      | API hook       |
| pfUI          | No     | No  | Yes      | Yes    | No   | Yes    | Custom      | Yes      | Yes     | Full UI skin   |
| Atlas         | Ace2   | No  | Yes      | Yes    | Yes  | Partial| No          | Yes      | Yes     | Map browser    |

---
#### Actionable Technical Rules (With Addon Reference)
- Always add modules, SavedVariables, profiles to .toc (BigWigs, pfUI).
- Use Ace2 module prototypes and mixins for feature extension (BigWigs).
- Register event handlers on frame creation, use AceEvent or custom event bootstrap as needed (BugSack, pfUI).
- Set up error buckets for reporting and session management (BugSack, BugGrabber).
- Localize via library or table and register locales on init (AceLocale: BigWigs/BugSack/Atlas).
- If adding configurable UI, always tie state to SavedVariables and explicit migration logic (pfUI, Atlas, ItemRack).
- Expose config/debug via slash command (pfUI, Atlas, BugSack, BigWigs).
- Use LoD packs for zone-specific/feature-specific expansion (BigWigs).
- Plugin/extension registration must follow registry-table/hook pattern (pfUI, Atlas, BigWigs).
- Optimize UI/data memory with local table reuse, minimize GC (ItemRack, pfUI).
- Revisit example addon source for every major feature for real-world reference before implementation.

---

This empirical empirical section will be extended regularly as more addons are audited in depth.

