local log = require("neo-tree.log")

local input_postfix = ": "

local M = {}

M.all = {
	desc = "All",
	input = function(_, _, cb)
		cb({
			desc = "All",
			query = {},
		})
	end,
}

M.orphans = {
	desc = "Orphans",
	input = function(_, _, cb)
		cb({ desc = "Orphans", query = { orphan = true } })
	end,
}

M.flimsy = {
	desc = "Filmsy",
	input = function(_, _, cb)
		cb({
			desc = "Flimsy",
			query = {
				sort = { "word-count" },
				limit = 20,
			},
		})
	end,
}

M.match_fts = {
	desc = "Match (full-text)",
	input = function(_, _, cb)
		vim.ui.input({ prompt = "Match (full-text)" .. input_postfix }, function(input)
			if input then
				cb({
					desc = "Match (full-text) " .. input,
					query = {
						match = input,
						matchStrategy = 'fts',
					},
				})
			end
		end)
	end,
}
M.match_re = {
	desc = "Match (regular expression)",
	input = function(_, _, cb)
		vim.ui.input({ prompt = "Match (regular expression)" .. input_postfix }, function(input)
			if input then
				cb({
					desc = "Match (regular expression) " .. input,
					query = {
						match = input,
						matchStrategy = 're',
					},
				})
			end
		end)
	end,
}
M.match_exact = {
	desc = "Match (exact)",
	input = function(_, _, cb)
		vim.ui.input({ prompt = "Match (exact)" .. input_postfix }, function(input)
			if input then
				cb({
					desc = "Match (exact) " .. input,
					query = {
						match = input,
						matchStrategy = 'exact',
					},
				})
			end
		end)
	end,
}

local function format_item_tag(tag)
	return tag.name
end

M.tag = {
	desc = "Tag",
	input = function(notebookPath, _, cb)
		require("zk.api").tag.list(notebookPath, {}, function(err, tags)
			if err then
				log("Error while querying tags: ", err)
				return
			end
			vim.ui.select(tags, { prompt = "Tag", format_item = format_item_tag }, function(tag)
				if tag then
					cb({
						desc = "Tag " .. tag.name,
						query = {
							tags = { tag.name },
						},
					})
				end
			end)
		end)
	end,
}

local function format_item_note(note)
	local path = note.path:sub(1, note.path:len() - note.filename:len())
	return path .. (note.title or note.filename)
end

local function link(field, desc, extra)
	return {
		desc = desc,
		input = function(notebookPath, _, cb)
			require("zk.api").list(notebookPath, {
				select = { "title", "path", "filename" },
			}, function(err, tags)
				if err then
					log("Error while querying tags: ", err)
					return
				end
				vim.ui.select(tags, { prompt = desc, format_item = format_item_note }, function(note)
					if note then
						local query = vim.tbl_extend("error", { [field] = { note.path } }, extra or {})
						cb({
							desc = desc .. " " .. format_item_note(note),
							query = query,
						})
					end
				end)
			end)
		end,
	}
end

M.mention = link("mention", "Mention")
M.mentionedBy = link("mentionedBy", "Mentioned by")
M.linkTo = link("linkTo", "Link to")
M.linkToRecursive = link("linkTo", "Link to (recursive)", { recursive = true })
M.linkedBy = link("linkedBy", "Linked by")
M.linkToRecursive = link("linkTo", "Link to (recursive)", { recursive = true })
M.linkedByRecursive = link("linkedByRecursive", "Linked by (recursive)", { recursive = true })
M.related = link("related", "Related")

local function date(field, refField, desc)
	return {
		desc = desc,
		input = function(notebookPath, id, cb)
			local rPath = id:sub(vim.fn.getcwd():len() + 2)
			require("zk.api").list(notebookPath, {
				select = { refField },
				hrefs = { rPath },
				limit = 1,
			}, function(err, notes)
				if err then
					log("Error while querying tags: ", err)
					return
				end
				local default = (notes[1] and notes[1][refField]) or ""
				default = default:sub(1, 16)
				vim.ui.input({ prompt = desc .. input_postfix, default = default }, function(input)
					if input then
						cb({
							desc = desc .. " " .. input,
							query = {
								[field] = input,
							},
						})
					end
				end)
			end)
		end,
	}
end

M.created = date("created", "created", "Created")
M.createdBefore = date("createdBefore", "created", "Created before")
M.createdAfter = date("createdAfter", "created", "Created after")
M.modified = date("modified", "modified", "Modified")
M.modifiedBefore = date("modifiedBefore", "modified", "Modified before")
M.modifiedAfter = date("modifiedAfter", "modified", "Modified after")

return M
