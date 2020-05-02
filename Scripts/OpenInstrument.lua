-- Opens the instrument associated with the selected track
-- Algorithm is:
-- If the selected track has an instrument, opens that instrument.
-- Otherwise it examines the track's MIDI sends and recursively calls "OpenInstrument" with them.

-- v2: Recursively obtains all instruments this track could feed MIDI into, show them in a listbox to choose which ones to open.
-- If it is only one, it opens it directly.


DEBUG = false

ROUTE_CATEGORY = { Receive = -1, Send = 0, HardwareOutput = 1 }
ROUTE_PARAM_NAME = {
    Mute = "B_MUTE",
    Phase = "B_PHASE",
    Mono = "B_MONO",
    Volume = "D_VOL",
    Pan = "D_PAN",
    PanLaw = "D_PANLAW",
    SendMode = "I_SENDMODE",
    AutoMode = "I_AUTOMODE",
    SourceChannel = "I_SRCCHAN",
    DestChannel = "I_DSTCHAN",
    MidiFlags = "I_MIDIFLAGS",
    SourceTrack = "P_SRCTRACK",
    DestTrack = "P_DESTTRACK",
    Envelope = "P_ENV",
}
TRACKFX_SHOW = { HideChain = 0, ShowChain = 1, HideFloating = 2, ShowFloating = 3 }


function debug(msg)
    if (DEBUG) then
        reaper.ShowConsoleMsg(msg .. "\n")
    end
end

local function open_instrument(track, instrumentIndex)
    reaper.TrackFX_Show(track, instrumentIndex, TRACKFX_SHOW.ShowFloating)
end

local function search_instruments(track)
    local trackIndex = reaper.CSurf_TrackToID(track, false)
    local _, trackName = reaper.GetTrackName(track)
    local trackDesc = trackIndex .. ". " .. trackName
    debug("Searching track " .. trackDesc)
    local instrumentIndex = reaper.TrackFX_GetInstrument(track)
    if instrumentIndex ~= -1 then
        debug("Track " .. trackDesc .. " has instrument!")
        return { { Track = track, InstrumentIndex = instrumentIndex } }
    else
        debug("Track " .. trackDesc .. " has no instrument")
    end

    local trackSends = reaper.GetTrackNumSends(track, ROUTE_CATEGORY.Send)
    local midiSendFound = false
    local dependantInstruments = {}
    for sendIndex = 0, trackSends - 1, 1 do
        local midiFlags = reaper.GetTrackSendInfo_Value(track, ROUTE_CATEGORY.Send, sendIndex, ROUTE_PARAM_NAME.MidiFlags)
        if midiFlags then
            midiSendFound = true
            local target = reaper.GetTrackSendInfo_Value(track, ROUTE_CATEGORY.Send, sendIndex, ROUTE_PARAM_NAME.DestTrack)
            local dependantInstrumentsOfSend = search_instruments(target)
            for _, instrument in pairs(dependantInstrumentsOfSend) do
                table.insert(dependantInstruments, instrument)
            end
        end
    end

    if not midiSendFound then
        debug("Track " .. trackDesc .. " does not have MIDI sends")
    end

    return dependantInstruments
end

local selectedTrack = reaper.GetSelectedTrack(0, 0)

local instruments = search_instruments(selectedTrack)

for _, instrument in pairs(instruments) do
    open_instrument(instrument.Track, instrument.InstrumentIndex)
end

