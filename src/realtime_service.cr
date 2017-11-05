require "kemal"
require "http/web_socket"
require "json"
require "colorize"
require "dotenv"
require "jwt"
require "./realtime_service/*"

Dotenv.load unless Kemal.config.env == "production"

# HTTP Client: https://github.com/mamantoha/crest
# JWT: https://github.com/crystal-community/jwt

SOCKETS = {} of String => Set(HTTP::WebSocket)

module RealtimeService
  get "/" do |env|
    env.response.content_type = "text/html"
    render "src/views/index.ecr"
  end

  get "/ping" do |env|
    begin
      message = env.params.query["message"].as(String)
      channel = env.params.query["channel"].as(String)

      SOCKETS[channel].each do |socket|
        socket.send({msg: message}.to_json)
      end
    rescue KeyError
      puts "Key error!".colorize(:red)
    end
  end

  post "/broadcast" do |env|
    env.response.content_type = "text/html"

    begin
      token = env.params.json["token"].as(String)
      payload = self.decode_jwt(token)

      channel = payload["channel"].as(String)
      deliveries = 0

      if SOCKETS.has_key?(channel)
        SOCKETS[channel].each do |socket|
          socket.send(payload["message"].as(String))
          deliveries += 1
        end
      end

      {message: "Success", deliveries: deliveries}.to_json
    rescue JWT::DecodeError
      env.response.status_code = 400
      {error: "Bad signature"}.to_json
    end
  end

  ws "/subscribe" do |socket|
    puts "Socket connected".colorize(:green)

    socket.on_message do |message|
      puts message.colorize(:blue)

      data = JSON.parse(message)

      # If message is authing, store in hash
      if data["type"].to_s == "authenticate"
        token = data["payload"]["token"].to_s

        begin
          payload = self.decode_jwt(token)
          payload["channels"].as(Array).each do |channel|
            channel = channel.as(String)
            if SOCKETS.has_key?(channel)
              SOCKETS[channel] << socket
            else
              SOCKETS[channel] = Set{socket}
            end

            socket.send({message: "subscribed", channel: channel}.to_json)
          end
        rescue JWT::DecodeError
          socket.close
        end
      end
    end

    # Remove clients from the list when it's closed
    socket.on_close do
      SOCKETS.each do |channel, set|
        if set.includes?(socket)
          set.delete(socket)

          puts "Socket disconnected from #{channel}!".colorize(:yellow)
        end
      end
    end
  end

  def self.decode_jwt(token : String)
    payload, header = JWT.decode(token, ENV["JWT_SECRET"], "HS512")
    payload
  end
end

Kemal.run
