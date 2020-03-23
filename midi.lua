

function parseMIDI( str )
	-- much help from https://github.com/nguyenkien07/parse-midi-file-lua/blob/master/midi.lua
	local byte = string.byte
	local sub = string.sub
	local filepos = 1

	local parse = {
		[4] = function( s )
			return 	16777216*byte(sub(s,1)) +
					65536*byte(sub(s,2)) +
					256*byte(sub(s,3)) + 
					byte(sub(s,4))
		end,
		[2] = function( s )
			return 256*byte(sub(s,1))+
					byte(sub(s,2))
		end,
	}

	local function getInstrumentFilePath(event)

		local instruments = {
			bass = "sound/instruments/bass.wav",
			cymbal = "sound/instruments/cymbal.wav",
			hi_hat = "sound/instruments/hi_hat.wav",
			hi_tom = "sound/instruments/hi_tom.wav",
			piano = "sound/instruments/pianoa_440.wav",
			snare = "sound/instruments/snare.wav",

			synth_440 = "sound/synth/saw_440.wav",
			synth_880 = "sound/synth/saw_880.wav",
			synth_1760 = "sound/synth/saw_1760.wav"
		}

		local program = event.param1
		
		if event.channel == 10 then -- percussive
			if program == 37 or program == 39 then event.instrument = instruments.snare -- snare
			elseif program == 41 or program == 43 or program == 45 then event.instrument = instruments.hi_hat -- hi-hat
			elseif program == 40 or program == 42 or program == 44 or program == 46 or program == 47 or program == 49 then event.instrument = instruments.hi_tom -- hi-tom
			elseif program == 34 or program == 35 then event.instrument = instruments.bass -- bass
			elseif program == 48 or program == 50 or program == 51 or program == 54 or program == 57 or program == 58 then event.instrument = instruments.cymbal -- cymbal
			else event.instrument = instrument.hi_tom end -- backup
		else
			if program <= 7 then event.instrument = instruments.piano -- piano
			elseif program >= 32 and program <= 39 then event.instrument = instruments.bass -- bass
			elseif program == 120 then event.instrument = instruments.cymbal -- cymbal
			else event.instrument = instruments.synth_440 end -- backup
		end
	end

	local function variableLengthNumber(s)
		local ret = 0
		repeat
			local current_num = byte(s:get())
			ret = (ret << 7) + (current_num & 0x7F)
		until current_num & 0x80 ~= 128
		return ret
	end

	string.get = function( str, len, doparse )
		local got = sub( str, filepos, filepos + (len or 1) - 1 )
		--print("got:",filepos,filepos + (len or 0),got)
		filepos = filepos + (len or 1)

		if doparse then got = parse[len]( got ) end

		return got
	end

	if str:get(4) ~= "MThd" then
		error("Invalid MIDI file, MThd header missing")
	end

	local parsed = {}

	-- get file headers
	local length = str:get(4,true)
	local format = str:get(2,true)
	local ntracks = str:get(2,true)
	local tickdiv = str:get(2,true)

	parsed["tick"] = tickdiv
	parsed["tracks"] = {}

	-- check tracks
	local running = false
	while filepos < #str - 8 do
		local track_head = str:get(4)
		if track_head ~= "MTrk" then error("Invalid MIDI file, MTrk header missing") end

		local track_length = str:get(4,true)
		if track_length > #str then error("Invalid MIDI file, track length is larger than file length") end
		local track_end = filepos + track_length

		local track = {}

		local parsed_index = 1

		-- decode this track
		while filepos < track_end - 1 do
			local deltatime = variableLengthNumber(str)
			local event = byte(str:get())

			--print("filepos",filepos,str:sub(filepos,filepos+20))

			if event < 0xF0 then -- midi event
				--print("midi event")
				if event & 255 > 127 then -- not running
					running = event -- set for future possible running events
				else
					if running == false then error("Invalid MIDI file, tried to use running even incorrectly") end
					event = running
					filepos = filepos - 1
				end

				local command = event & 0xFF0
				local channel = event & 0xF

				local e = {}
				e["deltatime"] = deltatime
				e["channel"] = channel
				e["param1"] = byte(str:get())

				if command == 0x80 then -- Note off
					e["command"] = "note off"
					e["param2"] = byte(str:get())
				elseif command == 0x90 then -- Note open
					e["command"] = "note on"
					e["param2"] = byte(str:get())
				elseif command == 0xA0 then -- Polyphonic pressure
					e["command"] = "polyphonic pressure"
					e["param2"] = byte(str:get())
				elseif command == 0xB0 then -- Controller
					e["command"] = "control change"
					e["param2"] = byte(str:get())
				elseif command == 0xC0 then -- Program change
					e["command"] = "program change"
					getInstrumentFilePath(e)
				elseif command == 0xD0 then -- Channel pressure
					e["command"] = "channel pressure"
				elseif command == 0xE0 then -- Pitch blend
					e["command"] = "pitch blend"
					local param2 = byte(str:get())
					e["param2"] = 128 * param2 + param1 - 8192
				end

				track[parsed_index] = e
				parsed_index = parsed_index + 1
			elseif event == 0xFF then -- Meta event
				local command = str:get()
				local length = variableLengthNumber(str)

				local e = {}
				e["deltatime"] = deltatime

				if command == 3 then -- track name
					e["command"] = "track name"
					e["param1"] = str:get(length)
				elseif command == 4 then -- instrument name
					e["command"] = "instrument name"
					e["param1"] = str:get(length)
				else
					local junk = str:get(length) -- read and forget data to move filepos
				end

				--[[
				if command == 0 then
					if length == 2 then
						str:get(2,true) -- read and forget data
					else
						error("Invalid MIDI file, length was not 2 when expected")
					end
				elseif command < 0x2F then
					str:get(length) -- read and forget data
				elseif command == 0x2F then
					parsed[parsed_index] = {"track_end", deltatime}
					parsed_index = parsed_index + 1
				elseif 
				print("meta event",command,length)
				local junk = str:get(length)
				]]
				-- ignore meta events
			elseif event == 0xF0 or event == 0xF7 then -- SysEx event
				local length = variableLengthNumber(str)
				local junk = str:get(length) -- read and forget data to move filepos
				-- ignore SysEx events
			elseif event == 0xF2 then str:get(3) -- song_position
			elseif event == 0xF3 then str:get(2) -- song_select
			--elseif event == 0xF6 then -- tune_request
			elseif event > 0xF0 then str:get(2) -- unknown event
			else
				error("Invalid MIDI file, unknown event")
			end
		end

		-- override filepos with correct position
		filepos = track_end
		parsed["tracks"][#parsed["tracks"]+1] = track
	end

	return parsed
end
