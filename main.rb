require 'gosu'
require './file_parser'
require './config_parser'
require './file_importer'
require 'time'

# rewrite the parsing to get more information / move file parser to a secondary file
# implement graphics
# also include rubycatch
# volume slider
# background slider
# menu screen

WIDTH = 1920
HEIGHT = 1080

class GameWindow < Gosu::Window
  def initialize
    super WIDTH, HEIGHT, :fullscreen => true, :update_interval => 1
    self.caption = "GosuMania"
    check_map_directory_exists()
    load_maps()
    load_assets()
    
    @column_keys = get_keyboard_controls() # get the controls from the config

    @last_frame_time = Time.now
    @hit_height = HEIGHT*0.8
    @note_height = 100

    @approach_time = 400.0 # ms
    @approach_interval = 50.0 # ms to change the approach rate by

    @volume = 100

    #change this to a dictionary for ease of rebinding
    @column_states = {}
    @column_start_taps = {}
    @column_end_taps = {}
    
    @menu = 0
    @playing_map = false

    @prev_scroll_offset = -1
    @scroll_offset = 0

    @combo = 0
    @misses = 0

    @current_accuracy_image = nil

    @draw_volume_time = 0
    @display_combo_until = 0
    @display_note_accuracy_until = 0

    @background_dim = 20
    get_menu_background(rand(0..@maps.length-1))
  end

  def check_map_directory_exists()
    if !(File.directory?("maps"))
        Dir.mkdir "maps"
    end
  end

  def load_assets()
    @image_miss = Gosu::Image.new("skin/mania-hit0.png")
    @image_50 = Gosu::Image.new("skin/mania-hit50.png")
    @image_100 = Gosu::Image.new("skin/mania-hit100.png")
    @image_200 = Gosu::Image.new("skin/mania-hit200.png")
    @image_300 = Gosu::Image.new("skin/mania-hit300.png")
    @image_perfect = Gosu::Image.new("skin/mania-hit300g-0.png")
  end

  def get_next_note_group()

    #add notes to current notes that are happening in less than the approach time

    count = @notes_all.length

    while @note_index < count
        note = @notes_all[@note_index]

        @note_start_time = note.start_time.to_i - @approach_time

        break if @note_start_time > (@song_time*1000 + @approach_time) # if the note doesn't need to exist yet, leave the while loop

        @notes << note # the note needs to exist now

        @note_index += 1
    end
  end

  def initiate_song(map_id) # call when a song is selected
    if @maps.length != 0 and map_id != nil
        @playing_map = true
        @selected_map = @maps[map_id]

        @selected_map.print_info

        @song_src = @selected_map.source_folder + @selected_map.audio_filename
        @song = Gosu::Song.new(@song_src)
        @wait_time = 2 # wait 2 seconds before starting the song
        @song_start_time = Time.now + @wait_time

        @column_states = {}
        @column_start_taps = {}
        @column_end_taps = {}
        for column_number in (0..@selected_map.columns-1)
            @column_states[column_number] = false
            @column_start_taps[column_number] = nil
            @column_end_taps[column_number] = nil
        end

        get_background_image()
        
        @notes_all = @selected_map.notes
        @notes = []
        @note_index = 0
        @flag = true
    else
        # go back to menu
        @menu = 0
    end
  end

  def get_background_image()
    if @selected_map.background_image != nil
        begin
            @background_image = Gosu::Image.new(@selected_map.background_image)
        rescue
            @background_image = nil
        end
    else
        @background_image = nil
    end
  end

  def get_menu_background(map_id)
    if map_id != nil
        if @maps[map_id].background_image != nil
            begin
                @menu_background = Gosu::Image.new(@maps[map_id].background_image)
            rescue
                @menu_background = nil
            end
        else
            @menu_background = nil
        end
    end
  end

  def update_song

    if Time.now > @song_start_time and @flag == true

        if @song != nil
            @song.play
            @song.volume = (@volume/100.to_f)

            @flag = false
        end
    end

    if get_song_status == "playing" or get_song_status == "song_over" # song_over is important as the song might require notes fall before it starts
        @song_time = Time.now-@song_start_time
    end
  end

  def get_song_status()
    @song_object = Gosu::Song.current_song
    if @song_object == nil
        #song stopped or over or hasn't started yet
        return "song_over"
    else
        if @song_object.playing?
            return "playing"
        else
            return "paused"
        end
    end
  end

  def note_fall

    @note_positions = {}

    for note in @notes
        @note_hit_time = note.start_time
        @note_start_time = @note_hit_time.to_i - @approach_time
        @note_y = (@hit_height/@approach_time)*((@song_time*1000)-@note_start_time)-@note_height
        @note_positions[note.id] = @note_y
    end
  end

  def note_delete

    @note_positions.each do | note_id, position |

        if position > HEIGHT # if the note is off the screen,
            @note_positions.delete(note_id)
            note_value = ""
            for note in @notes
                if note.id == note_id
                    note_value = note
                    @combo = 0 # the note was missed by the player
                    @misses += 1
                    @current_accuracy_image = @image_miss # player missed, so show them
                    @display_note_accuracy_until = @song_time + 0.2 # only 0.2 seconds
                    @display_combo_until = @song_time + 2 # 2 seconds
                    break
                end
            end

            @notes.delete(note_value)
        end
    end
  end

  def delete_specific_note(note)
    @notes.delete(note)
  end

  def center_text(text, size, color, x_pos, y_pos)
    @text = Gosu::Image.from_text(text, size)
    x = (WIDTH-@text.width)/2 + (x_pos - (WIDTH/2))
    @text.draw(x, y_pos, 3, scale_x = 1, scale_y = 1, color)
  end

  def note_tap()
    @column_states.each do |column, state|
        if state # button is currently held
            # use the song time to determine whether there is a note within some ms before or after the tap time
            for note in @notes
                start_tap = @column_start_taps[column]
                if start_tap != nil
                    timing = (start_tap*1000 - note.start_time.to_i)
                    if note.column == column and timing.abs <= 250
                        @column_start_taps[column] = nil
                        @combo += 1
                        @display_combo_until = @song_time + 2 # 2 seconds
                        delete_specific_note(note)
                        @current_accuracy_image = @image_50 # assume the worst accuracy at first
                        if timing.abs <= 75
                            @current_accuracy_image = @image_perfect
                        elsif timing.abs <= 100
                            @current_accuracy_image = @image_300
                        elsif timing.abs <= 125
                            @current_accuracy_image = @image_200
                        elsif timing.abs <= 150
                            @current_accuracy_image = @image_100
                        elsif timing.abs <= 250
                            @combo = 0
                            @current_accuracy_image = @image_miss
                        end
                        @display_note_accuracy_until = @song_time + 0.2 # only for 0.2 seconds
                        break
                    end
                else
                    break
                end
            end
        end
    end
  end

  def update

    # time between frames, used to skip frames
    @current_frame_time = Time.now
    @time_difference = @current_frame_time - @last_frame_time
    
    # condition to determine options, paused, song_select or gameplay
    if @playing_map or @menu == 1

        # calculate the song time and play the song if not paused
        update_song()

        # load the next chunk of visible notes into the notes array
        get_next_note_group()

        # calculate note position below
        note_fall()
        
        # remove old notes from the array
        note_delete()
        
        # tap notes
        if get_song_status == "playing"
            note_tap()
        end

        status = get_song_status()
        if (status != "playing" and status != "paused" and @song_time*1000 > @selected_map.end_event)
            reset_environment()
            @menu = 0
            @playing_map = false
        end
    elsif @menu == 0
        # song selection
        
    end

    # set the last frame to the frame just used
    @last_frame_time = @current_frame_time

  end

  def draw
    @buttons = [] # reset all buttons every cycle

    if @playing_map or @menu == 1
        if @background_image != nil
            i_width = @background_image.width
            i_height = @background_image.height
            scale_x = (WIDTH/i_width.to_f)
            scale_y = (HEIGHT/i_height.to_f)
            if scale_x < scale_y #find which needs to be enlarged the most
                scale_f = scale_y
            else
                scale_f = scale_x
            end
            background_255 = @background_dim*0.01*255
            background_hex = "0x"+background_255.to_i.to_s(16)+"_ffffff" #get a hex representation
            color = background_hex.hex
            @background_image.draw(0, 0, 0, scale_f, scale_f, color)
        end

        @columns_width = (WIDTH/3)
        @columns_offset = (WIDTH - @columns_width)/2
        @column_width = @columns_width/@selected_map.columns

        # draw column lines
        for column in (1..@selected_map.columns+1) do
            @x = @columns_offset+((column-1)*@column_width)
            @y = 0
            Gosu.draw_rect(@x, @y, 1, HEIGHT, Gosu::Color::WHITE)
        end

        # draw all visible notes
        @notes.each_with_index do |note, index|
            column_number = note.column

            @note_y_pos = @note_positions[note.id]

            Gosu.draw_rect(@columns_offset+((column_number)*@column_width), @note_y_pos, @column_width, @note_height, Gosu::Color::WHITE)
        end

        # draw the current button presses
        @column_states.each do |column, state|
            if state
                Gosu.draw_rect(@columns_offset+((column)*@column_width), @hit_height, @column_width, (HEIGHT-@hit_height)/4, Gosu::Color::AQUA)
            end
        end

        Gosu.draw_rect(@columns_offset, @hit_height, @columns_width, 1, Gosu::Color::RED)

        # draw combo, also draw total accuracy and note accuracy
        if @display_combo_until != 0
            if @song_time < @display_combo_until
                center_text(@combo.to_s, 200, Gosu::Color::WHITE, WIDTH/2, 300)
            end
        end

        # display the previous notes accuracy

        if @display_note_accuracy_until != 0
            if @song_time < @display_note_accuracy_until
                draw_accuracy_image()
            end
        end
        if @menu == 1
            button_spacing = 50
            height = 100
            width = 500
            total_height = 3*height + 2*button_spacing
            offset_y = (HEIGHT-total_height)/2
            offset_x = (WIDTH-width)/2
            y = offset_y
            x = offset_x
            # resume
            draw_button(x, y, height, width, Gosu::Color::GREEN, "resume")
            create_hitbox(0, x, y, x+width, y+height)
            y += height + button_spacing
            # retry
            draw_button(x, y, height, width, Gosu::Color::YELLOW, "retry")
            create_hitbox(1, x, y, x+width, y+height)
            y += height + button_spacing
            # quit
            draw_button(x, y, height, width, Gosu::Color::RED, "quit")
            create_hitbox(2, x, y, x+width, y+height)
            y += height + button_spacing
        end

        
        # draw the volume bar
        if @draw_volume_time != 0
            if Time.now < @draw_volume_time
                draw_volume_level()
            end
        end
    elsif @menu == 0
        # draw the menu
        # draw the songs that can be selected
        pos_y = 0
        @map_height = 75
        map_width = 1000
        x = WIDTH-map_width
        if @prev_scroll_offset != @scroll_offset
            map_index = 0
            for map in @maps
                y = pos_y+@scroll_offset
                if y <= HEIGHT and y >= -@map_height
                    create_hitbox(map_index, x, y, x+map_width, y+@map_height)
                    draw_map(map, x, y, map_width, map_index)
                    Gosu.draw_rect(WIDTH-map_width, pos_y+@scroll_offset, map_width, 1, Gosu::Color::BLACK, 9)
                end
                pos_y += @map_height
                map_index += 1
            end
        end
        change_menu_background()
    end
  end

  def change_menu_background()
    @button_hover = button_pressed(mouse_x, mouse_y) # usually triggered by the mouse clicker, but it isn't necessary
    if @button_hover != false
        @menu_background = get_menu_background(@button_hover)
    end
    if @menu_background != nil
        i_width = @menu_background.width
        i_height = @menu_background.height
        scale_x = (WIDTH/i_width.to_f)
        scale_y = (HEIGHT/i_height.to_f)
        if scale_x < scale_y #find which needs to be enlarged the most
            scale_f = scale_y
        else
            scale_f = scale_x
        end
        @menu_background.draw(0, 0, 0, scale_f, scale_f)
    end
  end

  def draw_button(x, y, height, width, color, text)
    Gosu.draw_rect(x, y, width, height, color, 9)
    @text = Gosu::Image.from_text(text, 50)
    @text.draw(x+10, y+10, 10, scale_x = 1, scale_y = 1, Gosu::Color::BLACK)
  end

  def create_hitbox(button_id, x, y, x2, y2)
    @buttons << [button_id, x, y, x2, y2]
  end

  def draw_map(map, x, y, map_width, map_index)
    color = 0x66_ffffff
    if button_pressed(mouse_x, mouse_y) == map_index.to_i
        color = 0x66_ff0000
    end
    Gosu.draw_rect(x, y, map_width, @map_height, color, 1)
    name = map.artist + " - " + map.title
    version = map.version
    @text = Gosu::Image.from_text(name, 20)
    @text.draw(x+10, y+20, 7, scale_x = 1, scale_y = 1, Gosu::Color::BLACK)
    @text = Gosu::Image.from_text(version, 15)
    @text.draw(x+10, y+40, 7, scale_x = 1, scale_y = 1, Gosu::Color::BLACK)
  end

  def draw_accuracy_image()
    image_height = @current_accuracy_image.height
    image_width = @current_accuracy_image.width
    x_align = WIDTH/2
    y_align = (HEIGHT/3)*2
    offset_x = (WIDTH - image_width)/2
    offset_y = ((HEIGHT - image_height)/3)*2
    @current_accuracy_image.draw(offset_x, offset_y, 5)
  end

  def draw_volume_level() #refactor
    volume = @volume
    width = 20
    height = 210
    start_x = WIDTH-width
    start_y = (HEIGHT-height)/2
    spacing = 5
    offset = 5
    volume_scale = (height/100)
    starting_height = start_y+spacing+((100*volume_scale)-volume*volume_scale)
    volume_height = height-(spacing*2)-((100*volume_scale)-volume*volume_scale)
    Gosu.draw_rect(start_x-offset, start_y, width, height, Gosu::Color::WHITE, 1, mode=:default)
    Gosu.draw_rect(start_x+spacing-offset, starting_height, width-(spacing*2), volume_height, Gosu::Color::BLACK, 1, mode=:default)
  end

  def needs_redraw? # if the fps is below  60, skip the frame
    if @time_difference > (1.0/60) # 16.67 ms / 60 fps
        false
    else
        true
    end
  end

  def drop(filename)
    import_new_map(filename) # triggered on the drag and drop event
    load_maps() # reload all the maps so player can select it to play
  end

  def button_pressed(mouse_x, mouse_y)
    for button in @buttons
        if (mouse_x >= button[1] && mouse_x <= (button[3])) && (mouse_y >= button[2] && mouse_y <= (button[4]))
            return button[0]
        end
    end
    return false
  end

  def resume_song()
    @time_paused_end = Time.now
    @time_paused = @time_paused_end - @time_paused_start
    @song_start_time += @time_paused # so the notes are in the correct time position
    @song.play
    @song.volume = (@volume/100.to_f)
    @menu = 0 # so it isn't paused
  end

  def pause_song()
    @time_paused_start = Time.now
    @song.pause
    @menu = 1 # bring up paused menu overlay
  end

  def reset_environment()
    @misses = 0
    @combo = 0
    @display_combo_until = 0
    @display_note_accuracy_until = 0
    @current_accuracy_image = nil
    @playing_map = true
    @menu = 0
    if @song != nil
        @song.stop
    end
  end

  def button_down(id)
    if id == Gosu::KbEscape
        status = get_song_status()
        if status == "playing"
            pause_song()
        elsif status == "paused"
            resume_song()
        elsif @playing_map == true
            @menu = 0
            @playing_map = false
        else
            close
        end
    elsif id == Gosu::MsLeft
        result = button_pressed(mouse_x, mouse_y)
        if result != false
            if @menu == 0
                @current_map_id = result
                reset_environment()
                initiate_song(result)
            elsif @menu == 1
                if result == 0 # resume
                    @menu = 0
                    @playing_map = true
                    resume_song()
                elsif result == 1 # retry
                    reset_environment()
                    initiate_song(@current_map_id)
                elsif result == 2 # quit
                    reset_environment()
                    @playing_map = false
                end
            end
        end
    elsif id == 259
        if @playing_map or @menu == 1
            if @volume < 100
                @volume += 1
            end
            # Volume Up
            if @song != nil
                @song.volume = (@volume/100.to_f)
            end
            @draw_volume_time = Time.now + 1
        end
        
        @prev_scroll_offset = @scroll_offset
        @scroll_offset += 200
        if @scroll_offset > HEIGHT-@map_height
            # scrolled too far
            @prev_scroll_offset = @scroll_offset
            @scroll_offset = HEIGHT-@map_height
        end
    elsif id == 260
        if @playing_map or @menu == 1
            if @volume > 0
                @volume -= 1
            end
            # Volume Down
            if @song != nil
                @song.volume = (@volume/100.to_f)
            end
            @draw_volume_time = Time.now + 1
        end

        @prev_scroll_offset = @scroll_offset
        @scroll_offset  -= 200
        if @scroll_offset < (@maps.length-1)*-@map_height
            # scrolled too far,
            @prev_scroll_offset = @scroll_offset
            @scroll_offset = (@maps.length-1)*-@map_height
        end
    elsif id == Gosu::KB_F1
        @background_dim += 10
        if @background_dim > 100
            @background_dim = 100
        end
    elsif id == Gosu::KB_F2
        @background_dim -= 10
        if @background_dim < 0
            @background_dim = 0
        end
    else # this handles the column key presses
        if @playing_map or @menu == 1
            controls = @column_keys[@selected_map.columns] # select the applicable key bindings based on the amount of columns
            column_number = controls.index(id) # find the column for the key, if it exists
            if column_number != nil
                modify_column_state(column_number, "down") # change the keys state
            end
        end
    end
  end

  def change_approach_time(change)
    if change == 1 # increase the approach time (eg. slower notes)
        @approach_time += @approach_interval
    elsif change == -1 # decrease the approach time (eg. faster notes)
        @approach_time -= @approach_interval

        if @approach_time < @approach_interval
            @approach_time = @approach_interval
        end
    end
  end

  def modify_column_state(column, state)
    if state == "up"
        @column_states[column] = false
        @column_start_taps[column] = nil
        @column_end_taps[column] = @song_time
    else
        @column_states[column] = true
        if @column_start_taps[column] == nil # prevent holding to tap
            @column_start_taps[column] = @song_time
            @column_end_taps[column] = nil
        end
    end
  end

  def needs_cursor?
    if @playing_map == true and @menu != 1
        return false
    elsif @menu == 1
        return true
    else
        return true
    end
  end

  def button_up(id)
    if id == Gosu::KB_F3
        change_approach_time(1)
    elsif id == Gosu::KB_F4
        change_approach_time(-1)
    else
        if @playing_map or @menu == 1
            controls = @column_keys[@selected_map.columns] # select the applicable key bindings based on the amount of columns
            column_number = controls.index(id) # find the column for the key, if it exists
            if column_number != nil
                modify_column_state(column_number, "up") # change the keys state
            end
        end
    end
  end

  def load_maps()
    @maps = read_all_maps("maps", ".rbm")
  end
end

window = GameWindow.new
window.show