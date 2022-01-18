# rewrite the parsing to get more information / move file parser to a secondary file

class Map
    attr_accessor :notes, :columns, :title, :artist, :creator, :version, :audio_filename, :audio_offset, :end_event, :game_mode, :source_folder, :beatmap_set_id, :background_image

    def initialize(notes, columns, title, artist, creator, version, audio_filename, audio_offset, end_event, game_mode, source_folder, beatmap_set_id, background_image)
        @columns = columns
		@notes = notes
		@title = title
		@artist = artist
		@creator = creator
		@version = version
		@audio_filename = audio_filename
		@audio_offset = audio_offset
		@end_event = end_event
		@game_mode = game_mode
		@source_folder = source_folder
		@beatmap_set_id = beatmap_set_id
		@background_image = background_image
    end

	def print_info()
		puts("Artist: #{@artist}")
		puts("Title: #{@title}")
		puts("Creator: #{@creator}")
		puts("Version: #{@version}")
		puts("BeatmapSetID: #{@beatmap_set_id}")
		puts("Source Folder: #{@source_folder}")
		puts("Audio Filename: #{@audio_filename}")
		puts("Audio Offset: #{@audio_offset}ms")
		puts("Background Image: #{@background_image}")
		puts("Map Length: #{@end_event}ms")
		puts("Mode: #{@game_mode}")
		puts("Columns: #{@columns}")
		puts("Notes: #{@notes.length}")
	end

	def print_map()
        print_info()
		
        for note in @notes
            note.print_data()
        end
    end
end

class Note
    attr_accessor :type, :column, :start_time, :end_time, :id

    def initialize(id, type, column, start_time, end_time=nil)
        @id = id
        @type = type
        @column = column
        @start_time = start_time
        @end_time = end_time
    end

    def print_data()
        if @type == "hold"
            suffix = ", end_time: #{@end_time}ms"
        end
        puts("Note ID is #{@id}, type: #{@type}, column: #{@column}, start_time: #{@start_time}ms#{suffix}")
    end
end

def create_map(data)
    
	notes_data = data['notes_data']
	columns = data['columns']
    column_width = data['column_width']
    game_mode = data['game_mode']
    title = data['title']
    artist = data['artist']
    creator = data['creator']
    version = data['version']
    audio_filename = data['audio_filename']
	audio_offset = data['audio_offset']
	end_event = data['end_event']
	source_folder = data['source_folder']
	beatmap_set_id = data['beatmap_set_id']
	background_image = data['background_image']
	
	notes = []
	
	id = 1

    for note_data in notes_data
        if note_data[1] > columns #note exists in a column that doesn't exist, changing column number to reflect that.
            columns = note_data[1]
        end
        if note_data[0] == "hold" # a hold note with an end time
            note = Note.new(id, note_data[0],note_data[1],note_data[2],note_data[3])
        else # a tap note (no end time)
            note = Note.new(id, note_data[0],note_data[1],note_data[2])
        end
		notes << note
		id += 1
    end

	if background_image != nil
		background_image = source_folder + background_image
	end

    map = Map.new(notes, columns, title, artist, creator, version, audio_filename, audio_offset, end_event, game_mode, source_folder, beatmap_set_id, background_image)

    return map
end

def get_key_value_from_line(line)
    setting_data = line.split(":")

    setting_name = setting_data[0].strip
    setting_value = setting_data[1..-1].join(":").strip
    
    return [setting_name, setting_value]
end

def process_line(data, line, flag) # refactor this because it is not nice, maybe have a function for each flag with an appropriate name
	line = line.chomp
	if line != ""
		if flag == 1
			key_value = get_key_value_from_line(line)
			
			setting_name = key_value[0]
			setting_value = key_value[1]

			if setting_name == "AudioFilename"
				data['audio_filename'] = setting_value
			elsif setting_name == "AudioLeadIn"
				data['audio_offset'] = setting_value
			elsif setting_name == "Mode"
				data['game_mode'] = setting_value
			end
		elsif flag == 2
		elsif flag == 3
			key_value = get_key_value_from_line(line)
			
			setting_name = key_value[0]
			setting_value = key_value[1]

			if setting_name == "Title"
				data['title'] = setting_value
			elsif setting_name == "Artist"
				data['artist'] = setting_value
			elsif setting_name == "Creator"
				data['creator'] = setting_value
			elsif setting_name == "Version"
				data['version'] = setting_value
			elsif setting_name == "BeatmapSetID"
				data['beatmap_set_id'] = setting_value
			end
		elsif flag == 4  # line should be about difficulty settings
			key_value = get_key_value_from_line(line)

			setting_name = key_value[0]
			setting_value = key_value[1]

			if setting_name == "CircleSize"
				data['columns'] = setting_value.to_i # change columns
				data['column_width'] = (512 / data['columns']).floor # recalculate column width
			end
		elsif flag == 5
			if line.start_with?('0,0,"') # probably the background image
				data['background_image'] = line.split('"')[1]
			end
		elsif flag == 6
		elsif flag == 7
		elsif flag == 8  # line should be note data
			line_data = line.split(",")
			x = line_data[0].to_f
			#y = line_data[1]
			start_time = line_data[2]
			type = line_data[3]
			#hitsound = line_data[4]
			column = ((x / data['column_width'])).floor
			if column >= data['columns']
				column = data['columns'] - 1
			end
			#puts(x,column_width,column)
			if type == "128"
				line_data_extra = line_data[5].split(":")
				end_time = line_data_extra[0]
				type = "hold"
				#extras = line_data_extra[1..-1]
				data['notes_data'] << [type, column, start_time, end_time]
			elsif type != 8 # do not include 'spinners'
				type = "tap"
				data['notes_data'] << [type, column, start_time]
			end
		end
		if line == "[General]"
			flag = 1
		elsif line == "[Editor]"
			flag = 2
		elsif line == "[Metadata]"
			flag = 3
		elsif line == "[Difficulty]"
			flag = 4
		elsif line == "[Events]"
			flag = 5
		elsif line == "[TimingPoints]"
			flag = 6
		elsif line == "[Colours]"
			flag = 7
		elsif line == "[Notes]" or line == "[HitObjects]"
			flag = 8
		end
	end

	return [data, flag]
end

def read_map(file_location)
    file = File.new(file_location)
    
    columns = 4 # default columns
    column_width = (512 / columns).floor
	
	source_folder = file_location.split("/")[0..-2].join("/")+"/"

	data = {"notes_data" => [],
			"columns" => 4,
			"column_width" => column_width,
			"game_mode" => 3, "title" => "",
			"artist" => "", "creator" => "",
			"version" => "",
			"audio_filename" => "",
			"audio_offset" => "",
			"source_folder" => source_folder,
			"end_event" => 0,
			"BeatmapSetID" => 0,
			"background_image" => nil
		}
	
    flag = 0
	
	File.foreach(file) do |line|
		data_from_line = process_line(data, line, flag)
		data = data_from_line[0]
		flag = data_from_line[1]
    end

	file.close

	if data['notes_data'] != []
		end_note = data['notes_data'][-1]
		if end_note[0] == "hold"
			end_event = end_note[3].to_i # end time of the extended note
		else
			end_event = end_note[2].to_i # only start time
		end

		data['end_event'] = end_event
	end

    map = create_map(data)

    return map
end