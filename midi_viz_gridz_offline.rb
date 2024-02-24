# Midi note ticks to seconds with tempo support
#     req: tested with ruby 2.3.3
# install: bundle install
# 
# .:/ DiSCATTe \:.
#
# April 2022  (04/01/2022)

#   usage: bundle exec ruby thisfile.rb midi_file
require 'rubygems'
require 'bundler/setup'

require 'benchmark'
require 'ruby-prof'

require 'pry'
require 'oily_png'
#require 'chunky_png'
require 'midilib/sequence'
require 'progressbar'

seq = MIDI::Sequence.new
@seq = seq
File.open(ARGV[0], 'rb') { |file| seq.read(file) }


# testmidi3bar.mid
# M1 1 - 00:00 00:01
# M1 2 - 00:01 00:02
# M2 3 - 00:02 00:03
# M2 4 - 00:03 00:04
# M3 5 - 00:04 00:05
# M3 6 - 00:05 00:06


# testmidi3bar_tempo_120_60_30.mid
# M1 1 - 00:00 00:01
# M1 2 - 00:01 00:02
# M2 3 - 00:02 00:04
# M2 4 - 00:04 00:06
# M3 5 - 00:06 00:10
# M3 6 - 00:10 00:14


# testmidi3bar_tempo_120_60_30_middle_of_note.mid
# M1 1 - 00:00   00:01
# M1 2 - 00:01   00:02
# M2 3 - 00:02   00:03.5
# M2 4 - 00:03.5 00:05.5
# M3 5 - 00:05.5 00:08.5
# M3 6 - 00:08.5 00:12.5

# Variables #############################################
@target_fps   = 30  * 2
@note_falloff = 0.5 * 1.75
all_tempo_events = []
all_note_events  = []
all_events = []
@midi_zero = 1 # tracks 1 - 16


def scale_between(value, from_min, from_max, to_min, to_max)
	((to_max.to_f - to_min.to_f) * (value.to_f - from_min.to_f)) / (from_max.to_f - from_min.to_f) + to_min
end


@gm_instrument_names = {
# 1-8 Piano
1=>"Acoustic Grand Piano", 2=>"Bright Acoustic Piano", 3=>"Electric Grand Piano", 4=>"Honky-tonk Piano", 5=>"Electric Piano 1", 6=>"Electric Piano 2", 7=>"Harpsichord", 8=>"Clavi",
# 9-16 Chromatic Percussion
9=>"Celesta", 10=>"Glockenspiel", 11=>"Music Box", 12=>"Vibraphone", 13=>"Marimba", 14=>"Xylophone", 15=>"Tubular Bells", 16=>"Dulcimer",
# 17-24 Organ
17=>"Drawbar Organ", 18=>"Percussive Organ", 19=>"Rock Organ", 20=>"Church Organ", 21=>"Reed Organ", 22=>"Accordion", 23=>"Harmonica", 24=>"Tango Accordion",
# 25-32 Guitar
25=>"Acoustic Guitar (nylon)", 26=>"Acoustic Guitar (steel)", 27=>"Electric Guitar (jazz)", 28=>"Electric Guitar (clean)", 29=>"Electric Guitar (muted)", 30=>"Overdriven Guitar", 31=>"Distortion Guitar", 32=>"Guitar harmonics",
# 33-40 Bass
33=>"Acoustic Bass", 34=>"Electric Bass (finger)", 35=>"Electric Bass (pick)", 36=>"Fretless Bass", 37=>"Slap Bass 1", 38=>"Slap Bass 2", 39=>"Synth Bass 1", 40=>"Synth Bass 2",
# 41-48 Strings
41=>"Violin", 42=>"Viola", 43=>"Cello", 44=>"Contrabass", 45=>"Tremolo Strings", 46=>"Pizzicato Strings", 47=>"Orchestral Harp", 48=>"Timpani",
# 49-56 Ensemble
49=>"String Ensemble 1", 50=>"String Ensemble 2", 51=>"SynthStrings 1", 52=>"SynthStrings 2", 53=>"Choir Aahs", 54=>"Voice Oohs", 55=>"Synth Voice", 56=>"Orchestra Hit",
# 57-64 Brass
57=>"Trumpet", 58=>"Trombone", 59=>"Tuba", 60=>"Muted Trumpet", 61=>"French Horn", 62=>"Brass Section", 63=>"SynthBrass 1", 64=>"SynthBrass 2",
# 65-72 Reed
65=>"Soprano Sax", 66=>"Alto Sax", 67=>"Tenor Sax", 68=>"Baritone Sax", 69=>"Oboe", 70=>"English Horn", 71=>"Bassoon", 72=>"Clarinet",
# 73-80 Pipe
73=>"Piccolo", 74=>"Flute", 75=>"Recorder", 76=>"Pan Flute", 77=>"Blown Bottle", 78=>"Shakuhachi", 79=>"Whistle", 80=>"Ocarina",
# 81-88 Synth Lead
81=>"Lead 1 (square)", 82=>"Lead 2 (sawtooth)", 83=>"Lead 3 (calliope)", 84=>"Lead 4 (chiff)", 85=>"Lead 5 (charang)", 86=>"Lead 6 (voice)", 87=>"Lead 7 (fifths)", 88=>"Lead 8 (bass + lead)",
# 89-96 Synth Pad
89=>"Pad 1 (new age)", 90=>"Pad 2 (warm)", 91=>"Pad 3 (polysynth)", 92=>"Pad 4 (choir)", 93=>"Pad 5 (bowed)", 94=>"Pad 6 (metallic)", 95=>"Pad 7 (halo)", 96=>"Pad 8 (sweep)",
# 97-104 Synth Effects
97=>"FX 1 (rain)", 98=>"FX 2 (soundtrack)", 99=>"FX 3 (crystal)", 100=>"FX 4 (atmosphere)", 101=>"FX 5 (brightness)", 102=>"FX 6 (goblins)", 103=>"FX 7 (echoes)", 104=>"FX 8 (sci-fi)",
# 105-112 Ethnic
105=>"Sitar", 106=>"Banjo", 107=>"Shamisen", 108=>"Koto", 109=>"Kalimba", 110=>"Bag pipe", 111=>"Fiddle", 112=>"Shanai",
# 113-120 Percussive
113=>"Tinkle Bell", 114=>"Agogo", 115=>"Steel Drums", 116=>"Woodblock", 117=>"Taiko Drum", 118=>"Melodic Tom", 119=>"Synth Drum", 120=>"Reverse Cymbal",
# 121-128 Sound Effects
121=>"Guitar Fret Noise", 122=>"Breath Noise", 123=>"Seashore", 124=>"Bird Tweet", 125=>"Telephone Ring", 126=>"Helicopter", 127=>"Applause", 128=>"Gunshot"
}

# utility for midi instrument names
def pc_to_general_midi program_change
	@gm_instrument_names[program_change+1] || program_change
end


@gm_drum_names = {
35=>"Acoustic Bass Drum", 36=>"Bass Drum 1", 37=>"Side Stick", 38=>"Acoustic Snare", 39=>"Hand Clap", 40=>"Electric Snare", 41=>"Low Floor Tom", 42=>"Closed Hi Hat", 43=>"High Floor Tom", 44=>"Pedal Hi-Hat", 45=>"Low Tom", 46=>"Open Hi-Hat", 47=>"Low-Mid Tom", 48=>"Hi-Mid Tom", 49=>"Crash Cymbal 1", 50=>"High Tom", 51=>"Ride Cymbal 1", 52=>"Chinese Cymbal", 53=>"Ride Bell", 54=>"Tambourine", 55=>"Splash Cymbal", 56=>"Cowbell", 57=>"Crash Cymbal 2", 58=>"Vibraslap", 59=>"Ride Cymbal 2", 60=>"Hi Bongo", 61=>"Low Bongo", 62=>"Mute Hi Conga", 63=>"Open Hi Conga", 64=>"Low Conga", 65=>"High Timbale", 66=>"Low Timbale", 67=>"High Agogo", 68=>"Low Agogo", 69=>"Cabasa", 70=>"Maracas", 71=>"Short Whistle", 72=>"Long Whistle", 73=>"Short Guiro", 74=>"Long Guiro", 75=>"Claves", 76=>"Hi Wood Block", 77=>"Low Wood Block", 78=>"Mute Cuica", 79=>"Open Cuica", 80=>"Mute Triangle", 81=>"Open Triangle"
}

# utility for midi drum names
def drum_note_to_general_midi drum_note
	@gm_drum_names[drum_note] || drum_note
end

@cc_names = {
0=>"Bank Select (MSB)",
1=>"Modulation Wheel (MSB)",
2=>"Breath Controller (MSB)",

4=>"Foot Controller (MSB)",
5=>"Portamento Time (MSB)",
6=>"Data Entry (MSB)",
7=>"Channel Volume (MSB)",
8=>"Balance (MSB)",

10=>"Pan (MSB)",
11=>"Expression (MSB)",
12=>"Effect Control 1 (MSB)",
13=>"Effect Control 2 (MSB)",

16=>"General Purpose Controller 1 (MSB)",
17=>"General Purpose Controller 2 (MSB)",
18=>"General Purpose Controller 3 (MSB)",
19=>"General Purpose Controller 4 (MSB)",

32=>"Bank Select (LSB)",
33=>"Modulation Wheel (LSB)",
34=>"Breath Controller (LSB)",

36=>"Foot Controller (LSB)",
37=>"Portamento Time (LSB)",
38=>"Data Entry (LSB)",
39=>"Channel Volume (LSB)",
40=>"Balance (LSB)",

42=>"Pan (LSB)",
43=>"Expression (LSB)",
44=>"Effect Control 1 (LSB)",
45=>"Effect Control 2 (LSB)",

48=>"General Purpose Controller 1 (LSB)",
49=>"General Purpose Controller 2 (LSB)",
50=>"General Purpose Controller 3 (LSB)",
51=>"General Purpose Controller 4 (LSB)",

64=>"Sustain Pedal",
65=>"Portamento On/Off",
66=>"Sostenuto",
67=>"Soft Pedal",
68=>"Legato Footswitch",
69=>"Hold 2",
70=>"Sound Controller 1 (Sound Variation)",
71=>"Sound Controller 2 (Timbre / Harmonic Quality)",
72=>"Sound Controller 3 (Release Time)",
73=>"Sound Controller 4 (Attack Time)",
74=>"Sound Controller 5 (Brightness)",
75=>"Sound Controller 6 (GM2 default: Decay Time)",
76=>"Sound Controller 7 (GM2 default: Vibrato Rate)",
77=>"Sound Controller 8 (GM2 default: Vibrato Depth)",
78=>"Sound Controller 9 (GM2 default: Vibrato Delay)",
79=>"Sound Controller 10 (GM2 default: Undefined)",
80=>"General Purpose Controller 5",
81=>"General Purpose Controller 6",
82=>"General Purpose Controller 7",
83=>"General Purpose Controller 8",
84=>"Portamento Control",

91=>"Effects 1 Depth (Reverb Send)",
92=>"Effects 2 Depth (Tremolo Depth)",
93=>"Effects 3 Depth (Chorus Send)",
94=>"Effects 4 Depth (Celeste Depth)",
95=>"Effects 5 Depth (Phaser Depth)",
96=>"Data Increment",
97=>"Data Decrement",
98=>"NRPN (LSB)",
99=>"NRPN (MSB)",
100=>"RPN (LSB)",
101=>"RPN (MSB)",

120=>"All Sound Off",
121=>"Reset All Controllers",
122=>"Local Control On/Off",
123=>"All Notes Off",
124=>"Omni Mode Off",
125=>"Omni Mode On",
126=>"Poly Mode Off",
127=>"Poly Mode On"
}

def cc_to_name cc_number
	@cc_names[cc_number] || cc_number 
end


# full summary
def full_summary seq
seq.each_with_index do |track, track_index|
	puts "TRACK [%02d] EVENTS:%d" % [track_index, track.to_a.length]
	track_events = track.events.group_by{|e| e.class.name}
	track_events_count = track_events.keys.sort.collect{|key| "#{key.gsub("MIDI::","")}:#{track_events[key].length}"}.join(", ")
	puts " \\SUMMARY %s" % track_events_count
	
	cc_events = track.events.select{|e| e.is_a? MIDI::Controller}
	cc_by_cont = cc_events.group_by{|c| c.controller}
	cc_count = cc_by_cont.keys.sort.collect{|controller| [controller, cc_to_name(controller),cc_by_cont[controller].length]}

	count_length = cc_count.collect{|c| c.last}.max.to_s.length
	cc_count.each_with_index do |cc_info, index|
		cc_header = index == 0 ? " \\CC#" : "     "
		puts "%s  %#{count_length}d:[%3d] %s" % [cc_header, cc_info[2], cc_info[0], cc_info[1]]
	end
end
end


# XG mode detection
@file_is_xg = false
def xg_detect seq

seq.each_with_index do |track, track_index|	
	sysex_events = track.events.select{|e| e.is_a? MIDI::SystemExclusive}.each do |sysex|
	    sysex_start = 0xF0
		sysex_end   = 0xF7
	    xg_on_sysex = [sysex_start, 0x43, "1n", 0x4C, 0x00, 0x00, 0x7E, 0x00, sysex_end] 
		
		matches = 0
		
		sysex.data.each_with_index do |byte, index|
			if (byte == xg_on_sysex[index]) || (xg_on_sysex[index].is_a? String)
				matches += 1
			end
		end
		
		if matches == xg_on_sysex.length
			puts "!!! <XG> MODE ON !!!"
			@file_is_xg = true
			
			break
		end
	end
end
end


# tidy summary and some event organization, file type hacks

@drum_channels = {9=>true}
def summary_and_event_sort seq, all_tempo_events, all_note_events, all_events
# Debug output and extract tempos and note from tracks
  puts "-"*20
  puts "File Summary"
  puts "SEQ PPQN:#{seq.ppqn} TRACKS:#{seq.to_a.length}"

  seq.each_with_index do |track, track_index|	
	puts "TRACK [%02d] EVENTS:%d NAME: \"%s\"" % [track_index, track.to_a.length, track.name]
	

	tempo_events = track.events.select{|e| e.is_a? MIDI::Tempo}
	tempo_events.each do |tempo|
		all_tempo_events.push tempo
	end
	
	# Debug Tempo on TRACK
	tempo_events.each do |tempo_event|
		puts " \\TEMPO %8d BPM: %3d" % [tempo_event.data, MIDI::Tempo.mpq_to_bpm(tempo_event.data)]
	end
	
	track.events.select{|e| e.is_a? MIDI::Marker }.each do |marker|
		puts " \\MARKER [%s]" % marker.data_as_str
	end
	
	track.events.select{|e| e.is_a? MIDI::KeySig }.each do |keysig|
		puts " \\KEYSIG [%s]" % keysig.to_s
	end	
	
	track.events.select{|e| e.is_a? MIDI::TimeSig }.each do |timesig|
		puts " \\TIMESIG [%s]" % timesig.to_s
	end		

	
	if @file_is_xg
		# Hacky XG Bank Drum mode check (we just care that its a drum track)
		control_events = track.events.select{|e| e.is_a? MIDI::Controller}
		cc0_events = control_events.select{|c| c.controller == 0}
		cc0_events.each do |c|
			if    c.value == 127
				@drum_channels[c.channel] = true
			elsif c.value == 0
				@drum_channels[c.channel] = false
			end
		end
	end
		

	# Debug Program Change Summary
    programs_hash = track.events.select{|e| e.is_a? MIDI::ProgramChange}.group_by{|e| e.channel}
	programs_hash.keys.sort.each do |key|
		chan_programs = programs_hash[key].map{|e| e.program}
		if @drum_channels[key]
			programs_used = chan_programs.uniq.map{|prog_number| "Drum Kit (#{prog_number})"}.join(",")
		else
			programs_used = chan_programs.uniq.map{|prog_number| pc_to_general_midi prog_number }.join(",")
		end
		puts " \\CHAN[%02d] PROGS:%3d <%s>" %
		[key+@midi_zero, chan_programs.length, programs_used]
	end

	notes = track.events.select{|e| e.is_a?(MIDI::NoteEvent) || e.is_a?(MIDI::PitchBend) || (e.is_a?(MIDI::Controller) && e.controller == 1) }
	notes.each do |note|
		all_note_events.push note
	end
	
	# fix for files where last event isnt a note
	track.events.each{|e| all_events.push e}
	
	# Debug Channel Notes Summary
	event_count_length = track.to_a.length.to_s.length
	notes_hash = notes.select{|e| e.is_a?(MIDI::NoteEvent) && e.respond_to?(:channel)}.group_by{|e| e.channel}
	notes_hash.keys.sort.each do |key|
		chan_notes = notes_hash[key].map{|e| e.note}
		if @drum_channels[key]
			notes_used = chan_notes.uniq.map{|note_number| drum_note_to_general_midi note_number }.join(",")
		else
			notes_used = chan_notes.uniq.map{|note_number| MIDI::Utils.note_to_s note_number }.join(",")
		end
		puts " \\CHAN[%02d] NOTES:%#{event_count_length}d (%3s-%3s) [%3d] <%s>" %
		[key+@midi_zero, chan_notes.length, MIDI::Utils.note_to_s(chan_notes.min), MIDI::Utils.note_to_s(chan_notes.max), chan_notes.uniq.length,notes_used]
	end

  end
  puts "-"*20

  # not sure if needed for tempo, but notes would be from different tracks interleaved

  all_note_events.sort!#_by{|e| e.time_from_start}
  all_tempo_events.sort!#_by{|e| e.time_from_start}

  # last event fix
  all_events.sort!#_by{|e| e.time_from_start}

  #binding.pry

end # summary and prep


# Calculate seconds given a duration of ticks and a bpm ##############################################

def ticks_to_seconds(ticks, bpm)
	(ticks.to_f / @seq.ppqn.to_f / bpm.to_f) * 60
end

# Build tempo ranges out of tempo pairs, and the last event in the files tick time ###################
@last_event = nil
@tempo_ranges = []
def build_tempo_map_and_song_length seq, all_tempo_events
	puts "Tempo to seconds map"
	@last_event = seq.tracks.collect{|track| track.events}.flatten.sort.last
	all_tempo_events.push @last_event

	@tempo_ranges = []
	tempo_elapsed_seconds = 0.0
	# iterate in overlap pairs [0,1] [1,2] [2,3] etc
	all_tempo_events.each_cons(2) do |tempos|
		curr_tempo = tempos[0]
		next_tempo = tempos[1]
		
		tempo_bpm = 60_000_000.0/curr_tempo.data
		
		tempo_duration_ticks = next_tempo.time_from_start - curr_tempo.time_from_start
		
		tempo_duration_seconds = ticks_to_seconds(tempo_duration_ticks, tempo_bpm)
		
		tempo_object  = {start_tick: curr_tempo.time_from_start,
						   end_tick: next_tempo.time_from_start,
								bpm: tempo_bpm,
					  start_seconds: tempo_elapsed_seconds,
				   duration_seconds: tempo_duration_seconds,
						end_seconds: tempo_elapsed_seconds + tempo_duration_seconds}
		@tempo_ranges.push tempo_object
		
		tempo_elapsed_seconds += tempo_duration_seconds
	end

	# float string formatting "tricks"
	tick_str_size = @tempo_ranges.last[:end_tick].to_s.length
	secs_str_size = ("%0.4f" % [@tempo_ranges.last[:end_seconds]]).length

	# debug output
	@tempo_ranges.each do |tempo_range|
		puts "TEMPO BPM:%3d  START: %#{tick_str_size}d/%#{secs_str_size}s  END: %#{tick_str_size}d/%#{secs_str_size}s  DURATION: %#{secs_str_size}s" %
		[tempo_range[:bpm],
		 tempo_range[:start_tick],
		 "%0.4f" % tempo_range[:start_seconds],
		 tempo_range[:end_tick],
		 "%0.4f" % tempo_range[:end_seconds],
		 "%0.4f" % tempo_range[:duration_seconds]
		]
	end
end # build tempos


class MIDI::Event
	attr_accessor :absolute_seconds
end

# Show absolute time in seconds for each note event ##########################################

def get_event_absolute_time event
	last_tempo_range = @tempo_ranges.select do |tempo_range|
		tempo_range[:start_tick] <= event.time_from_start
	end.last
	
	ticks_since_tempo      = event.time_from_start - last_tempo_range[:start_tick]
	event_start_seconds    = ticks_to_seconds(ticks_since_tempo, last_tempo_range[:bpm])
	event_absolute_seconds = event_start_seconds + last_tempo_range[:start_seconds]
	
	event.absolute_seconds = event_absolute_seconds
	if(event.is_a?(MIDI::NoteEvent))
		#puts "NOTE %3s (%3d) CH:%02d TIME:%6d/%7s" % [ MIDI::Utils.note_to_s(event.note), event.note, event.channel, event.time_from_start, "%0.4f" % event_absolute_seconds]
	end
end

def get_all_absolute_times all_events #all_note_events
	#all_note_events
	all_events.each do |note|
		get_event_absolute_time note
	end
end


@note_histogram  = Array.new(16) {Array.new(128) { 8 }} # 8 for visual grid


@note_grid_state = Array.new(16) {Array.new(128) { 0 }} # (rand*128).to_i }} # test values
@note_on_state   = Array.new(16) {Array.new(128) { false }}

@note_mod_state  = Array.new(16) { 0    } # 0 - 127
@note_bend_state = Array.new(16) { 8192 } # 0 - 8192 - 16383

# TODO calculate this outside framerate based rendering (otherwise it clumps time)
@max_polyphony = 0
@cur_polyphony = 0

# instantanous values
@channel_velocity = Array.new(16) { 0 }
@global_velocity  = 0
@note_velo_state  = Array.new(16) {Array.new(128) { 0 }}

def update_grid_state all_note_events, percent
	time = @last_event.absolute_seconds * percent
	
	if all_note_events.empty?
		return # GOODNIGHT SUGAH
	end
	
	event_time = all_note_events.first.absolute_seconds
	
	while event_time <= time
		event = all_note_events.shift
		
		if event.is_a? MIDI::NoteOn
			@note_on_state  [event.channel][event.note] = true
			@note_grid_state[event.channel][event.note] = event.velocity * 2 # for 256 value smooth fadout

			@note_velo_state[event.channel][event.note] = event.velocity
			
		elsif event.is_a? MIDI::NoteOff
			@note_on_state  [event.channel][event.note] = false
			
			@note_velo_state[event.channel][event.note] = 0
			
		elsif event.is_a? MIDI::PitchBend
			@note_bend_state[event.channel] = event.value
			
		elsif event.is_a?(MIDI::Controller) && event.controller == 1
			@note_mod_state [event.channel] = event.value
			
		end

		if all_note_events.empty?
	        return #BYE BYE"
		end
		
		event_time = all_note_events.first.absolute_seconds
	end

    #@global_velocity = @note_grid_state.flatten.max
	@global_velocity = @note_velo_state.flatten.max

	# naive count vs simulated period of overlap
	#@cur_polyphony = @note_on_state.flatten.count(true)
	@cur_polyphony = @note_grid_state.flatten.select{|velocity| velocity > 10}.count
	#puts "POLY [%3d]" % @cur_polyphony
	if @cur_polyphony > @max_polyphony
		@max_polyphony = @cur_polyphony
	end
end

def grid_falloff
	@note_grid_state.each_with_index do |channel_row, row_i|
		channel_row.each_with_index do |note_val, col_i|
			if @note_on_state[row_i][col_i] == false
				@note_grid_state[row_i][col_i] *= @note_falloff
			end
		end
	end
end

# draws the 'grid' as well using value 1
def get_note_histogram all_note_events
	all_note_events.each do |note|
		if(note.is_a? MIDI::NoteOn)
			@note_histogram[note.channel][note.note] += 1
		end
	end
	
	max_count = @note_histogram.collect{|chan| chan.max}
	puts "MAX NOTES #{max_count}"
	
	# rescale
	@note_histogram.each_with_index do |channel_row, row_i|
		channel_row.each_with_index do |note_count, col_i|
			channel_row[col_i] = scale_between(note_count, 0, max_count, 0, 127*2)
		end
	end
end


@note_sprites = Array.new(128)
@drum_sprites = Array.new(128)
@titlecard = nil
@digi_sprites = Array.new(10)
@digisep = nil
@bground = nil

@cvu_sprites = Array.new(16)
@gvu_sprites = Array.new(16)

def load_note_sprites
    print "Loading note sprites..."

    tile_image_names = Dir.glob(File.join("sprites", "midi_sprites","note_rect*.png"))

    tile_image_names.sort.each_with_index do |name, index|
      @note_sprites[index] = ChunkyPNG::Image.from_file(name)
	end
	
    tile_image_names = Dir.glob(File.join("sprites", "midi_sprites","drum_rect*.png"))

    tile_image_names.sort.each_with_index do |name, index|
      @drum_sprites[index] = ChunkyPNG::Image.from_file(name)
	end
	
    digi_image_names = Dir.glob(File.join("sprites", "midi_sprites","dig*.png"))

    digi_image_names.sort.each_with_index do |name, index|
      @digi_sprites[index] = ChunkyPNG::Image.from_file(name)
	end
	
    cvu_image_names = Dir.glob(File.join("sprites", "midi_sprites","cvu*.png"))

    cvu_image_names.sort.each_with_index do |name, index|
      @cvu_sprites[index] = ChunkyPNG::Image.from_file(name)
	end
	
    gvu_image_names = Dir.glob(File.join("sprites", "midi_sprites","gvu*.png"))

    gvu_image_names.sort.each_with_index do |name, index|
      @gvu_sprites[index] = ChunkyPNG::Image.from_file(name)
	end	

	@beatup    = ChunkyPNG::Image.from_file File.join("sprites", "midi_sprites", "beat-up.png")
	@beatdown  = ChunkyPNG::Image.from_file File.join("sprites", "midi_sprites", "beat-down.png")
	@beatoff   = ChunkyPNG::Image.from_file File.join("sprites", "midi_sprites", "beat-off.png")
	
	@titlecard = ChunkyPNG::Image.from_file File.join("sprites", "midi_sprites", "titlecard.png")
	@digisep   = ChunkyPNG::Image.from_file File.join("sprites", "midi_sprites", "disep.png")
	
	#@bground   = ChunkyPNG::Image.from_file File.join("sprites", "midi_sprites", "bg.png")
end



def rect(canvas, x0, y0, x1, y1, stroke_color = ChunkyPNG::Color::BLACK, fill_color = ChunkyPNG::Color::TRANSPARENT)

  fill_color   = ChunkyPNG::Color.parse(fill_color)

  # Fill
  unless fill_color == ChunkyPNG::Color::TRANSPARENT
    [x0, x1].min.upto([x0, x1].max) do |x|
      [y0, y1].min.upto([y0, y1].max) do |y|
        canvas.compose_pixel(x, y, fill_color)
      end
    end
  end
end

@white_clear = ChunkyPNG.Color(255, 255, 255, 0)

def draw_bg
	note_width   =   8
	note_height  =   8 * 3
	note_pad     =   2
	chan_pad     =   3
	jelly_pad_h  =  62
	jelly_pad_w  =  20
	note_area_h  =  16 * (note_height+chan_pad) #-4 for rinbu
	note_area_w  = 128 * (note_width +note_pad)
	jelly_height = note_area_h + jelly_pad_h * 2
	jelly_width  = note_area_w + jelly_pad_w * 2
	pad_border   = 6
	
    vertical_off = 30+42

	#bg_purpleblue = ChunkyPNG.Color(50,50,100)
	#bg_blackish = ChunkyPNG.Color(20,20,20)
	#bg_pinkish = ChunkyPNG.Color(255, 128, 166)
	#bg_rose = ChunkyPNG.Color(255,98,145)
	#bg_clear = ChunkyPNG::Color::TRANSPARENT
	#bg_clear = @white_clear # rinbu composite
	
	bg_color = ChunkyPNG.Color(50,0,100)
	
	#puts "JELLYSPACE: w#{jelly_width}-h#{jelly_height}"
	jellyspace  = ChunkyPNG::Canvas.new jelly_width, jelly_height+42, bg_color #h+10
#	jellyspace.compose! @bground, 0, 0
	
	pad_x1 = jelly_pad_w-pad_border
	pad_y1 = jelly_pad_h-pad_border+vertical_off
	pad_x2 = note_area_w+jelly_pad_w+pad_border
	pad_y2 = note_area_h+jelly_pad_h+pad_border+vertical_off
	
	jellyspace.rect pad_x1, pad_y1, pad_x2, pad_y2, ChunkyPNG::Color::TRANSPARENT,ChunkyPNG.Color(255,255,255,4)
#=begin
	@note_histogram.each_with_index do |channel_row, row_i|
		channel_row.each_with_index do |note_val, col_i|
			x1 = col_i * (note_width  + note_pad) + jelly_pad_w
			y1 = row_i * (note_height + chan_pad) + jelly_pad_h+vertical_off

			if(@drum_channels[row_i])
				sprite = @drum_sprites[note_val]
			else
				sprite = @note_sprites[note_val]
			end
			jellyspace.compose! sprite, x1, y1
		end
	end
#=end

	jellyspace.compose! @titlecard, 13,0

	jellyspace
end

def draw_time seconds
	digispace = ChunkyPNG::Canvas.new (38*4*2)+10*2, 23*2
	
	minutes = seconds/60
	m_ten   = minutes/10
	m_one   = minutes%10
	remains = seconds%60
	s_ten   = remains/10
	s_one   = remains%10
	
	spacer = 38*2
	cursor = 0
	digispace.compose @digi_sprites[m_ten], cursor, 0
	cursor+=spacer
	digispace.compose @digi_sprites[m_one], cursor, 0
	cursor+=spacer
	digispace.compose @digisep, cursor, 0
	cursor+=10*2
	digispace.compose @digi_sprites[s_ten], cursor, 0
	cursor+=spacer
	digispace.compose @digi_sprites[s_one], cursor, 0
	cursor+=spacer
	
	digispace
end

def draw_polyphony
    
end

def draw_global_vu_meter
end

def draw_channel_vu_meters
    # 20 x 46

end

def draw_beat_pulse
    # 34 x 34
end

def draw_midi_frame jelly_bg, percent
	note_width   =   8
	note_height  =   8 * 3
	note_pad     =   2
	chan_pad     =   3
	jelly_pad_h  =  62
	jelly_pad_w  =  20
	jelly_height =  16 * (note_height+chan_pad) + jelly_pad_h * 2 #-4 rinbu
	jelly_width  = 128 * (note_width +note_pad) + jelly_pad_w * 2
	
	vertical_off = 30

#nodraw
	jellyspace  = ChunkyPNG::Canvas.new jelly_width, jelly_height, @white_clear#, ChunkyPNG.Color(50,50,100)

	@note_grid_state.each_with_index do |channel_row, row_i|
		channel_row.each_with_index do |note_val, col_i|
			x1 = col_i * (note_width  + note_pad) + jelly_pad_w
			y1 = row_i * (note_height + chan_pad) + jelly_pad_h + vertical_off
			bend_offset = scale_between(@note_bend_state[row_i],0,8192*2,-20,20).to_i
			 mod_offset = scale_between(@note_mod_state [row_i],0,127,0,12     ).to_i

			x1 = x1 + bend_offset
			y1 = y1 -  mod_offset
			
			if(@drum_channels[row_i])
				sprite = @drum_sprites[note_val]
			else
				sprite = @note_sprites[note_val]
			end
#nodraw			
			jellyspace.compose! sprite, x1, y1
		end
	end
#nodraw	
	jellyspace
end

# benchmark
# 6:25 - 320 (385) 2.3.3 - from_canvas
# 6:40 - 363 (400) 2.3.3 - replace and compose
# 5:14 - 289 (314) 2.7.5 - replace and compose
# 4:53 - 267 (293) 3.1.1 - replace and compose

def make_pixel_animation all_note_events
	note_width   =   8
	note_height  =   8 * 3
	note_pad     =   2
	chan_pad     =   3
	jelly_pad_h  =  62
	jelly_pad_w  =  20
	jelly_height =  16 * (note_height+chan_pad) + jelly_pad_h * 2
	jelly_width  = 128 * (note_width +note_pad) + jelly_pad_w * 2

#Benchmark.bm( 20 ) do |bench|
#bench.report("FRAME RENDERING") do


	frame_count  = (@last_event.absolute_seconds * @target_fps).to_i
	total_time   =  @last_event.absolute_seconds
	
	format = "%t: |%b %p%% => %i| %c/%C [%a|%e]"
    bar = ProgressBar.create title:"#{frame_count} Frames", total:frame_count, format: format
	
	jelly_bg = draw_bg

#RubyProf.start
	frame_count.times do |frame_num|

		percent = frame_num / frame_count.to_f
		seconds = (total_time * percent).to_i
		
		jellytime = draw_time seconds
		
		# # main magic # #
		update_grid_state all_note_events, percent
		
		#if(frame_num > 100 && frame_num < 1100)
		#### jelly_bg   = draw_bg
		jellyspace = draw_midi_frame jelly_bg, percent
		
		
		jellybeats = draw_beat_pulse
		jellymeats = draw_channel_vu_meters
		
		# # # # # # # # #
		
		# using from_canvas wasn't working, building up data?
begin		
		jelly_comp  = ChunkyPNG::Image.new jelly_width, jelly_height+42, @white_clear
		jelly_comp.replace! jelly_bg,   0,0
		jelly_comp.compose! jellyspace, 0,0+42
		jelly_comp.compose! jellytime, jelly_width-(jelly_width/2)-(((38*2*4)+10*2)/2), 22+22+28
		
		jelly_name = "testmidi-gridz#{frame_num.to_s.rjust(6, "0")}.png"
		jelly_comp.save File.join("frames", jelly_name), color_mode: ChunkyPNG::COLOR_TRUECOLOR_ALPHA
		#end # if frame_num
end
		
		grid_falloff
		bar.increment
		
	end #frame count loop
	
	bar.finish
	
	puts "MAX POLYPHONY #{@max_polyphony}"
	
#profile = RubyProf.stop
#printer = RubyProf::GraphHtmlPrinter.new(profile)
#File.open("profile_data.html", 'w') { |file| printer.print(file) }
	

#end # bench report
#end # bench	

end # make animation


# MAIN ######################################

                   full_summary( seq )

                      xg_detect( seq )
         summary_and_event_sort( seq, all_tempo_events, all_note_events, all_events )
build_tempo_map_and_song_length( seq, all_tempo_events )
         get_all_absolute_times( all_events ) #all_note_events )
			 #get_note_histogram( all_note_events )

			  load_note_sprites
		   make_pixel_animation( all_note_events )	