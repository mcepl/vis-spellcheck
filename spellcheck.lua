local module = {}
module.lang = os.getenv("LANG"):sub(0,5) or "en_US"
-- TODO use more spellcheckers (aspell/hunspell)
module.cmd = "enchant -d %s -a"

function spellcheck(file, range)
	local cmd = module.cmd:format(module.lang)
	local ret, so, se = vis:pipe(file, range, cmd)

	if ret ~= 0 then
		return ret, se
	end

	local word_corrections = so:gmatch("(.-)\n")
	-- skip header line
	word_corrections()

	local orig = file:content(range)
	local new = orig:gsub("%S+", function(w)
		local correction = word_corrections()
		-- empty correction means a new line in range
		if correction == "" then
			correction = word_corrections()
		end
		if correction and correction ~= "*" then
			-- get corrections
			local orig, pos, sug = correction:match("& (%S+) %d+ (%d+): (.*)")
			if orig ~= w then
				orig = orig or "nil"
				print("Bad things happend!! Correction: " .. orig  .. " is not for " .. w)
				return w
			end
			-- select a correction
			local cmd = 'printf "' .. sug:gsub(", ", "\\n") .. '\\n" | vis-menu'
			local f = io.popen(cmd)
			correction = f:read("*all")
			-- trim correction
			correction = correction:match("%S+")
			f:close()
			if correction then
				return correction
			end
		else
			print("Bad things happend!! No correction available for " .. w)
		end
	end)

	if orig ~= new then
		file:delete(range)
		file:insert(range.start, new)
	end
end

vis:map(vis.modes.NORMAL, "<C-s>", function(keys)
	local win = vis.win
	local file = win.file
	ret, err = spellcheck(file, { start=0, finish=file.size })
	if ret then
		vis:info(err)
	end
	win:draw()
	return 0
end, "Spellcheck the whole file")

vis:map(vis.modes.NORMAL, "<C-w>", function(keys)
	local win = vis.win
	local file = win.file
	local pos = win.cursor.pos
	if not pos then return end
	local range = file:text_object_word(pos > 0 and pos-1 or pos);
	if not range then return end
	if range.start == range.finish then return end
	ret, err = spellcheck(file, range)
	if ret then
		vis:info(err)
	end
	win:draw()
	return 0
end, "Spellcheck word")

return module
