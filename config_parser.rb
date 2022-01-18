$config_location = "config.ini"

def check_if_config_exists()
    if (File.file?($config_location))
        return true
    end
end

def create_config()
    config_file = File.new($config_location, "w")
    data = "1K:44\n"+
           "2K:26,76\n"+
           "3K:26,44,76\n"+
           "4K:20,26,76,77\n"+
           "5K:20,26,44,76,77\n"+
           "6K:20,26,8,76,77,78\n"+
           "7K:20,26,8,44,76,77,78\n"+
           "8K:20,26,8,21,24,12,18,19\n"+
           "9K:20,26,8,21,44,24,12,18,19\n"+
           "10K:20,26,8,21,23,28,24,12,18,19"
    config_file.puts(data)
    config_file.close
end

def get_keyboard_controls()
    
    if !(check_if_config_exists()) # check if the file exists
        create_config() # it doesn't so make the default config
    end

    setting_name_delimiter = ":"
    value_delimiter = ","

    config_file = File.new($config_location)

    column_keys = {}

    config_file.each do |line|
        line_data = line.strip.split(setting_name_delimiter)
        setting_name = line_data[0].split("K")[0].to_i # don't really need the K, it just makes the config clearer to read
        str_values = line_data[1].split(value_delimiter)
        int_values = []
        str_values.each do |value|
            int_values << value.to_i
        end
        column_keys[setting_name] = int_values
    end

    return column_keys
end