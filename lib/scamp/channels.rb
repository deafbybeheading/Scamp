class Scamp
  module Channels
    # TextMessage (regular chat message),
    # PasteMessage (pre-formatted message, rendered in a fixed-width font),
    # SoundMessage (plays a sound as determined by the message, which can be either “rimshot”, “crickets”, or “trombone”),
    # TweetMessage (a Twitter status URL to be fetched and inserted into the chat)
    
    #  curl -vvv -H 'Content-Type: application/json' -d '{"message":{"body":"Yeeeeeaaaaaahh", "type":"Textmessage"}}' -u API_KEY:X https://37s.campfirenow.com/room/293788/speak.json
    def say(message, channel)
      url = "https://37s.campfirenow.com/room/#{channel_id(channel)}/speak.json"
      http = EventMachine::HttpRequest.new(url).post :head => {'Content-Type' => 'application/json', 'authorization' => [api_key, 'X']}, :body => Yajl::Encoder.encode({:message => {:body => message, :type => "Textmessage"}})
      
      http.errback { STDERR.puts "Error speaking: '#{message}' to #{channel_id(channel)}" }
    end
    
    def paste(text, channel)
    end
    
    def upload
    end
    
    def join(channel_id)
      url = "https://37s.campfirenow.com/room/#{channel_id}/join.json"
      http = EventMachine::HttpRequest.new(url).post :head => {'Content-Type' => 'application/json', 'authorization' => [api_key, 'X']}
      
      http.errback { STDERR.puts "Error joining channel: #{channel_id}" }
      http.callback {
        yield if block_given?
      }
    end

    def channel_id(channel_id_or_name)
      if channel_id_or_name.is_a? Integer
        return channel_id_or_name
      else
        return channel_id_from_channel_name(channel_id_or_name)
      end
    end
    
    def channel_name_for(channel_id)
      data = channel_cache_data(channel_id)
      return data["name"] if data
      channel_id.to_s
    end
    
    private
    
    def channel_cache_data(channel_id)
      return channel_cache[channel_id] if channel_cache.has_key? channel_id
      fetch_channel_data(channel_id)
      return false
    end
    
    def populate_channel_list
      url = "https://37s.campfirenow.com/rooms.json"
      http = EventMachine::HttpRequest.new(url).get :head => {'authorization' => [api_key, 'X']}
      http.errback { puts http.status }
      http.callback {
        new_channels = {}
        Yajl::Parser.parse(http.response)['rooms'].each do |c|
          new_channels[c["name"]] = c
        end
        # No idea why using the "channels" accessor here doesn't
        # work but accessing the ivar directly does. There's
        # Probably a bug.
        @channels = new_channels # replace existing channel list
        yield if block_given?
      }
    end

    def fetch_channel_data(channel_id)
      STDERR.puts "Fetching channel data for #{channel_id}"
      url = "https://37s.campfirenow.com/room/#{channel_id}.json"
      http = EventMachine::HttpRequest.new(url).get :head => {'authorization' => [api_key, 'X']}
      http.errback { STDERR.puts "Couldn't get data for channel #{channel_id} at url #{url}" }
      http.callback {
        puts "Fetched channel data for #{channel_id}"
        room = Yajl::Parser.parse(http.response)['room']
        channel_cache[room["id"]] = room
        room['users'].each do |u|
          update_user_cache_with(u["id"], u)
        end
      }
    end
    
    def stream(channel_id)
      json_parser = Yajl::Parser.new :symbolize_keys => true
      json_parser.on_parse_complete = method(:process_message)
      
      url = "https://streaming.campfirenow.com/room/#{channel_id}/live.json"
      http = EventMachine::HttpRequest.new(url).get :head => {'authorization' => [api_key, 'X']}
      http.errback { STDERR.puts "Couldn't stream channel #{channel_id} at url #{url}" }
      http.stream {|chunk| json_parser << chunk }
    end

    def channel_id_from_channel_name(channel_name)
      puts "Looking for channel id for #{channel_name}"
      channels[channel_name]["id"]
    end
  end
end #class
