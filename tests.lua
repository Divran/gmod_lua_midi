--create lookup table for octal to binary
oct2bin = {
    ['0'] = '000',
    ['1'] = '001',
    ['2'] = '010',
    ['3'] = '011',
    ['4'] = '100',
    ['5'] = '101',
    ['6'] = '110',
    ['7'] = '111'
}
function getOct2bin(a) return oct2bin[a] end
function convertBin(n)
    local s = string.format('%o', n)
    s = s:gsub('.', getOct2bin)
    return s
end



local f = io.open("MIDI_sample.mid","rb")
local s = f:read("*a")
f:close()

--local midi = require "midi_real"
--local t = midi.midi2opus(s)

require "midi"
local t = parseMIDI(s)

local function printTable(t,done,indent)
	done = done or {}
	if done[t] then return end
	indent = indent or 0
	done[t] = true

	for k,v in pairs(t) do
		if type(v) == "table" then
			print(string.rep(" ",indent)..k.." = ")
			printTable(v,done,indent+2)
		else
			print(string.rep(" ",indent)..k.." = "..v)
		end
	end
end

printTable(t)

--[[
print("BEFORE")
for k,v in pairs(t) do
	print(k,"=",type(v)=="table" and #v or v)
end
print("AFTER")
local allowed = {
	note_off = true,
	note_on = true,
	key_after_touch = true,
	control_change = true,
	patch_change = true,
	channel_after_touch = true,
	pitch_wheel_change = true,
}
for k,track in pairs(t) do
	if type(track) == "table" then
		for i=#track, 1, -1 do
			if not allowed[ track[i][1] ] then
				table.remove(track,i)
			end
		end
	end
end
--printTable(t)

for k,v in pairs(t) do
	print(k,"=",type(v)=="table" and #v or v)
end

print("----")

require "midi"
local t2 = parseMIDI(s)
local tracks = t2.tracks

for k,v in pairs(t2.tracks) do
	print(" ",k,"=",#v)
end


local function compare(mine,theirs)
	if mine.command ~= theirs[1] then return false end
	if mine.deltatime ~= theirs[2] then return false end
	if mine.channel ~= theirs[3] then return false end
	if mine.param1 ~= theirs[4] then return false end
	if mine.param2 ~= theirs[5] then return false end
	return true
end

local function printBoth(mine,theirs)
	print("DIFFERENT!")
	print("command",mine.command,theirs[1])
	print("deltatime",mine.deltatime,theirs[2])
	print("channel",mine.channel,theirs[3])
	print("param1",mine.param1,theirs[4])
	print("param2",mine.param2,theirs[5])
	print("---")
end

for k,track in pairs(tracks) do
	local their_track = t[k+1]

	for k2,mine in pairs(track) do
		local theirs = their_track[k2]

		if not compare(mine,theirs) then
			printBoth(mine,theirs)
			print(k,k2)
			return
		end
	end
end
]]