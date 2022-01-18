require 'fileutils'
require 'zip'
require './file_parser'

def import_new_map(filename)
    file_extension = File.extname(filename).strip.downcase
    if file_extension == ".osz"
        begin
            extract_zip(filename)
            new_folder_name = "maps/" + get_map_folder_name("temp")
            rename_files("temp", ".osu")
            move_files("temp", new_folder_name)
        rescue
            FileUtils.rm_rf("temp")
        end
    end
end

def extract_zip(filename)
    FileUtils.rm_rf("temp") # delete the prior temp dir
    FileUtils.mkdir_p("temp") # make a new one

    zip_file = Zip::ZipFile.open(filename)
    zip_file.each do |file|
        file_path=File.join("temp", file.name)
        FileUtils.mkdir_p(File.dirname(file_path))
        zip_file.extract(file, file_path) unless File.exist?(file_path)
    end
end

def rename_files(folder_name, map_format)
    map_locations = Dir[folder_name+"/**/*"+map_format]

    for map_location in map_locations
        renamed_location = map_location.sub(".osu",".rbm")
        File.rename(map_location, renamed_location)
    end
end

def move_files(old_path, new_path)
    FileUtils.rm_rf(new_path)
    FileUtils.mv old_path, new_path
    FileUtils.rm_rf(old_path)
end

def get_map_folder_name(foldername)
    maps = read_all_maps(foldername, ".osu")
    map = maps[0]
    artist = map.artist
    title = map.title
    beatmap_set_id = map.beatmap_set_id
    if beatmap_set_id != 0
        filename = beatmap_set_id + " " + artist + " - " + title
    else
        filename = artist + " - " + title
    end
    return filename
end

def read_all_maps(foldername, map_format)
    map_locations = Dir[foldername+"/**/*"+map_format]
    maps = []

    for map_location in map_locations
        map = read_map(map_location)
        maps << map
    end

    return maps
end