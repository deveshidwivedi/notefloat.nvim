local M = {}

local api = vim.api
local fn = vim.fn
local storage_path = fn.stdpath("data") .. "/notefloat"
local notes = {}
local windows = {}
local buffers = {}

local config = {
    size = 0.6,
    border = "rounded",
    filetype = "markdown",
    auto_save = true,
    debounce_ms = 1000,
    categories = {"quick", "todo", "code", "meeting"}
}

local window_currently_opened = false
local current_category = "quick"
local timer = nil

-- Ensure storage directory exists
local function ensure_storage()
    if fn.isdirectory(storage_path) == 0 then
        fn.mkdir(storage_path, "p")
    end
end

-- Get file path for a category
local function get_file_path(category)
    return storage_path .. "/" .. category .. ".md"
end

-- Load note content from file
local function load_note(category)
    local path = get_file_path(category)
    if fn.filereadable(path) == 1 then
        local content = {}
        for line in io.lines(path) do
            table.insert(content, line)
        end
        return content
    end
    return {"# " .. category:gsub("^%l", string.upper) .. " Notes", "", ""}
end

-- Save note content to file
local function save_note(category)
    if not buffers[category] or not api.nvim_buf_is_valid(buffers[category]) then
        return
    end
    
    local content = api.nvim_buf_get_lines(buffers[category], 0, -1, false)
    local path = get_file_path(category)
    
    local file = io.open(path, "w")
    if file then
        for _, line in ipairs(content) do
            file:write(line .. "\n")
        end
        file:close()
    end
end

-- Get floating window configuration
function M.get_float_config()
    local ui_info = api.nvim_list_uis()[1]
    local width = math.floor(ui_info.width * config.size)
    local height = math.floor(ui_info.height * config.size)
    
    return {
        relative = "editor",
        width = width,
        height = height,
        row = (ui_info.height - height) * 0.5 - 1,
        col = (ui_info.width - width) * 0.5,
        style = "minimal",
        border = config.border
    }
end

-- Open window for a category
function M.open_window(category)
    windows[category] = api.nvim_open_win(buffers[category], true, M.get_float_config())
    api.nvim_win_set_option(windows[category], "winblend", 10)
    api.nvim_win_set_option(windows[category], "cursorline", true)
    api.nvim_win_set_option(windows[category], "foldcolumn", "0")
    
    -- Set title if possible (Neovim >= 0.9)
    if vim.fn.has("nvim-0.9") == 1 then
        api.nvim_win_set_config(windows[category], {
            title = " 📝 " .. category:gsub("^%l", string.upper) .. " Notes ",
            title_pos = "center"
        })
    end
end

-- Refresh/resize window
function M.refresh_window(category)
    local win = windows[category]
    if not api.nvim_win_is_valid(win) then return end
    api.nvim_win_set_config(win, M.get_float_config())
end

-- Setup auto-save
local function setup_autosave(category)
    if not config.auto_save then return end
    
    local buf = buffers[category]
    api.nvim_create_autocmd("TextChanged", {
        buffer = buf,
        callback = function()
            if timer then
                timer:stop()
            end
            timer = vim.defer_fn(function()
                save_note(category)
            end, config.debounce_ms)
        end
    })
    
    api.nvim_create_autocmd("TextChangedI", {
        buffer = buf,
        callback = function()
            if timer then
                timer:stop()
            end
            timer = vim.defer_fn(function()
                save_note(category)
            end, config.debounce_ms)
        end
    })
end

-- Create window and buffer for a category
function M.create_window(category)
    if not buffers[category] or not api.nvim_buf_is_valid(buffers[category]) then
        -- Create new buffer
        local buf = api.nvim_create_buf(false, true)
        buffers[category] = buf
        
        -- Setup buffer
        api.nvim_buf_set_option(buf, "filetype", config.filetype)
        api.nvim_buf_set_option(buf, "bufhidden", "hide")
        api.nvim_buf_set_option(buf, "swapfile", false)
        
        -- Load content
        local content = load_note(category)
        api.nvim_buf_set_lines(buf, 0, -1, false, content)
        
        -- Setup autogroup for window events
        local notefloat_augroup = api.nvim_create_augroup("notefloat_" .. category, { clear = true })
        
        -- Close window when leaving buffer
        api.nvim_create_autocmd("BufLeave", {
            buffer = buf,
            group = notefloat_augroup,
            callback = function()
                save_note(category)
                
                if window_currently_opened and windows[category] and api.nvim_win_is_valid(windows[category]) then
                    api.nvim_win_close(windows[category], true)
                    window_currently_opened = false
                end
            end,
        })
        
        -- Handle window resize
        api.nvim_create_autocmd("VimResized", {
            buffer = buf,
            group = notefloat_augroup,
            callback = function() 
                M.refresh_window(category) 
            end
        })
        
        -- Setup autosave
        setup_autosave(category)
    end
    
    -- Open window
    M.open_window(category)
    window_currently_opened = true
end

-- Toggle note window for a category
function M.toggle(category)
    category = category or current_category
    current_category = category
    
    if window_currently_opened and windows[category] and api.nvim_win_is_valid(windows[category]) then
        -- Close the window
        api.nvim_win_close(windows[category], true)
        window_currently_opened = false
    else
        -- Create and open the window
        ensure_storage()
        M.create_window(category)
    end
end

-- Change to a different note category
function M.change_category(category)
    if not vim.tbl_contains(config.categories, category) then
        vim.notify("Invalid note category: " .. category, vim.log.levels.ERROR)
        return
    end
    
    -- Save current note if open
    if window_currently_opened then
        save_note(current_category)
        
        if windows[current_category] and api.nvim_win_is_valid(windows[current_category]) then
            api.nvim_win_close(windows[current_category], true)
        end
    end
    
    -- Open the new category
    current_category = category
    M.toggle(category)
end

-- List available categories
function M.list_categories()
    return vim.tbl_map(function(cat)
        return cat:gsub("^%l", string.upper)
    end, config.categories)
end

-- Setup the plugin
function M.setup(opts)
    -- Merge configs
    if opts then
        config = vim.tbl_deep_extend("force", config, opts)
    end
    
    -- Create commands
    api.nvim_create_user_command("NoteFloat", function(input)
        if #input.args == 0 then
            M.toggle()
        else
            M.change_category(input.args)
        end
    end, { 
        force = true, 
        nargs = "?", 
        complete = function()
            return M.list_categories()
        end
    })
    
    api.nvim_create_user_command("NoteFloatList", function()
        vim.ui.select(M.list_categories(), {
            prompt = "Select Note Category",
            format_item = function(item)
                return item
            end,
        }, function(choice)
            if choice then
                M.change_category(choice:lower())
            end
        end)
    end, { force = true })
    
    -- Ensure storage directory exists
    ensure_storage()
    
    -- Save all notes on exit
    api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
            for category, _ in pairs(buffers) do
                save_note(category)
            end
        end
    })
end

return M