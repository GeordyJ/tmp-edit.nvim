-- Author: Geordy Jomon gj82@njit.edu
-- GeordyJ/tmp-edit.nvim: edit files in $TMPDIR

local M = {}

---@class TmpEditConfig
---@field verbose boolean
---@field set_timestep boolean
---@field tmp_dir string
local DEFAULT_CONFIG = {
	verbose = false,
	set_timestep = true,
	tmp_dir = os.getenv("TMPDIR") or "/tmp",
}

-- Stores the state for tmp-edit.nvim
local state = {
	tmp_files = {},
	autocmd_ids = {},
	cursor_positions = {},
	original_pwd = vim.fn.getcwd(),
	config = DEFAULT_CONFIG,
}

---@param opts TmpEditConfig?
---Setup function for tmp_edit.nvim
M.setup = function(opts)
	state.config = vim.tbl_deep_extend("force", DEFAULT_CONFIG, opts or {})
end

local function log(msg)
	if state.config.verbose then
		vim.notify(msg, vim.log.levels.INFO, { title = "tmp-edit.nvim" })
	end
end

---@param file_path string
---@return string
local function generate_tmp_filename(file_path)
	local tmp_file_name = vim.fn.fnamemodify(file_path, ":t")
	if state.config.set_timestep then
		return string.format("%s/%s_%s", state.config.tmp_dir, os.date("%Y%m%d_%H%M%S"), tmp_file_name)
	end
	return string.format("%s/%s", state.config.tmp_dir, tmp_file_name)
end

---@param file_path string
---@return string tmp_file_path
local function copy_to_tmp(file_path)
	local tmp_file_path = generate_tmp_filename(file_path)

	local ok, err = vim.uv.fs_copyfile(file_path, tmp_file_path)
	if not ok then
		error(string.format("Failed to copy file to temp: %s", err))
	end

	state.tmp_files[tmp_file_path] = file_path
	return tmp_file_path
end

---@param tmp_file_path string
---@param original_file_path string
local function sync_back(tmp_file_path, original_file_path)
	local ok, err = vim.uv.fs_copyfile(tmp_file_path, original_file_path)
	if not ok then
		error(string.format("Failed to sync file back to original: %s", err))
	end
	log(string.format("Synced: %s", original_file_path))
end

---@param tmp_file_path string
---@param original_file_path string
local function schedule_sync_back(tmp_file_path, original_file_path)
	vim.schedule(function()
		sync_back(tmp_file_path, original_file_path)
	end)
end

---@param buffer number
local function detach_lsp_clients(buffer)
	local clients = vim.lsp.get_clients({ buffer = buffer })
	for _, client in ipairs(clients) do
		local ok = pcall(vim.lsp.buf_detach_client, buffer, client.id)
		if not ok then
			log("Failed to detach LSP client")
		end
	end
end

---@param buffer number
---@param root_dir string
local function attach_new_lsp_clients(buffer, root_dir)
	for _, client in ipairs(vim.lsp.get_clients()) do
		local new_client = vim.lsp.start_client({
			name = client.name,
			cmd = client.config.cmd,
			root_dir = root_dir,
			capabilities = client.config.capabilities,
			settings = client.config.settings,
		})
		if new_client then
			vim.lsp.buf_attach_client(buffer, new_client)
		end
	end
end

---@param file_path string
local function save_cursor_position(file_path)
	state.cursor_positions[file_path] = vim.api.nvim_win_get_cursor(0)
end

---@param file_path string
local function restore_cursor_position(file_path)
	local pos = state.cursor_positions[file_path]
	if pos then
		vim.api.nvim_win_set_cursor(0, pos)
	end
end

--Start editing current open buffer in temp dir while restaring LSPs
M.start_edit_in_tmp = function()
	local original_file_path = vim.fn.expand("%:p")
	local tmp_file_path = copy_to_tmp(original_file_path)

	save_cursor_position(original_file_path)

	vim.api.nvim_set_current_dir(state.config.tmp_dir)

	-- Switch to temp file
	vim.cmd(string.format("edit %s", tmp_file_path))
	vim.cmd("bdelete! #")

	restore_cursor_position(original_file_path)

	detach_lsp_clients(0)
	attach_new_lsp_clients(0, vim.fn.fnamemodify(tmp_file_path, ":h"))

	local autocmd_id = vim.api.nvim_create_autocmd("BufWritePost", {
		buffer = 0,
		callback = function()
			schedule_sync_back(tmp_file_path, original_file_path)
		end,
		desc = "tmp-edit: Sync the file back to the original location after saving",
	})

	state.autocmd_ids[tmp_file_path] = autocmd_id
	log(string.format("Editing in: %s", state.config.tmp_dir))
end

--Stop editing in tempfile and switch to orignal
M.stop_edit_in_tmp = function()
	local current_file_path = vim.fn.expand("%:p")

	if not vim.startswith(current_file_path, state.config.tmp_dir) then
		vim.notify("Not editing a file in temp directory.", vim.log.levels.WARN)
		return
	end

	local original_file_path = state.tmp_files[current_file_path]
	if not original_file_path then
		error(string.format("Original file path not found for: %s", current_file_path))
		return
	end

	save_cursor_position(current_file_path)

	-- Switch back to original file
	vim.api.nvim_set_current_dir(state.original_pwd)
	vim.cmd(string.format("edit %s", original_file_path))
	vim.cmd("bdelete! #")

	restore_cursor_position(current_file_path)

	-- Clean up autocmd
	local autocmd_id = state.autocmd_ids[current_file_path]
	if autocmd_id then
		vim.api.nvim_del_autocmd(autocmd_id)
		state.autocmd_ids[current_file_path] = nil
		log(string.format("Autocmd removed: %s", current_file_path))
	end

	log(string.format("Editing: %s", original_file_path))
end

--Interface to toggle tmp-edit.nvim
M.toggle_edit_in_tmp = function()
	local current_file_path = vim.fn.expand("%:p")

	if vim.startswith(current_file_path, state.config.tmp_dir) then
		M.stop_edit_in_tmp()
	else
		M.start_edit_in_tmp()
	end
end

return M
