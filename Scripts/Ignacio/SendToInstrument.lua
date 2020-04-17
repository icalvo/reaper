DEBUG = false
local lib_path = reaper.GetExtState("Lokasenna_GUI", "lib_path_v2")
if not lib_path or lib_path == "" then
    reaper.MB("Couldn't load the Lokasenna_GUI library. Please install 'Lokasenna's GUI library v2 for Lua', available on ReaPack, then run the 'Set Lokasenna_GUI v2 library path.lua' script in your Action List.", "Whoops!", 0)
    return
end
loadfile(lib_path .. "Core.lua")()

InstrumentTracks = {}

for trackIndex = 0, reaper.GetNumTracks() - 1, 1 do
    local track = reaper.GetTrack(0, trackIndex)
    if reaper.TrackFX_GetInstrument(track) ~= -1 then
        local _, trackName = reaper.GetTrackName(track)
        table.insert(InstrumentTracks, { (trackIndex+1) .. ": " .. trackName, trackIndex })
    end
end

if (#InstrumentTracks == 0) then
    reaper.MB("ERROR: There are no tracks with a virtual instrument loaded.", "ERROR", MB_TYPE.OK)
    return
end

MB_TYPE = { OK = 0, OKCANCEL = 1, ABORTRETRYIGNORE = 2, YESNOCANCEL = 3, YESNO = 4, RETRYCANCEL = 5 }

local function print_binary_aux(n)
    if n == 0 then return "" end
    if n < 0 then return "-" .. print_binary_aux(-n) end
    if n % 2 == 0 then return print_binary_aux(n >> 1) .. "0" end

    return print_binary_aux(n >> 1) .. "1"
end

local function print_binary(n)
  local result = print_binary_aux(n)
  if result == "" then
    return "0"
  else
    return result
  end
end

local function debug(msg)
    if (DEBUG) then
        reaper.ShowConsoleMsg(msg .. "\n")
    end
end

local function create_send()
    local selected = GUI.Val("InstrumentsListBox")
    if (selected == nil) then
        reaper.MB("ERROR: Please select an instrument track", "ERROR", MB_TYPE.OK)
        return
    end
    debug("Selected: " .. selected)
    local trackIndex = InstrumentTracks[selected][2]
    debug("Selected track: " .. InstrumentTracks[selected][1])

    local channelString = GUI.Val("ChannelTextBox")

    if not channelString or channelString == "" then
        reaper.MB("ERROR: Must choose a destination MIDI channel", "ERROR", MB_TYPE.OK)
        return
    end

    local channel = tonumber(channelString)
    if not channel or channel < 1 or channel > 16 then
        reaper.MB("ERROR: Channel must be a number between 1 and 16", "ERROR", MB_TYPE.OK)
        return
    end

    debug("Selected channel: " .. channel)
    if reaper.CountSelectedTracks(0) ~= 1 then
        reaper.MB("ERROR: Must select only one track", "ERROR", MB_TYPE.OK)
        return
    end

    local sourceTrack = reaper.GetSelectedTrack(0, 0)
    local targetTrack = reaper.GetTrack(0, trackIndex)

    reaper.Undo_BeginBlock()
    -- Create send
    local sendIndex = reaper.CreateTrackSend(sourceTrack, targetTrack)

    if sendIndex < 0 then
        reaper.MB("ERROR: Failed to create send!", "ERROR", MB_TYPE.OK)
        return
    end

    local ROUTE_CATEGORY = { Receive = -1, Send = 0, HardwareOutput = 1 }

    -- Deactivate audio send
    local result = reaper.SetTrackSendInfo_Value(sourceTrack, ROUTE_CATEGORY.Send, sendIndex, "I_SRCCHAN", -1)
    if not result then
        reaper.MB("An error occurred when trying to disable audio send.", "ERROR", MB_TYPE.OK)
    end

    -- Send to chosen channel
    local flag = channel << 5
    debug("Selected channel flag: " .. print_binary(flag))
    result = reaper.SetTrackSendInfo_Value(sourceTrack, ROUTE_CATEGORY.Send, sendIndex, "I_MIDIFLAGS", flag)
    if not result then
        reaper.MB("An error occurred when trying to setup MIDI channel send.", "ERROR", MB_TYPE.OK)
    end
    reaper.MB("Send created!", "Success", MB_TYPE.OK)

    reaper.Undo_EndBlock("Created send on track " .. trackIndex + 1, 0)
    GUI.quit = true
end

GUI.req("Classes/Class - Textbox.lua")()
GUI.req("Classes/Class - Listbox.lua")()
GUI.req("Classes/Class - Button.lua")()
-- If any of the requested libraries weren't found, abort the script.
if missing_lib then return 0 end



GUI.name = "Send to instrument"
GUI.x, GUI.y, GUI.w, GUI.h = 0, 0, 300, 200
GUI.anchor, GUI.corner = "screen", "C"



GUI.New("ChannelTextBox", "Textbox", {
    z = 11,
    x = 80,
    y = 128,
    w = 48,
    h = 20,
    caption = "Channel",
    cap_pos = "left",
    font_a = 3,
    font_b = "monospace",
    color = "txt",
    bg = "wnd_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20
})

GUI.New("CreateSendButton", "Button", {
    z = 11,
    x = 80,
    y = 160,
    w = 96,
    h = 24,
    caption = "Create Send",
    font = 3,
    col_txt = "txt",
    col_fill = "elm_frame",
    func = create_send
})



local instrument_track_names = {}
for i = 1, #InstrumentTracks do
	instrument_track_names[i] = InstrumentTracks[i][1]
end


GUI.New("InstrumentsListBox", "Listbox", {
    z = 11,
    x = 80,
    y = 16,
    w = 192,
    h = 96,
    list = instrument_track_names,
    multi = false,
    caption = "Instruments",
    font_a = 3,
    font_b = 4,
    color = "txt",
    col_fill = "elm_fill",
    bg = "elm_bg",
    cap_bg = "wnd_bg",
    shadow = true,
    pad = 4
})


GUI.Init()
GUI.Main()
