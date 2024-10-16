-- Author: Geordy Jomon
-- WARNING: This is still work in progress, see the README for more details

local M = {}

local tmp_files = {}
local autocmd_ids = {}
local cursor_positions = {}
local original_pwd = vim.fn.getcwd()

local verbose = false

local function get_tmp_dir()
	return os.getenv("TMPDIR") or "/tmp"
end

local function copy_to_tmp(file_path)
	local tmp_dir = get_tmp_dir()

	local tmp_file_name = vim.fn.fnamemodify(file_path, ":t")
	local tmp_file_path = tmp_dir .. "/" .. os.date("%Y%m%d_%H%M%S") .. "_" .. tmp_file_name

	local ok, err = vim.loop.fs_copyfile(file_path, tmp_file_path)
	if not ok then
		error("Failed to copy file to temp: " .. err)
	end

	tmp_files[tmp_file_path] = file_path

	return tmp_file_path
end

local function sync_back(tmp_file_path, original_file_path)
	local ok, err = vim.loop.fs_copyfile(tmp_file_path, original_file_path)
	if not ok then
		error("Failed to sync file back to original: " .. err)
	end
	if verbose then
		print("File synced back to original: " .. original_file_path)
	end
end

M.start_edit_in_tmp = function()
	local original_file_path = vim.fn.expand("%:p")
	local tmp_file_path = copy_to_tmp(original_file_path)

	cursor_positions[original_file_path] = vim.api.nvim_win_get_cursor(0)

	local tmp_dir = get_tmp_dir()
	vim.api.nvim_set_current_dir(tmp_dir)
	vim.api.nvim_command("edit " .. tmp_file_path)
	vim.api.nvim_command("bdelete! #")

	if cursor_positions[original_file_path] then
		vim.api.nvim_win_set_cursor(0, cursor_positions[original_file_path])
	end

	local clients = vim.lsp.buf_get_clients(0)
	for _, client in ipairs(clients) do
		vim.lsp.buf_detach_client(0, client.id)
	end

	local root_dir = vim.fn.fnamemodify(tmp_file_path, ":h")

	for _, client in ipairs(vim.lsp.get_active_clients()) do
		local new_client = vim.lsp.start_client({
			name = client.name,
			cmd = client.config.cmd,
			root_dir = root_dir,
			filetypes = client.config.filetypes,
			capabilities = client.config.capabilities,
		})

		vim.lsp.buf_attach_client(0, new_client)
	end

	local autocmd_id = vim.api.nvim_create_autocmd("BufWritePost", {
		buffer = 0,
		callback = function()
			sync_back(tmp_file_path, original_file_path)
		end,
		desc = "Sync the file back to the original location after saving",
	})

	autocmd_ids[tmp_file_path] = autocmd_id

	if verbose then
		print("Editing in temp directory: " .. tmp_dir)
	end
end

M.stop_edit_in_tmp = function()
	local current_file_path = vim.fn.expand("%:p")
	local tmp_dir = get_tmp_dir()

	if vim.startswith(current_file_path, tmp_dir) then
		local original_file_path = tmp_files[current_file_path]
		if original_file_path then
			cursor_positions[current_file_path] = vim.api.nvim_win_get_cursor(0)
			vim.api.nvim_set_current_dir(original_pwd)
			vim.api.nvim_command("edit " .. original_file_path)
			vim.api.nvim_command("bdelete! #")

			if cursor_positions[current_file_path] then
				vim.api.nvim_win_set_cursor(0, cursor_positions[current_file_path])
			end

			local autocmd_id = autocmd_ids[current_file_path]
			if autocmd_id then
				vim.api.nvim_del_autocmd(autocmd_id)
				autocmd_ids[current_file_path] = nil
				if verbose then
					print("Autocmd removed for: " .. current_file_path)
				end
			end

			if verbose then
				print("Switched back to original file and directory: " .. original_file_path)
			end
		else
			print("Original file path not found for: " .. current_file_path)
		end
	else
		print("Not editing a file in temp directory.")
	end
end

M.setup = function(opts)
	if opts["verbose"] == true then
		verbose = true
	end
end

return M
