local M = {}

local api = vim.api
local fn = vim.fn
local storage_path = fn.stdpath("data") .. "/notefloat"
local notes = {}
local windows = {}
local buffers = {}
local sidebar_buf, sidebar_win

local config = {
    size = 0.6,
    border = "rounded",
    filetype = "markdown",
    auto_save = true,
    debounce_ms = 1000,
    periodic_save = true,
    periodic_save_interval = 60000, -- 1 minute
    git_sync = false,
    git_sync_interval = 300000, -- 5 minutes
    git_sync_message = "Auto-sync NoteFloat notes",
    summarize_prompt = "Summarize the following note in 3 bullet points:\n\n",
    sidebar_width = 30,
    categories = {"quick", "todo", "code", "meeting", "project"}
}

local window_currently_opened = false
local current_category = "quick"
local timer = nil
local periodic_timer = nil
local git_timer = nil

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

-- Save all open notes
local function save_all_notes()
    for category, _ in pairs(buffers) do
        if api.nvim_buf_is_valid(buffers[category]) then
            save_note(category)
        end
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

-- Get sidebar window configuration
function M.get_sidebar_config()
    local ui_info = api.nvim_list_uis()[1]
    local width = config.sidebar_width
    
    return {
        relative = "editor",
        width = width,
        height = ui_info.height - 4,
        row = 2,
        col = 1,
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
    if fn.has("nvim-0.9") == 1 then
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
                timer:close()
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
                timer:close()
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
    
    -- Update sidebar if it's open
    if sidebar_win and api.nvim_win_is_valid(sidebar_win) then
        M.update_sidebar()
    end
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

-- Git sync function
function M.git_sync()
    -- Check if we're in a git repo
    local is_git = fn.system("cd " .. storage_path .. " && git rev-parse --is-inside-work-tree 2>/dev/null")
    
    if is_git:find("true") then
        -- Git repo exists, commit and push changes
        local git_add = fn.system("cd " .. storage_path .. " && git add .")
        local git_commit = fn.system("cd " .. storage_path .. " && git commit -m '" .. config.git_sync_message .. "' --allow-empty")
        local git_push = fn.system("cd " .. storage_path .. " && git push")
        
        if git_push:find("error") then
            vim.notify("Failed to push notes to git repository", vim.log.levels.ERROR)
        else
            vim.notify("Notes synced to git repository", vim.log.levels.INFO)
        end
    else
        vim.notify("Git repository not found in notes directory. Please initialize one manually.", vim.log.levels.WARN)
    end
end

-- Initialize git repository
function M.init_git_repo()
    ensure_storage()
    
    -- Check if already a git repo
    local is_git = fn.system("cd " .. storage_path .. " && git rev-parse --is-inside-work-tree 2>/dev/null")
    
    if is_git:find("true") then
        vim.notify("Git repository already initialized in " .. storage_path, vim.log.levels.INFO)
        return
    end
    
    -- Initialize git repo
    local git_init = fn.system("cd " .. storage_path .. " && git init")
    
    if git_init:find("error") then
        vim.notify("Failed to initialize git repository", vim.log.levels.ERROR)
        return
    end
    
    -- Create .gitignore
    local gitignore = io.open(storage_path .. "/.gitignore", "w")
    if gitignore then
        gitignore:write("# NoteFloat gitignore\n*.swp\n*.swo\n")
        gitignore:close()
    end
    
    -- Initial commit
    fn.system("cd " .. storage_path .. " && git add . && git commit -m 'Initial NoteFloat commit'")
    
    vim.notify("Git repository initialized in " .. storage_path, vim.log.levels.INFO)
    
    -- Prompt for remote repo
    vim.ui.input({
        prompt = "Enter git remote URL (optional): ",
    }, function(input)
        if input and input ~= "" then
            local git_remote = fn.system("cd " .. storage_path .. " && git remote add origin " .. input)
            if git_remote:find("error") then
                vim.notify("Failed to add git remote", vim.log.levels.ERROR)
            else
                vim.notify("Git remote added. Use :NoteFloatGitSync to push changes.", vim.log.levels.INFO)
            end
        end
    end)
end

-- Create and update sidebar
function M.create_sidebar()
    if sidebar_buf and api.nvim_buf_is_valid(sidebar_buf) then
        api.nvim_buf_delete(sidebar_buf, { force = true })
    end
    
    sidebar_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(sidebar_buf, "filetype", "notefloat_sidebar")
    api.nvim_buf_set_option(sidebar_buf, "bufhidden", "wipe")
    api.nvim_buf_set_option(sidebar_buf, "swapfile", false)
    api.nvim_buf_set_option(sidebar_buf, "modifiable", false)
    
    -- Create sidebar window
    if sidebar_win and api.nvim_win_is_valid(sidebar_win) then
        api.nvim_win_close(sidebar_win, true)
    end
    
    sidebar_win = api.nvim_open_win(sidebar_buf, true, M.get_sidebar_config())
    api.nvim_win_set_option(sidebar_win, "cursorline", true)
    
    -- Set title if possible
    if fn.has("nvim-0.9") == 1 then
        api.nvim_win_set_config(sidebar_win, {
            title = " 📒 Notes ",
            title_pos = "center"
        })
    end
    
    -- Update sidebar content
    M.update_sidebar()
    
    -- Set up keymaps for the sidebar
    local opts = { noremap = true, silent = true, buffer = sidebar_buf }
    api.nvim_buf_set_keymap(sidebar_buf, "n", "<CR>", ":lua require('notefloat').open_from_sidebar()<CR>", opts)
    api.nvim_buf_set_keymap(sidebar_buf, "n", "q", ":lua require('notefloat').close_sidebar()<CR>", opts)
    
    -- Create autocmd to close both sidebar and note window when leaving
    api.nvim_create_autocmd("BufLeave", {
        buffer = sidebar_buf,
        callback = function()
            if sidebar_win and api.nvim_win_is_valid(sidebar_win) then
                api.nvim_win_close(sidebar_win, true)
            end
        end,
    })
end

-- Update sidebar content
function M.update_sidebar()
    if not sidebar_buf or not api.nvim_buf_is_valid(sidebar_buf) then
        return
    end
    
    -- Get active note categories
    local lines = {
        "NoteFloat Categories",
        "===================="
    }
    
    -- Add categories
    for _, category in ipairs(config.categories) do
        local prefix = " "
        if category == current_category and window_currently_opened then
            prefix = ">"
        end
        table.insert(lines, prefix .. " " .. category:gsub("^%l", string.upper))
    end
    
    -- Make buffer modifiable
    api.nvim_buf_set_option(sidebar_buf, "modifiable", true)
    
    -- Update content
    api.nvim_buf_set_lines(sidebar_buf, 0, -1, false, lines)
    
    -- Make buffer non-modifiable again
    api.nvim_buf_set_option(sidebar_buf, "modifiable", false)
end

-- Open note from sidebar
function M.open_from_sidebar()
    local line = api.nvim_get_current_line()
    line = line:gsub("^[> ] ", "")
    local category = line:lower()
    
    if vim.tbl_contains(config.categories, category) then
        M.change_category(category)
    end
end

-- Close sidebar
function M.close_sidebar()
    if sidebar_win and api.nvim_win_is_valid(sidebar_win) then
        api.nvim_win_close(sidebar_win, true)
    end
end

-- Toggle sidebar
function M.toggle_sidebar()
    if sidebar_win and api.nvim_win_is_valid(sidebar_win) then
        M.close_sidebar()
    else
        M.create_sidebar()
    end
end

-- Summarize note content
function M.summarize()
    -- Check if we have a summarization command available
    if not window_currently_opened or not current_category then
        vim.notify("No note open to summarize", vim.log.levels.ERROR)
        return
    end
    
    local content = api.nvim_buf_get_lines(buffers[current_category], 0, -1, false)
    local note_text = table.concat(content, "\n")
    
    -- Check if openai cli is available
    local has_openai = (fn.executable("openai") == 1)
    
    if has_openai then
        -- Use OpenAI CLI to summarize
        local temp_file = fn.tempname()
        local file = io.open(temp_file, "w")
        if file then
            file:write(config.summarize_prompt .. note_text)
            file:close()
            
            -- Create a new buffer and window for summary
            local sum_buf = api.nvim_create_buf(false, true)
            api.nvim_buf_set_option(sum_buf, "filetype", "markdown")
            api.nvim_buf_set_option(sum_buf, "bufhidden", "wipe")
            
            local sum_win = api.nvim_open_win(sum_buf, true, {
                relative = "editor",
                width = 60,
                height = 10,
                row = 5,
                col = 10,
                style = "minimal",
                border = "rounded",
                title = " Summary ",
                title_pos = "center"
            })
            
            -- Set initial content
            api.nvim_buf_set_lines(sum_buf, 0, -1, false, {"Generating summary...", "", "Please wait..."})
            
            -- Run OpenAI CLI in the background
            vim.fn.jobstart("openai api completions.create -m text-davinci-003 -f " .. temp_file .. " -t 0.7 -M 200", {
                on_stdout = function(_, data)
                    if data then
                        local summary_lines = {}
                        for _, line in ipairs(data) do
                            if line ~= "" then
                                table.insert(summary_lines, line)
                            end
                        end
                        
                        if #summary_lines > 0 then
                            api.nvim_buf_set_option(sum_buf, "modifiable", true)
                            api.nvim_buf_set_lines(sum_buf, 0, -1, false, summary_lines)
                            api.nvim_buf_set_option(sum_buf, "modifiable", false)
                        end
                    end
                end,
                on_stderr = function(_, data)
                    if data and #data > 0 and data[1] ~= "" then
                        api.nvim_buf_set_option(sum_buf, "modifiable", true)
                        api.nvim_buf_set_lines(sum_buf, 0, -1, false, {"Error generating summary:", "", table.concat(data, "\n")})
                        api.nvim_buf_set_option(sum_buf, "modifiable", false)
                    end
                end,
                on_exit = function(_, code)
                    if code ~= 0 then
                        api.nvim_buf_set_option(sum_buf, "modifiable", true)
                        api.nvim_buf_set_lines(sum_buf, 0, -1, false, {"Failed to generate summary.", "", "Make sure OpenAI CLI is configured correctly."})
                        api.nvim_buf_set_option(sum_buf, "modifiable", false)
                    end
                    os.remove(temp_file)
                end
            })
        end
    else
        -- Fallback to a simple summary (count lines, words, etc.)
        local lines = #content
        local words = 0
        local chars = 0
        
        for _, line in ipairs(content) do
            words = words + #vim.split(line, "%s+")
            chars = chars + #line
        end
        
        -- Create a summary buffer
        local sum_buf = api.nvim_create_buf(false, true)
        api.nvim_buf_set_option(sum_buf, "filetype", "markdown")
        api.nvim_buf_set_option(sum_buf, "bufhidden", "wipe")
        
        local sum_win = api.nvim_open_win(sum_buf, true, {
            relative = "editor",
            width = 60,
            height = 8,
            row = 5,
            col = 10,
            style = "minimal",
            border = "rounded",
            title = " Summary ",
            title_pos = "center"
        })
        
        -- Set content
        api.nvim_buf_set_lines(sum_buf, 0, -1, false, {
            "# " .. current_category:gsub("^%l", string.upper) .. " Note Summary",
            "",
            "- **Lines**: " .. lines,
            "- **Words**: " .. words,
            "- **Characters**: " .. chars,
            "",
            "For AI-powered summarization, install the OpenAI CLI"
        })
    end
end

-- Start periodic save timer
local function start_periodic_save()
    if config.periodic_save and not periodic_timer then
        periodic_timer = vim.loop.new_timer()
        periodic_timer:start(
            config.periodic_save_interval, 
            config.periodic_save_interval, 
            vim.schedule_wrap(function() 
                save_all_notes() 
            end)
        )
    end
end

-- Start git sync timer
local function start_git_sync_timer()
    if config.git_sync and not git_timer then
        -- Check if git is available
        if fn.executable("git") ~= 1 then
            vim.notify("Git not found in PATH. Git sync disabled.", vim.log.levels.WARN)
            return
        end
        
        git_timer = vim.loop.new_timer()
        git_timer:start(
            config.git_sync_interval, 
            config.git_sync_interval, 
            vim.schedule_wrap(function() 
                save_all_notes()
                M.git_sync() 
            end)
        )
    end
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
    
    api.nvim_create_user_command("NoteFloatSummarize", function()
        M.summarize()
    end, { force = true })
    
    api.nvim_create_user_command("NoteFloatGitInit", function()
        M.init_git_repo()
    end, { force = true })
    
    api.nvim_create_user_command("NoteFloatGitSync", function()
        save_all_notes()
        M.git_sync()
    end, { force = true })
    
    api.nvim_create_user_command("NoteFloatSidebar", function()
        M.toggle_sidebar()
    end, { force = true })
    
    -- Ensure storage directory exists
    ensure_storage()
    
    -- Start timers
    start_periodic_save()
    if config.git_sync then
        start_git_sync_timer()
    end
    
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